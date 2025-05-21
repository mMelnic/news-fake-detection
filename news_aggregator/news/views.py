from django.shortcuts import render
from news.fetchers.news_api_fetcher import NewsApiFetcher
from news.fetchers.gnews_api_fetcher import GNewsApiFetcher
from news.fetchers.google_rss_fetcher import RssFeedFetcher
from news.services.article_service import ArticleService
from news.utils.storage import get_cached_result, cache_result
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import Recommendation
from .tasks import generate_recommendations

from rest_framework.views import APIView
from rest_framework.response import Response

class NewsAggregatorView(APIView):
    def get(self, request):
        query = request.query_params.get("query", "technology")  # Default query
        language = request.query_params.get("language", "en")
        country = request.query_params.get("country", None)

        news_fetcher = NewsApiFetcher()
        gnews_fetcher = GNewsApiFetcher()
        rss_fetcher = RssFeedFetcher()

        articles = []
        
        # Fetch from NewsAPI
        articles.extend(news_fetcher.fetch_articles(query, language))
        
        # Fetch from GNews
        articles.extend(gnews_fetcher.fetch_articles(query, language, country))
        
        # Fetch from Google RSS
        articles.extend(rss_fetcher.fetch_feed(query, language, country))

        return Response({"articles": articles})


def fetch_and_store_articles(query, language=None):
    fetcher = NewsApiFetcher()
    article_service = ArticleService()

    cached_result = get_cached_result(query, language)
    if cached_result:
        return cached_result

    articles = fetcher.fetch_articles(query, language)
    if articles:
        article_service.store_articles(articles, query)
        cache_result(query, language, articles)
    return articles

class RecommendationView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        recs = Recommendation.objects.filter(user=request.user)
        data = [{'id': r.article.id, 'title': r.article.title, 'url': r.article.url} for r in recs]
        return Response(data)

    def post(self, request):
        generate_recommendations.delay(request.user.id)
        return Response({'status': 'Recommendation task started'})