from datetime import datetime, timedelta
import os
from .base_fetcher import BaseFetcher
from .fetcher_interface import FetcherInterface

NEWS_API_URL = "https://newsapi.org/v2/everything"
NEWS_API_KEY = os.getenv('NEWS_API_KEY')
MAX_PAGES = 5
VALID_LANGUAGES = {'ar', 'de', 'en', 'es', 'fr', 'he', 'it', 'nl', 'no', 'pt', 'ru', 'sv', 'ud', 'zh'}

class NewsApiFetcher(BaseFetcher, FetcherInterface):
    def __init__(self):
        super().__init__()  # Call parent constructor to initialize logger
        self.api_key = NEWS_API_KEY

    def fetch_articles(self, query, language=None, country=None):
        """
        Fetch articles from NewsAPI with proper query formatting.
        
        NewsAPI supports advanced search syntax:
        - Quoted phrases for exact matches: "climate change"
        - Required terms with +: +bitcoin
        - Excluded terms with -: -bitcoin
        - AND/OR/NOT operators: crypto AND (ethereum OR litecoin) NOT bitcoin
        """
        # Basic validation without URL encoding yet
        query = self._validate_and_format_query(query)
        language = self._validate_language(language)
        one_week_ago = (datetime.now() - timedelta(days=7)).isoformat()

        # For NewsAPI, we don't need to transform the query syntax
        # It already supports quotes for exact phrases and AND/OR operators
        
        params = {
            "apiKey": self.api_key,
            "q": query,  # Send the query as is - NewsAPI handles the syntax
            "sortBy": "popularity",
            "pageSize": 100,
            "from": one_week_ago,
        }
        
        if language:
            params["language"] = language

        articles = []
        try:
            self.logger.info(f"Fetching articles from NewsAPI with query: {query}")
            response_data = self._send_request(NEWS_API_URL, params)
            articles = response_data.get("articles", [])
            self.logger.info(f"Received {len(articles)} articles from NewsAPI")
        except Exception as e:
            self.logger.error(f"Failed to fetch articles from NewsAPI: {e}")

        return articles

    def _validate_language(self, language):
        if language and language not in VALID_LANGUAGES:
            raise ValueError(f"Invalid language code. Valid options are: {', '.join(VALID_LANGUAGES)}")
        return language