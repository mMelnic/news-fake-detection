import logging
import random
import re
import uuid

import numpy as np

from django.core.cache import cache
from django.db.models import Q, Count
from django.shortcuts import get_object_or_404
from django.utils import timezone

from pgvector.django import CosineDistance

from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from news.fetchers.gnews_api_fetcher import GNewsApiFetcher
from news.fetchers.google_rss_fetcher import RssFeedFetcher
from news.fetchers.news_api_fetcher import NewsApiFetcher
from news.services.nlp_service import NLPPredictionService
from news.tasks import process_search_results

from .models import (
    Articles,
    Comment,
    Feed,
    Like,
    Recommendation,
    SavedArticle,
    SavedCollection,
    Sources,
    UserInteraction,
)
from .tasks import generate_recommendations, process_and_store_articles


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
    
    if created:
        # Record like interaction
        UserInteraction.objects.update_or_create(
            user=request.user,
            article=article,
            defaults={
                'interaction_type': 'like',
                'strength': 2.0,  # Higher weight for explicit likes
                'timestamp': timezone.now()
            }
        )
        return Response({'liked': True})
    else:
        # Remove like
        like.delete()
        # Update interaction to view only
        UserInteraction.objects.update_or_create(
            user=request.user,
            article=article,
            defaults={
                'interaction_type': 'view',
                'strength': 0.5,  # Lower weight for views
                'timestamp': timezone.now()
            }
        )
        return Response({'liked': False})

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
    
class ArticleTopicClassificationAPIView(APIView):
    """Classify the topic of an article by its ID"""

    def get(self, request, article_id):
        try:
            article = Articles.objects.get(id=article_id)
        except Articles.DoesNotExist:
            return Response({'error': 'Article not found'}, status=status.HTTP_404_NOT_FOUND)

        nlp_service = NLPPredictionService()
        topic = nlp_service.predict_topic_single(article.title + ' ' + article.content)

        if topic is None:
            return Response({'error': 'Could not classify topic'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        return Response({
            'article_id': article_id,
            'topic': topic
        })

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
    """Search articles using AND logic (all search terms must match)"""
    query = request.query_params.get('q', '')
    language = request.query_params.get('language', None)
    country = request.query_params.get('country', None)
    
    if not query:
        return Response({"error": "Query parameter 'q' is required"}, status=400)
    
    try:
        # Process the search using the NewsAPI fetcher
        newsapi_fetcher = NewsApiFetcher()
        newsapi_articles = newsapi_fetcher.fetch_articles(query, language=language)
        
        # Process the search using GNews fetcher
        gnews_fetcher = GNewsApiFetcher()
        gnews_articles = gnews_fetcher.fetch_articles(query, language=language)
        
        # Combine results
        all_articles = newsapi_articles + gnews_articles
        
        # Process and return results
        task = process_search_results.delay(all_articles)
        
        # Return the task ID as a string
        return Response({
            'status': 'started',
            'task_id': str(task.id)
        })
    
    except Exception as e:
        logging.error(f"Search error: {e}")
        return Response({"error": str(e)}, status=500)

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

    newsapi_articles = NewsApiFetcher().fetch_articles(newsapi_query, language=language)
    gnews_articles = GNewsApiFetcher().fetch_articles(gnews_query, language=language, country=country)
    rss_articles = RssFeedFetcher().fetch_feed(query=rss_query, language=(language or 'en').lower(), country=(country or 'US').upper())

    all_articles = newsapi_articles + gnews_articles + rss_articles
    task = process_and_store_articles.delay(all_articles, language, country, extracted_terms=terms, extracted_phrases=phrases)

    return Response({"task_id": task.id, "status": "started", "search_type": "OR"})


def build_query_string(terms, phrases, operator):
    parts = []
    # Add exact phrases with quotes preserved
    if phrases:
        parts += phrases
    if terms:
        parts += terms

    if operator == "AND":
        return " ".join(parts)
    elif operator == "OR":
        return " OR ".join(parts)
    else:
        raise ValueError("Invalid operator")
    
def build_rss_query(terms, phrases, operator):
    parts = []
    if phrases:
        parts += [p.strip('"') for p in phrases]  # remove quotes, since RSS doesn't use boolean logic
    if terms:
        parts += terms
    return " ".join(parts)

from celery.result import AsyncResult

@api_view(['GET'])
def poll_task_articles(request, task_id):
    """Poll for the status of a search task and return results if ready"""
    task = AsyncResult(task_id)
    
    if task.ready():
        if task.successful():
            return Response({
                'status': 'completed',
                'articles': task.result
            })
        else:
            return Response({
                'status': 'error',
                'error': str(task.result)
            }, status=500)
    else:
        return Response({
            'status': 'processing'
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
#             logger.error(f"Error fetching new articles: {str(e)}")

def get_real_time_recommendations(user, category, page, page_size):
    """Generate real-time recommendations based on user's liked and saved articles"""
    liked_articles = Articles.objects.filter(like__user=user)
    saved_articles = Articles.objects.filter(savedarticle__user=user)
    
    # Combine liked and saved articles (distinct)
    user_articles = (liked_articles | saved_articles).distinct()
    
    # Check if enough user articles with embeddings
    user_articles_with_embeddings = user_articles.exclude(embedding=None)
    
    MIN_ARTICLES_FOR_RECOMMENDATIONS = 3
    
    if user_articles_with_embeddings.count() < MIN_ARTICLES_FOR_RECOMMENDATIONS:
        # Not enough data, fall back to newest articles with optional category filter
        if category.lower() == 'all categories':
            fallback_articles = Articles.objects.all().order_by('-published_date')
        else:
            fallback_articles = Articles.objects.filter(categories__icontains=category).order_by('-published_date')
        
        # Paginate fallback results
        start_idx = (page - 1) * page_size
        end_idx = start_idx + page_size
        fallback_articles = fallback_articles[start_idx:end_idx]
        
        return [{
            'id': a.id,
            'title': a.title,
            'content': a.content,
            'url': a.url,
            'image_url': a.image_url if a.image_url else DEFAULT_IMAGE_URL,
            'source': a.source.name if a.source else "Unknown",
            'published_date': a.published_date,
            'author': a.author,
            'categories': a.categories,
            'is_fake': a.is_fake,
            'sentiment': a.sentiment,
            'recommendation_type': 'fallback'  # Add indicator that this is a fallback
        } for a in fallback_articles]
    
    # Calculate mean embedding from user's articles
    embeddings = [a.embedding for a in user_articles_with_embeddings if a.embedding is not None]
    embeddings_array = np.array(embeddings)
    mean_embedding = np.mean(embeddings_array, axis=0).tolist()
    
    # Query for similar articles, excluding already interacted ones
    base_query = Articles.objects.exclude(id__in=user_articles.values_list('id', flat=True))
    
    # Apply category filter
    if category.lower() != 'all categories':
        base_query = base_query.filter(categories__icontains=category)
    
    similar_articles = base_query.exclude(embedding=None) \
        .annotate(similarity=CosineDistance('embedding', mean_embedding)) \
        .order_by('similarity')
    
    # Paginate results
    start_idx = (page - 1) * page_size
    end_idx = start_idx + page_size
    paginated_articles = similar_articles[start_idx:end_idx]
    
    return [{
        'id': a.id,
        'title': a.title,
        'content': a.content[:200] + "..." if len(a.content) > 200 else a.content,
        'url': a.url,
        'image_url': a.image_url if a.image_url else DEFAULT_IMAGE_URL,
        'source': a.source.name if a.source else "Unknown",
        'published_date': a.published_date,
        'author': a.author,
        'categories': a.categories,
        'is_fake': a.is_fake,
        'sentiment': a.sentiment,
        'recommendation_type': 'similarity',  # Add indicator that this is a similarity-based recommendation
        'similarity_score': float(a.similarity) if hasattr(a, 'similarity') else None  # Add similarity score
    } for a in paginated_articles]

class ArticleCategoryView(APIView):
    """
    Return articles by category with pagination support and filtering
    """
    def get(self, request, category):
        page = int(request.query_params.get('page', 1))
        page_size = int(request.query_params.get('page_size', 10))
        sort = request.query_params.get('sort', 'newest')
        
        # Start with all articles if category is "All categories"
        if category.lower() == 'all categories':
            qs = Articles.objects.all()
        else:
            # Filter by specific category
            qs = Articles.objects.filter(categories__icontains=category)
        
        if sort == 'newest':
            qs = qs.order_by('-published_date')
        elif sort == 'oldest':
            qs = qs.order_by('published_date')
        elif sort == 'popular':
            qs = qs.annotate(num_likes=Count('like')).order_by('-num_likes', '-published_date')
        elif sort == 'recommendation' and request.user.is_authenticated:
            # Get recommendations for authenticated users
            try:
                articles = get_real_time_recommendations(request.user, category, page, page_size)
                
                return Response({
                    'category': category,
                    'articles': articles,
                    'page': page,
                    'page_size': page_size,
                    'has_more': len(articles) >= page_size  # Assume there are more if page is filled
                })
            except Exception as e:
                logger.error(f"Error generating recommendations: {e}")
                # Fall back to newest if recommendation fails
                qs = qs.order_by('-published_date')
        elif sort == 'random':
            qs = list(qs)
            random.shuffle(qs)
            # Convert back to a sliceable object
            start_idx = (page - 1) * page_size
            end_idx = start_idx + page_size
            articles = qs[start_idx:end_idx]
            
            data = [{
                'id': a.id,
                'title': a.title,
                'content': a.content[:200] + "..." if len(a.content) > 200 else a.content,
                'url': a.url,
                'image_url': a.image_url if a.image_url else DEFAULT_IMAGE_URL,
                'source': a.source.name if a.source else "Unknown",
                'published_date': a.published_date,
                'author': a.author,
                'categories': a.categories,
                'is_fake': a.is_fake,
                'sentiment': a.sentiment
            } for a in articles]
            
            return Response({
                'category': category,
                'articles': data,
                'page': page,
                'page_size': page_size,
                'has_more': len(qs) > (page * page_size)
            })
        
        # Paginate results for non-random sorting
        start_idx = (page - 1) * page_size
        end_idx = start_idx + page_size
        articles = qs[start_idx:end_idx]
        
        data = [{
            'id': a.id,
            'title': a.title,
            'content': a.content[:200] + "..." if len(a.content) > 200 else a.content,
            'url': a.url,
            'image_url': a.image_url if a.image_url else DEFAULT_IMAGE_URL,
            'source': a.source.name if a.source else "Unknown",
            'published_date': a.published_date,
            'author': a.author,
            'categories': a.categories,
            'is_fake': a.is_fake,
            'sentiment': a.sentiment
        } for a in articles]
        
        return Response({
            'category': category,
            'articles': data,
            'page': page,
            'page_size': page_size,
            'has_more': qs.count() > (page * page_size)
        })

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def toggle_saved(request):
    article_id = request.data.get('article_id')
    collection_name = request.data.get('collection_name')
    
    if not article_id or not collection_name:
        return Response({'error': 'Article ID and collection name are required'}, status=400)
    
    article = get_object_or_404(Articles, pk=article_id)
    
    collection, created = SavedCollection.objects.get_or_create(
        user=request.user,
        name=collection_name
    )
    
    # Check if article already saved in this collection
    saved_article = SavedArticle.objects.filter(
        user=request.user,
        article=article,
        collection=collection
    ).first()
    
    if saved_article:
        saved_article.delete()
        # Check if article exists in any other collection
        other_collections = SavedArticle.objects.filter(
            user=request.user,
            article=article
        ).exists()
        
        if not other_collections:
            # Update interaction to view only if not saved anywhere else
            UserInteraction.objects.update_or_create(
                user=request.user,
                article=article,
                defaults={
                    'interaction_type': 'view',
                    'strength': 0.5,
                    'timestamp': timezone.now()
                }
            )
        
        return Response({'saved': False, 'collection': collection_name})
    
    # Save to collection
    SavedArticle.objects.create(
        user=request.user,
        article=article,
        collection=collection
    )
    
    # Record save interaction
    UserInteraction.objects.update_or_create(
        user=request.user,
        article=article,
        defaults={
            'interaction_type': 'save',
            'strength': 3.0,  # Highest weight for saves (explicit interest)
            'timestamp': timezone.now()
        }
    )
    
    return Response({'saved': True, 'collection': collection_name})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def is_article_saved(request, article_id):
    article = get_object_or_404(Articles, pk=article_id)
    saved_articles = SavedArticle.objects.filter(
        user=request.user,
        article=article
    )
    
    if not saved_articles.exists():
        return Response({'saved': False})
    
    collections = [sa.collection.name for sa in saved_articles]
    return Response({'saved': True, 'collections': collections})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def collection_list(request):
    collections = SavedCollection.objects.filter(user=request.user)
    
    # Get count of articles in each collection
    data = []
    for collection in collections:
        article_count = SavedArticle.objects.filter(
            user=request.user,
            collection=collection
        ).count()
        
        # Get a sample article for cover image
        sample_article = SavedArticle.objects.filter(
            user=request.user,
            collection=collection
        ).first()
        
        image_url = None
        if sample_article and sample_article.article.image_url:
            image_url = sample_article.article.image_url
        
        data.append({
            'id': collection.id,
            'name': collection.name,
            'article_count': article_count,
            'created_at': collection.created_at,
            'cover_image': image_url or DEFAULT_IMAGE_URL
        })
    
    return Response({'collections': data})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def collection_detail(request, collection_id):
    collection = get_object_or_404(SavedCollection, pk=collection_id, user=request.user)
    article_count = SavedArticle.objects.filter(
        user=request.user,
        collection=collection
    ).count()
    
    return Response({
        'id': collection.id,
        'name': collection.name,
        'article_count': article_count,
        'created_at': collection.created_at
    })

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def collection_articles(request, collection_id):
    collection = get_object_or_404(SavedCollection, pk=collection_id, user=request.user)
    saved_articles = SavedArticle.objects.filter(
        user=request.user,
        collection=collection
    ).select_related('article').order_by('-created_at')
    
    articles = [{
        'id': sa.article.id,
        'title': sa.article.title,
        'content': sa.article.content[:200] + "..." if len(sa.article.content) > 200 else sa.article.content,
        'url': sa.article.url,
        'image_url': sa.article.image_url if sa.article.image_url else DEFAULT_IMAGE_URL,
        'source': sa.article.source.name if sa.article.source else "Unknown",
        'published_date': sa.article.published_date,
        'author': sa.article.author,
        'saved_at': sa.created_at
    } for sa in saved_articles]
    
    return Response({
        'collection_id': collection.id,
        'collection_name': collection.name,
        'articles': articles
    })

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def user_interaction_stats(request):
    likes_count = Like.objects.filter(user=request.user).count()
    comments_count = Comment.objects.filter(user=request.user).count()
    saved_count = SavedArticle.objects.filter(user=request.user).count()
    
    return Response({
        'likes_count': likes_count,
        'comments_count': comments_count,
        'saved_count': saved_count
    })

@api_view(['GET'])
def articles_null_category(request):
    """Get articles with null or empty categories"""
    try:
        page = int(request.query_params.get('page', 1))
        page_size = int(request.query_params.get('page_size', 10))
        
        # Query articles with null or empty categories
        from django.db import models
        from .models import Articles
        
        articles = Articles.objects.filter(
            models.Q(categories__isnull=True) | models.Q(categories='')
        ).order_by('-published_date')
        total_count = articles.count()
        
        # Paginate
        start_idx = (page - 1) * page_size
        end_idx = start_idx + page_size
        paginated_articles = articles[start_idx:end_idx]
        
        # Serialize
        DEFAULT_IMAGE_URL = 'https://raw.githubusercontent.com/mMelnic/news-fake-detection/refs/heads/users/news_aggregator/newspaper_beige.jpg'
        
        data = []
        for a in paginated_articles:
            article_data = {
                'id': a.id,
                'title': a.title,
                'content': a.content[:200] + "..." if len(a.content) > 200 else a.content,
                'url': a.url,
                'image_url': a.image_url if a.image_url and a.image_url != 'null' else DEFAULT_IMAGE_URL,
                'source': a.source.name if a.source else "Unknown",
                'published_date': a.published_date.isoformat() if a.published_date else None,
                'author': a.author,
                'categories': '',
                'is_fake': a.is_fake,
                'sentiment': a.sentiment
            }
            data.append(article_data)
        
        return Response({
            'articles': data,
            'page': page,
            'page_size': page_size,
            'total_count': total_count,
            'has_more': total_count > (page * page_size)
        })
    
    except Exception as e:
        import traceback
        logging.error(f"Error fetching null category articles: {e}")
        logging.error(traceback.format_exc())
        return Response({"error": str(e)}, status=500)

@api_view(['GET'])
def direct_search(request):
    """Direct synchronous search that returns articles immediately"""
    query = request.query_params.get('q', '')
    language = request.query_params.get('language', None)
    country = request.query_params.get('country', None)
    search_mode = request.query_params.get('mode', 'and')  # 'and' or 'or'
    
    if not query:
        return Response({"error": "Query parameter 'q' is required"}, status=400)
    
    try:
        # Process the search using the NewsAPI fetcher
        newsapi_fetcher = NewsApiFetcher()
        newsapi_articles = newsapi_fetcher.fetch_articles(query, language=language)
        
        # Process the search using GNews fetcher
        gnews_fetcher = GNewsApiFetcher()
        gnews_articles = gnews_fetcher.fetch_articles(query, language=language)
        
        # Combine results
        all_articles = newsapi_articles + gnews_articles
        DEFAULT_IMAGE_URL = 'https://raw.githubusercontent.com/mMelnic/news-fake-detection/refs/heads/users/news_aggregator/newspaper_beige.jpg'
        
        processed_articles = []
        for article in all_articles:
            # Extract data from the article
            title = article.get('title', '')
            url = article.get('url', '')
            content = article.get('content', '') or article.get('description', '')
            image_url = article.get('urlToImage') or article.get('image') or DEFAULT_IMAGE_URL
            author = article.get('author', 'Unknown')
            published_at = article.get('publishedAt', '') or article.get('published_date', '')
            
            # Handle source which might be a string or a dict
            if isinstance(article.get('source'), dict):
                source_name = article.get('source', {}).get('name', 'Unknown')
            else:
                source_name = article.get('source', 'Unknown')
            
            # Format published date
            from datetime import datetime
            if published_at:
                try:
                    from dateutil import parser
                    if isinstance(published_at, str):
                        parsed_date = parser.parse(published_at)
                        published_date = parsed_date.isoformat()
                    else:
                        published_date = published_at.isoformat()
                except Exception:
                    published_date = datetime.now().isoformat()
            else:
                published_date = datetime.now().isoformat()
            
            processed_article = {
                'id': str(uuid.uuid4()),  # Generate a temporary ID as string
                'title': title,
                'content': content,
                'url': url,
                'image_url': image_url,
                'author': author,
                'published_date': published_date,
                'source': source_name,
                'categories': '',
                'is_fake': False,  # Default, would need actual classification
                'sentiment': 'neutral'
            }
            
            processed_articles.append(processed_article)
        
        return Response({
            'articles': processed_articles,
            'count': len(processed_articles)
        })
    
    except Exception as e:
        import traceback
        logging.error(f"Search error: {e}")
        logging.error(traceback.format_exc())
        return Response({"error": str(e)}, status=500)