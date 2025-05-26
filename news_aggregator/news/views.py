import re
from django.shortcuts import  get_object_or_404
from news.fetchers.news_api_fetcher import NewsApiFetcher
from news.fetchers.gnews_api_fetcher import GNewsApiFetcher
from news.fetchers.google_rss_fetcher import RssFeedFetcher
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.decorators import api_view, permission_classes
from .models import Recommendation, Articles, UserInteraction, Like, Comment, Feed, Sources, Keyword
from .tasks import generate_recommendations, process_and_store_articles, store_articles_batch, store_article_async
from django.utils import timezone
from datetime import timedelta
import logging
from django.db.models import Q, Count
from rest_framework import status
import random
from django.core.cache import cache
from news.utils.article_serializer import ArticleSerializer

logger = logging.getLogger(__name__)
DEFAULT_IMAGE_URL = 'https://raw.githubusercontent.com/mMelnic/news-fake-detection/refs/heads/users/news_aggregator/newspaper_beige.jpg'


class ArticleDetailView(APIView):
    def get(self, request, article_id):
        try:
            article = Articles.objects.get(id=article_id)
            
            # Record user interaction if authenticated
            if request.user.is_authenticated:
                UserInteraction.objects.get_or_create(
                    user=request.user,
                    article=article,
                    defaults={'interaction_type': 'view'}
                )
            
            # Return article details
            return Response({
                "id": article.id,
                "title": article.title,
                "content": article.content,
                "url": article.url,
                "image_url": article.image_url,
                "author": article.author,
                "published_date": article.published_date,
                "source": article.source.name if article.source else "Unknown",
                "has_embedding": article.embedding is not None,
                "is_fake": article.is_fake,
                "fake_score": article.fake_score,  # Keep for backward compatibility
                "sentiment": article.sentiment,
                "language": article.language,
            })
        except Articles.DoesNotExist:
            return Response({"error": "Article not found"}, status=404)


class RecommendationView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        recs = Recommendation.objects.filter(user=request.user).select_related('article')
        data = [{
            'id': r.article.id,
            'title': r.article.title,
            'content': r.article.content[:200] + "..." if len(r.article.content) > 200 else r.article.content,
            'url': r.article.url,
            'image_url': r.article.image_url,
            'source': r.article.source.name if r.article.source else "Unknown",
            'published_date': r.article.published_date,
            'has_embedding': r.article.embedding is not None
        } for r in recs]
        return Response(data)

    def post(self, request):
        generate_recommendations.delay(request.user.id)
        return Response({'status': 'Recommendation task started'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def toggle_like(request):
    article_id = request.data.get('article_id')
    article = get_object_or_404(Articles, pk=article_id)
    like, created = Like.objects.get_or_create(user=request.user, article=article)
    if not created:
        like.delete()
        return Response({'liked': False})
    return Response({'liked': True})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def is_article_liked(request, article_id):
    article = get_object_or_404(Articles, pk=article_id)
    liked = Like.objects.filter(user=request.user, article=article).exists()
    return Response({'liked': liked})

@api_view(['GET'])
def get_article_like_count(request, article_id):
    article = get_object_or_404(Articles, pk=article_id)
    count = Like.objects.filter(article=article).count()
    return Response({'count': count})

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_comment(request):
    article_id = request.data.get('article_id')
    content = request.data.get('content')
    article = get_object_or_404(Articles, pk=article_id)
    comment = Comment.objects.create(user=request.user, article=article, content=content)
    return Response({'id': comment.id, 'content': comment.content})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_article_comments(request, article_id):
    article = get_object_or_404(Articles, pk=article_id)
    comments = Comment.objects.filter(article=article).order_by('-created_at')
    data = [{'id': c.id, 'content': c.content} for c in comments]
    return Response({'comments': data})

class ArticleListView(APIView):
    """
    List articles filtered by any combination of:
    - category, language, country, keywords, published_date (start/end),
      source, sorted by newest, oldest, random, popular
    """
    def get(self, request):
        qs = Articles.objects.all()

        # Filters
        category = request.query_params.get('category')
        language = request.query_params.get('language')
        country = request.query_params.get('country')
        keywords = request.query_params.getlist('keywords')  # multiple keywords
        source_id = request.query_params.get('source')
        published_after = request.query_params.get('published_after')
        published_before = request.query_params.get('published_before')
        sort = request.query_params.get('sort', 'newest')

        # Category filter (string match in categories TextField)
        if category:
            qs = qs.filter(categories__icontains=category)

        if language:
            qs = qs.filter(language=language)

        if country:
            qs = qs.filter(country=country)

        if source_id:
            qs = qs.filter(source_id=source_id)

        # Filter by published date range if provided
        if published_after:
            try:
                dt_after = timezone.datetime.fromisoformat(published_after)
                qs = qs.filter(published_date__gte=dt_after)
            except Exception:
                return Response({"error": "Invalid published_after datetime format"}, status=status.HTTP_400_BAD_REQUEST)

        if published_before:
            try:
                dt_before = timezone.datetime.fromisoformat(published_before)
                qs = qs.filter(published_date__lte=dt_before)
            except Exception:
                return Response({"error": "Invalid published_before datetime format"}, status=status.HTTP_400_BAD_REQUEST)

        # Keywords filter (match article keywords or in title/content)
        if keywords:
            # Build OR filter for keywords related to articles or in title/content
            keyword_filter = Q()
            for kw in keywords:
                keyword_filter |= Q(keywords__keyword__iexact=kw) | Q(title__icontains=kw) | Q(content__icontains=kw)
            qs = qs.filter(keyword_filter).distinct()

        # Sorting
        if sort == 'newest':
            qs = qs.order_by('-published_date')
        elif sort == 'oldest':
            qs = qs.order_by('published_date')
        elif sort == 'random':
            qs = list(qs)
            random.shuffle(qs)
        elif sort == 'popular':
            # Popularity by likes count
            qs = qs.annotate(num_likes=Count('like')).order_by('-num_likes', '-published_date')
        else:
            qs = qs.order_by('-published_date')

        # Limit results to 300
        articles = qs[:300]

        data = [{
            'id': a.id,
            'title': a.title,
            'author': a.author,
            'content': a.content,
            'url': a.url,
            'image_url': a.image_url if a.image_url else DEFAULT_IMAGE_URL,
            'source': a.source.name if a.source else 'Unknown',
            'published_date': a.published_date,
            'country': a.country,
            'language': a.language,
            'categories': a.categories,
            'is_fake': a.is_fake,
            'sentiment': a.sentiment
        } for a in articles]

        return Response({'count': len(data), 'articles': data})


class FeedCategoryListView(APIView):
    """Return all unique feed categories"""

    def get(self, request):
        categories = Feed.objects.values_list('category', flat=True).distinct()
        categories = [c for c in categories if c]  # filter out None/empty
        return Response({'categories': categories})


class FeedCategoryArticlesView(APIView):
    """Return articles belonging to a feed category"""

    def get(self, request, category):
        articles = Articles.objects.filter(categories__icontains=category).order_by('-published_date')[:50]
        data = [{
            'id': a.id,
            'title': a.title,
            'author': a.author,
            'content': a.content,
            'url': a.url,
            'image_url': a.image_url if a.image_url else DEFAULT_IMAGE_URL,
            'source': a.source.name if a.source else None,
            'published_date': a.published_date,
            'country': a.country,
            'language': a.language,
            'categories': a.categories,
            'is_fake': a.is_fake,
            'sentiment': a.sentiment
        } for a in articles]
        return Response({'category': category, 'articles': data})


class SourceListView(APIView):
    """Return all unique sources"""

    def get(self, request):
        sources = Sources.objects.all()
        data = [{'id': s.id, 'name': s.name, 'url': s.url, 'country': s.country, 'language': s.language} for s in sources]
        return Response({'sources': data})


class SourceArticlesView(APIView):
    """Return articles belonging to a given source"""

    def get(self, request, source_id):
        articles = Articles.objects.filter(source_id=source_id).order_by('-published_date')[:50]
        data = [{
            'id': a.id,
            'title': a.title,
            'author': a.author,
            'content': a.content,
            'url': a.url,
            'image_url': a.image_url if a.image_url else DEFAULT_IMAGE_URL,
            'source': a.source.name if a.source else 'Unknown',
            'published_date': a.published_date,
            'country': a.country,
            'language': a.language,
            'categories': a.categories,
            'is_fake': a.is_fake,
            'sentiment': a.sentiment
        } for a in articles]
        return Response({'source_id': source_id, 'articles': data})
    
class ArticleOrSearchView(APIView):
    """
    Return articles that match ANY of the provided filters (logical OR).
    Filters: category, language, country, keywords, published_after, published_before, source
    """

    def get(self, request):
        qs = Articles.objects.all()
        or_filter = Q()

        category = request.query_params.get('category')
        language = request.query_params.get('language')
        country = request.query_params.get('country')
        keywords = request.query_params.getlist('keywords')
        source_id = request.query_params.get('source')
        published_after = request.query_params.get('published_after')
        published_before = request.query_params.get('published_before')
        sort = request.query_params.get('sort', 'newest')

        if category:
            or_filter |= Q(categories__icontains=category)

        if language:
            or_filter |= Q(language=language)

        if country:
            or_filter |= Q(country=country)

        if source_id:
            or_filter |= Q(source_id=source_id)

        if published_after:
            try:
                dt_after = timezone.datetime.fromisoformat(published_after)
                or_filter |= Q(published_date__gte=dt_after)
            except Exception:
                return Response({"error": "Invalid published_after format"}, status=400)

        if published_before:
            try:
                dt_before = timezone.datetime.fromisoformat(published_before)
                or_filter |= Q(published_date__lte=dt_before)
            except Exception:
                return Response({"error": "Invalid published_before format"}, status=400)

        if keywords:
            kw_filter = Q()
            for kw in keywords:
                kw_filter |= Q(keywords__keyword__iexact=kw) | Q(title__icontains=kw) | Q(content__icontains=kw)
            or_filter |= kw_filter

        qs = qs.filter(or_filter).distinct()

        # Sorting
        if sort == 'newest':
            qs = qs.order_by('-published_date')
        elif sort == 'oldest':
            qs = qs.order_by('published_date')
        elif sort == 'random':
            qs = list(qs)
            random.shuffle(qs)
        elif sort == 'popular':
            qs = qs.annotate(num_likes=Count('like')).order_by('-num_likes', '-published_date')

        # Limit to 300 articles
        articles = qs[:300]

        data = [{
            'id': a.id,
            'title': a.title,
            'content': a.content,
            'author': a.author,
            'published_date': a.published_date,
            'country': a.country,
            'language': a.language,
            'categories': a.categories,
            'source': a.source.name if a.source else 'Unknown',
            'url': a.url,
            'image_url': a.image_url if a.image_url else DEFAULT_IMAGE_URL,
            'is_fake': a.is_fake,
            'sentiment': a.sentiment
        } for a in articles]

        return Response({'count': len(data), 'articles': data})

@api_view(['GET'])
def search_and(request):
    raw_query = request.GET.get('q', '')
    language = request.GET.get('language')
    country = request.GET.get('country')

    if not raw_query:
        return Response({"error": "Missing query param 'q'"}, status=400)

    # Extract terms and phrases
    terms = []
    phrases = []
    matches = re.findall(r'"([^"]+)"|(\S+)', raw_query)
    for phrase, term in matches:
        if phrase:
            phrases.append(f'"{phrase}"')
        else:
            terms.append(term)

    operator = "AND"

    # Build query strings per API
    newsapi_query = build_query_string(terms, phrases, operator)
    gnews_query = newsapi_query
    rss_query = build_rss_query(terms, phrases, operator)

    # Fetch articles...
    newsapi_articles = NewsApiFetcher().fetch_articles(newsapi_query, language=language)
    gnews_articles = GNewsApiFetcher().fetch_articles(gnews_query, language=language, country=country)
    rss_articles = RssFeedFetcher().fetch_feed(query=rss_query, language=(language or 'en').lower(), country=(country or 'US').upper())

    all_articles = newsapi_articles + gnews_articles + rss_articles

    # Enrich each article with extracted keywords (store as list)
    # Pass extracted terms and phrases to celery task for storage
    task = process_and_store_articles.delay(all_articles, language, country, extracted_terms=terms, extracted_phrases=phrases)

    return Response({"task_id": task.id, "status": "started", "search_type": "AND"})


@api_view(['GET'])
def search_or(request):
    raw_query = request.GET.get('q', '')
    language = request.GET.get('language')
    country = request.GET.get('country')

    if not raw_query:
        return Response({"error": "Missing query param 'q'"}, status=400)

    # Extract terms and phrases
    terms = []
    phrases = []
    matches = re.findall(r'"([^"]+)"|(\S+)', raw_query)
    for phrase, term in matches:
        if phrase:
            phrases.append(f'"{phrase}"')
        else:
            terms.append(term)

    operator = "OR"

    # Build query strings per API
    newsapi_query = build_query_string(terms, phrases, operator)
    gnews_query = newsapi_query
    rss_query = build_rss_query(terms, phrases, operator)

    # Fetch articles...
    newsapi_articles = NewsApiFetcher().fetch_articles(newsapi_query, language=language)
    gnews_articles = GNewsApiFetcher().fetch_articles(gnews_query, language=language, country=country)
    rss_articles = RssFeedFetcher().fetch_feed(query=rss_query, language=(language or 'en').lower(), country=(country or 'US').upper())

    all_articles = newsapi_articles + gnews_articles + rss_articles

    # Enrich each article with extracted keywords (store as list)
    # Pass extracted terms and phrases to celery task for storage
    task = process_and_store_articles.delay(all_articles, language, country, extracted_terms=terms, extracted_phrases=phrases)

    return Response({"task_id": task.id, "status": "started", "search_type": "OR"})


def build_query_string(terms, phrases, operator):
    parts = []
    # Add exact phrases with quotes preserved
    if phrases:
        parts += phrases
    # Add individual terms (escaped if needed)
    if terms:
        parts += terms

    if operator == "AND":
        # Join with space, which means AND for NewsAPI/GNews
        return " ".join(parts)
    elif operator == "OR":
        # Join with ' OR '
        return " OR ".join(parts)
    else:
        raise ValueError("Invalid operator")
    
def build_rss_query(terms, phrases, operator):
    # RSS feed uses simple space-separated search
    # Just join all terms and phrases by space regardless of operator
    parts = []
    if phrases:
        parts += [p.strip('"') for p in phrases]  # remove quotes, since RSS doesn't use boolean logic
    if terms:
        parts += terms
    return " ".join(parts)

@api_view(['GET'])
def poll_task_articles(request, task_id):
    redis_key = f"articles_task:{task_id}"
    progress = cache.get(redis_key)

    if not progress:
        return Response({"status": "not_found"}, status=404)

    article_ids = progress.get("article_ids", [])
    articles = Articles.objects.filter(id__in=article_ids).order_by('-published_date')
    serialized = ArticleSerializer(articles, many=True)

    return Response({
        "status": progress.get("status", "processing"),
        "articles": serialized.data,
        "count": len(serialized.data)
    })


# class NewsAggregatorView(APIView):
#     def get(self, request):
#         query = request.query_params.get("query", "technology")  # Default query
#         language = request.query_params.get("language", "en")
#         country = request.query_params.get("country", None)
#         fresh_only = request.query_params.get("fresh_only", "true").lower() == "true"
#         force_refresh = request.query_params.get("refresh", "false").lower() == "true"
        
#         # First, check for existing articles in database
#         db_articles = self.get_db_articles(query, language, country, fresh_only)
        
#         # Only fetch from API if we have few results or force refresh is requested
#         if force_refresh or len(db_articles) < 50:
#             self.fetch_new_articles(query, language, country)
#             message = "Fetched from database. Additional articles are being loaded from external sources."
#         else:
#             message = "Fetched from database only. Use refresh=true parameter to fetch new articles."

#         # Return the database articles immediately
#         return Response({
#             "message": message,
#             "articles": db_articles,
#             "article_count": len(db_articles),
#             "from_db_only": not (force_refresh or len(db_articles) < 5),
#         })
    
#     def get_db_articles(self, query, language, country, fresh_only):
#         """Get relevant articles from database"""
#         logger.info(f"Searching database for articles matching: query={query}, language={language}, country={country}, fresh_only={fresh_only}")
        
#         queryset = Articles.objects.all()
        
#         # Apply keyword filtering using improved parsing
#         if query:
#             keyword_filter = self._build_keyword_filter(query)
#             if keyword_filter:
#                 queryset = queryset.filter(keyword_filter)
    
#         # Apply language filter if available
#         if language:
#             queryset = queryset.filter(Q(source__language=language) | Q(source__language__isnull=True))
            
#         # Apply country filter if available
#         if country:
#             queryset = queryset.filter(Q(country=country) | Q(country__isnull=True))
            
#         # Apply freshness filter if requested
#         if fresh_only:
#             # Get articles less than 24 hours old
#             one_day_ago = timezone.now() - timedelta(days=1)
#             queryset = queryset.filter(Q(published_date__gte=one_day_ago) | Q(published_date__isnull=True))
            
#         # Order by most recent first
#         queryset = queryset.order_by('-published_date').distinct()
        
#         # Log result count
#         article_count = queryset.count()
#         logger.info(f"Found {article_count} articles in database matching criteria")
        
#         # Convert to list of dictionaries
#         return [
#             {
#                 "id": article.id,
#                 "title": article.title,
#                 "content": article.content,
#                 "url": article.url,
#                 "image_url": article.image_url if article.image_url else DEFAULT_IMAGE_URL,
#                 "author": article.author,
#                 "published_date": article.published_date,
#                 "source": article.source.name if article.source else "Unknown",
#                 "is_fake": article.is_fake,
#                 "sentiment": article.sentiment,
#                 "country": article.country,
#                 "language": article.language,
#                 "categories": article.categories
#             }
#             for article in queryset[:100]  # Limit to 100 most recent matching articles
#         ]
        
#     def _build_keyword_filter(self, query):
#         """Build a Q filter for keywords based on parsed query."""
#         import re
        
#         # Extract phrases (quoted text)
#         phrases = re.findall(r'"(.*?)"', query)
        
#         # Remove phrases from query
#         remaining_query = re.sub(r'"(.*?)"', '', query)
        
#         # Extract individual keywords, ignoring logical operators
#         keywords = re.findall(r'([+-]?\b(?!AND\b|OR\b|NOT\b)\w+\b)', remaining_query)
#         keywords = [k.lower() for k in keywords if k.strip() and len(k.strip()) > 2]
        
#         # Combine with phrases
#         all_terms = keywords + phrases
        
#         if not all_terms:
#             return None
        
#         # Build Q filter for exact phrase matches and individual keywords
#         keyword_filter = Q()
        
#         # Add phrase matches (title contains the exact phrase)
#         for phrase in phrases:
#             keyword_filter |= Q(title__icontains=phrase)
    
#         # Add keyword matches (either in keywords table or title)
#         for keyword in keywords:
#             keyword_filter |= Q(keywords__keyword=keyword) | Q(title__icontains=keyword)
    
#         return keyword_filter
    
#     def fetch_new_articles(self, query, language, country):
#         """Fetch new articles from APIs in background"""
#         try:
#             logger.info(f"Fetching new articles from APIs: query={query}, language={language}, country={country}")
            
#             # Parse query to extract keywords for better article matching
#             from .tasks import _parse_query
#             keywords = _parse_query(query)
#             logger.info(f"Extracted keywords from query: {keywords}")
            
#             news_fetcher = NewsApiFetcher()
#             gnews_fetcher = GNewsApiFetcher()
#             rss_fetcher = RssFeedFetcher()
            
#             # Gather articles from all sources
#             articles = []
            
#             try:
#                 news_api_articles = news_fetcher.fetch_articles(query, language)
#                 # Add query, language and country information
#                 for article in news_api_articles:
#                     article['language'] = language
#                     article['country'] = country
#                     article['query'] = query
#                     article['keywords'] = keywords  # Add parsed keywords
#                 articles.extend(news_api_articles)
#                 logger.info(f"Fetched {len(news_api_articles)} articles from NewsAPI")
#             except Exception as e:
#                 logger.error(f"Error fetching from NewsAPI: {e}")
            
#             try:
#                 gnews_articles = gnews_fetcher.fetch_articles(query, language, country)
#                 # Add query information
#                 for article in gnews_articles:
#                     article['query'] = query
#                     article['keywords'] = keywords  # Add parsed keywords
#                 articles.extend(gnews_articles)
#                 logger.info(f"Fetched {len(gnews_articles)} articles from GNewsAPI")
#             except Exception as e:
#                 logger.error(f"Error fetching from GNewsAPI: {e}")
                
#             try:
#                 rss_articles = rss_fetcher.fetch_feed(query, language, country)
#                 # Add keywords to RSS articles
#                 for article in rss_articles:
#                     if 'keywords' not in article:
#                         article['keywords'] = keywords
#                 articles.extend(rss_articles)
#                 logger.info(f"Fetched {len(rss_articles)} articles from RSS feed")
#             except Exception as e:
#                 logger.error(f"Error fetching from RSS feed: {e}")
        
#             logger.info(f"Total articles fetched from all sources: {len(articles)}")
            
#             # Send to background processing - in batches to avoid overloading
#             batch_size = 10
#             for i in range(0, len(articles), batch_size):
#                 batch = articles[i:i+batch_size]
#                 # Pass the query parameter to enable WebSocket updates
#                 store_articles_batch.delay(batch, query)
                
#         except Exception as e:
#             # Log error but continue - we already returned DB results
#             logger.error(f"Error fetching new articles: {str(e)}")