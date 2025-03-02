import requests
from urllib.parse import quote
from datetime import datetime, timedelta
import os

NEWS_API_URL = "https://newsapi.org/v2/everything"
NEWS_API_KEY = os.getenv('NEWS_API_KEY')
MAX_PAGES = 5
VALID_LANGUAGES = {'ar', 'de', 'en', 'es', 'fr', 'he', 'it', 'nl', 'no', 'pt', 'ru', 'sv', 'ud', 'zh'}

class NewsApiFetcher:
    def __init__(self):
        self.api_key = NEWS_API_KEY

    def fetch_articles(self, query, language=None):
        query = self._validate_and_format_query(query)
        language = self._validate_language(language)
        articles = self._fetch_from_api(query, language)
        return articles

    def _fetch_from_api(self, query, language):
        one_week_ago = (datetime.now() - timedelta(days=7)).isoformat()

        params = {
            "apiKey": self.api_key,
            "q": query,
            "sortBy": "popularity",
            "pageSize": 100,
            "from": one_week_ago,
        }
        if language:
            params["language"] = language

        response = requests.get(NEWS_API_URL, params=params)
        if response.status_code != 200:
            raise Exception(f"Error {response.status_code}: {response.json()}")

        data = response.json()
        articles = data.get("articles", [])
        return articles

    def _validate_and_format_query(self, query):
        if not query or not isinstance(query, str):
            raise ValueError("Query must be a non-empty string.")
        if len(query) > 500:
            raise ValueError("Query must not exceed 500 characters.")
        return quote(query.strip())

    def _validate_language(self, language):
        if language and language not in VALID_LANGUAGES:
            raise ValueError(f"Invalid language code. Valid options are: {', '.join(VALID_LANGUAGES)}")
        return language
