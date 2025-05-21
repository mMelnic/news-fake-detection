from django.shortcuts import render
from news.fetchers.news_api_fetcher import NewsApiFetcher
from news.fetchers.gnews_api_fetcher import GNewsApiFetcher
from news.fetchers.google_rss_fetcher import RssFeedFetcher
from news.services.article_service import ArticleService
from news.utils.storage import get_cached_result, cache_result
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import Recommendation, Articles, UserInteraction
from .tasks import generate_recommendations, store_articles_batch, store_article_async
from django.utils import timezone
from datetime import timedelta
import logging
from django.db.models import Q
import hashlib

logger = logging.getLogger(__name__)

class NewsAggregatorView(APIView):
    def get(self, request):
        query = request.query_params.get("query", "technology")  # Default query
        language = request.query_params.get("language", "en")
        country = request.query_params.get("country", None)
        fresh_only = request.query_params.get("fresh_only", "true").lower() == "true"
        force_refresh = request.query_params.get("refresh", "false").lower() == "true"
        
        # First, check for existing articles in database
        db_articles = self.get_db_articles(query, language, country, fresh_only)
        
        # Only fetch from API if we have few results or force refresh is requested
        if force_refresh or len(db_articles) < 5:
            self.fetch_new_articles(query, language, country)
            message = "Fetched from database. Additional articles are being loaded from external sources."
        else:
            message = "Fetched from database only. Use refresh=true parameter to fetch new articles."
        
        # Include WebSocket information in the response
        websocket_info = {
            "use_websocket": True,
            "websocket_url": f"ws://{request.get_host()}/ws/news/?query={query}&language={language}&country={country or 'all'}"
        }
        
        # Return the database articles immediately
        return Response({
            "message": message,
            "articles": db_articles,
            "article_count": len(db_articles),
            "from_db_only": not (force_refresh or len(db_articles) < 5),
            "websocket": websocket_info
        })
    
    def get_db_articles(self, query, language, country, fresh_only):
        """Get relevant articles from database"""
        logger.info(f"Searching database for articles matching: query={query}, language={language}, country={country}, fresh_only={fresh_only}")
        
        queryset = Articles.objects.all()
        
        # Apply keyword filtering using improved parsing
        if query:
            keyword_filter = self._build_keyword_filter(query)
            if keyword_filter:
                queryset = queryset.filter(keyword_filter)
    
        # Apply language filter if available
        if language:
            queryset = queryset.filter(Q(source__language=language) | Q(source__language__isnull=True))
            
        # Apply country filter if available
        if country:
            queryset = queryset.filter(Q(country=country) | Q(country__isnull=True))
            
        # Apply freshness filter if requested
        if fresh_only:
            # Get articles less than 24 hours old
            one_day_ago = timezone.now() - timedelta(days=1)
            queryset = queryset.filter(Q(published_date__gte=one_day_ago) | Q(published_date__isnull=True))
            
        # Order by most recent first
        queryset = queryset.order_by('-published_date').distinct()
        
        # Log result count
        article_count = queryset.count()
        logger.info(f"Found {article_count} articles in database matching criteria")
        
        # Convert to list of dictionaries
        return [
            {
                "id": article.id,
                "title": article.title,
                "content": article.content[:200] + "..." if len(article.content) > 200 else article.content,
                "url": article.url,
                "image_url": article.image_url,
                "author": article.author,
                "published_date": article.published_date,
                "source": article.source.name if article.source else "Unknown",
                "has_embedding": article.embedding is not None,
                "is_fake": article.is_fake,
                "fake_score": article.fake_score,  # Keep for backward compatibility
                "sentiment": article.sentiment
            }
            for article in queryset[:50]  # Limit to 50 most recent matching articles
        ]
        
    def _build_keyword_filter(self, query):
        """Build a Q filter for keywords based on parsed query."""
        import re
        
        # Extract phrases (quoted text)
        phrases = re.findall(r'"(.*?)"', query)
        
        # Remove phrases from query
        remaining_query = re.sub(r'"(.*?)"', '', query)
        
        # Extract individual keywords, ignoring logical operators
        keywords = re.findall(r'([+-]?\b(?!AND\b|OR\b|NOT\b)\w+\b)', remaining_query)
        keywords = [k.lower() for k in keywords if k.strip() and len(k.strip()) > 2]
        
        # Combine with phrases
        all_terms = keywords + phrases
        
        if not all_terms:
            return None
        
        # Build Q filter for exact phrase matches and individual keywords
        keyword_filter = Q()
        
        # Add phrase matches (title contains the exact phrase)
        for phrase in phrases:
            keyword_filter |= Q(title__icontains=phrase)
    
        # Add keyword matches (either in keywords table or title)
        for keyword in keywords:
            keyword_filter |= Q(keywords__keyword=keyword) | Q(title__icontains=keyword)
    
        return keyword_filter
    
    def fetch_new_articles(self, query, language, country):
        """Fetch new articles from APIs in background"""
        try:
            logger.info(f"Fetching new articles from APIs: query={query}, language={language}, country={country}")
            
            # Parse query to extract keywords for better article matching
            from .tasks import _parse_query
            keywords = _parse_query(query)
            logger.info(f"Extracted keywords from query: {keywords}")
            
            news_fetcher = NewsApiFetcher()
            gnews_fetcher = GNewsApiFetcher()
            rss_fetcher = RssFeedFetcher()
            
            # Gather articles from all sources
            articles = []
            
            try:
                news_api_articles = news_fetcher.fetch_articles(query, language)
                # Add query, language and country information
                for article in news_api_articles:
                    article['language'] = language
                    article['country'] = country
                    article['query'] = query
                    article['keywords'] = keywords  # Add parsed keywords
                articles.extend(news_api_articles)
                logger.info(f"Fetched {len(news_api_articles)} articles from NewsAPI")
            except Exception as e:
                logger.error(f"Error fetching from NewsAPI: {e}")
            
            try:
                gnews_articles = gnews_fetcher.fetch_articles(query, language, country)
                # Add query information
                for article in gnews_articles:
                    article['query'] = query
                    article['keywords'] = keywords  # Add parsed keywords
                articles.extend(gnews_articles)
                logger.info(f"Fetched {len(gnews_articles)} articles from GNewsAPI")
            except Exception as e:
                logger.error(f"Error fetching from GNewsAPI: {e}")
                
            try:
                rss_articles = rss_fetcher.fetch_feed(query, language, country)
                # Add keywords to RSS articles
                for article in rss_articles:
                    if 'keywords' not in article:
                        article['keywords'] = keywords
                articles.extend(rss_articles)
                logger.info(f"Fetched {len(rss_articles)} articles from RSS feed")
            except Exception as e:
                logger.error(f"Error fetching from RSS feed: {e}")
        
            logger.info(f"Total articles fetched from all sources: {len(articles)}")
            
            # Send to background processing - in batches to avoid overloading
            batch_size = 10
            for i in range(0, len(articles), batch_size):
                batch = articles[i:i+batch_size]
                # Pass the query parameter to enable WebSocket updates
                store_articles_batch.delay(batch, query)
                
        except Exception as e:
            # Log error but continue - we already returned DB results
            logger.error(f"Error fetching new articles: {str(e)}")


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
                "sentiment": article.sentiment
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