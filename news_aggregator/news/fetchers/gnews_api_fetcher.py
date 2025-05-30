from .base_fetcher import BaseFetcher
from .fetcher_interface import FetcherInterface
import os
from dotenv import load_dotenv

load_dotenv()

GNEWS_API_URL = "https://gnews.io/api/v4/search"
GNEWS_API_KEY = os.getenv('GNEWS_API_KEY')

class GNewsApiFetcher(BaseFetcher, FetcherInterface):
    VALID_LANGUAGES = {'ar', 'de', 'el', 'en', 'es', 'fr', 'he', 'hi', 'it', 'ja', 'ml', 'mr', 'nl', 'no', 'pt', 'ro', 'ru', 'sv', 'ta', 'te', 'uk', 'zh'}
    VALID_COUNTRIES = {'au', 'br', 'ca', 'cn', 'eg', 'fr', 'de', 'gr', 'hk', 'in', 'ie', 'il', 'it', 'jp', 'nl', 'no', 'pk', 'pe', 'ph', 'pt', 'ro', 'ru', 'sg', 'es', 'se', 'ch', 'tw', 'ua', 'gb', 'us'}

    def __init__(self):
        super().__init__()  # Call parent constructor to initialize logger
        self.api_key = GNEWS_API_KEY

    def fetch_articles(self, query, language=None, country=None):
        """
        Fetch articles from GNewsAPI with proper query formatting.
        
        GNews API has its own query syntax:
        - Quotes for exact phrases: "climate change"
        - AND operator: climate AND change
        - OR operator: climate OR change
        - NOT operator: climate NOT change
        - Parentheses for grouping: (climate OR weather) AND change
        """
        # Basic validation without URL encoding
        query = self._validate_and_format_query(query)
        language = self._validate_language(language)
        country = self._validate_country(country)
        
        # GNewsAPI also accepts the query syntax directly
        params = {
            "apikey": self.api_key,
            "q": query,  # Send the query as is - GNewsAPI handles the syntax
            "max": 10,
            "sortby": "relevance"
        }
        
        if language:
            params["lang"] = language
        if country:
            params["country"] = country

        articles = []
        try:
            self.logger.info(f"Fetching articles from GNewsAPI with query: {query}")
            response_data = self._send_request(GNEWS_API_URL, params)
            articles = response_data.get("articles", [])
            self.logger.info(f"Received {len(articles)} articles from GNewsAPI")
        except Exception as e:
            self.logger.error(f"Failed to fetch articles from GNewsAPI: {e}")

        return articles

    def _validate_language(self, language):
        """Validate the language parameter specific to GNews API."""
        if language and language not in self.VALID_LANGUAGES:
            raise ValueError(f"Invalid language code. Valid options are: {', '.join(self.VALID_LANGUAGES)}")
        return language

    def _validate_country(self, country):
        """Validate the country parameter specific to GNews API."""
        if country and country not in self.VALID_COUNTRIES:
            raise ValueError(f"Invalid country code. Valid options are: {', '.join(self.VALID_COUNTRIES)}")
        return country