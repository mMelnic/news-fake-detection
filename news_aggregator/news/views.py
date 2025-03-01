from django.shortcuts import render

# Create your views here.

from news.fetchers.news_api_fetcher import NewsApiFetcher
from news.services.article_service import ArticleService
from news.utils.storage import get_cached_result, cache_result

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
