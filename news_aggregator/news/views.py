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
        
        # Return the database articles immediately
        return Response({
            "message": message,
            "articles": db_articles,
            "article_count": len(db_articles),
            "from_db_only": not (force_refresh or len(db_articles) < 5)
        })
    
    def get_db_articles(self, query, language, country, fresh_only):
        """Get relevant articles from database"""
        logger.info(f"Searching database for articles matching: query={query}, language={language}, country={country}, fresh_only={fresh_only}")
        
        queryset = Articles.objects.all()
        
        # Apply keyword filtering
        keywords = query.split()
        if keywords:
            keyword_filter = Q()
            for keyword in keywords:
                keyword = keyword.lower().strip()
                if len(keyword) > 2:  # Skip very short words
                    keyword_filter |= Q(keywords__keyword__icontains=keyword)
                    # Also search in title for better results
                    keyword_filter |= Q(title__icontains=keyword)
            
            queryset = queryset.filter(keyword_filter)
        
        # Apply language filter if available
        if language:
            queryset = queryset.filter(source__language=language)
            
        # Apply country filter if available
        if country:
            queryset = queryset.filter(country=country)
            
        # Apply freshness filter if requested
        if fresh_only:
            # Get articles less than 24 hours old
            one_day_ago = timezone.now() - timedelta(days=1)
            queryset = queryset.filter(published_date__gte=one_day_ago)
            
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
                "has_embedding": article.embedding is not None
            }
            for article in queryset[:50]  # Limit to 50 most recent matching articles
        ]
        
    def fetch_new_articles(self, query, language, country):
        """Fetch new articles from APIs in background"""
        try:
            logger.info(f"Fetching new articles from APIs: query={query}, language={language}, country={country}")
            
            # Create a unique identifier for this query to avoid duplicates
            query_hash = hashlib.md5(f"{query}:{language}:{country}".encode()).hexdigest()
            
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
                articles.extend(news_api_articles)
                logger.info(f"Fetched {len(news_api_articles)} articles from NewsAPI")
            except Exception as e:
                logger.error(f"Error fetching from NewsAPI: {e}")
            
            try:
                gnews_articles = gnews_fetcher.fetch_articles(query, language, country)
                # Add query information
                for article in gnews_articles:
                    article['query'] = query
                articles.extend(gnews_articles)
                logger.info(f"Fetched {len(gnews_articles)} articles from GNewsAPI")
            except Exception as e:
                logger.error(f"Error fetching from GNewsAPI: {e}")
                
            try:
                rss_articles = rss_fetcher.fetch_feed(query, language, country)
                # RSS articles are already normalized in the fetcher
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
                "has_embedding": article.embedding is not None
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