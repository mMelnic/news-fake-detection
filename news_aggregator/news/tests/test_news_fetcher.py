from django.test import TestCase
from unittest.mock import patch, MagicMock
from requests.models import Response
from news.fetchers.news_api_fetcher import NewsApiFetcher

class NewsFetcherTestCase(TestCase):

    def setUp(self):
        """Initialize a NewsFetcher instance."""
        self.fetcher = NewsApiFetcher()

    def test_validate_and_format_query(self):
        """Test if queries are validated and properly URL-encoded."""
        test_cases = [
            ('crypto AND (ethereum OR litecoin) NOT bitcoin', 'crypto%20AND%20%28ethereum%20OR%20litecoin%29%20NOT%20bitcoin'),
            ('"climate change" AND +renewable -fossil', '%22climate%20change%22%20AND%20%2Brenewable%20-fossil'),
            ('("artificial intelligence" OR AI) AND -bias', '%28%22artificial%20intelligence%22%20OR%20AI%29%20AND%20-bias'),
            ('+technology AND "self-driving cars" NOT Uber', '%2Btechnology%20AND%20%22self-driving%20cars%22%20NOT%20Uber'),
        ]

        for query, expected_encoded in test_cases:
            with self.subTest(query=query):
                encoded_query = self.fetcher._validate_and_format_query(query)
                self.assertEqual(encoded_query, expected_encoded)

    def test_invalid_queries(self):
        """Test invalid query cases."""
        with self.assertRaises(ValueError):
            self.fetcher._validate_and_format_query(None)
        
        with self.assertRaises(ValueError):
            self.fetcher._validate_and_format_query(123)  # Not a string

        with self.assertRaises(ValueError):
            self.fetcher._validate_and_format_query("")  # Empty string
        
        with self.assertRaises(ValueError):
            self.fetcher._validate_and_format_query("a" * 501)  # Exceeds max length

    @patch('requests.get')
    def test_fetch_articles_partial_results(self, mock_get):
        # Setup mock response to simulate the first page with 100 articles
        mock_response_1 = MagicMock(spec=Response)
        mock_response_1.status_code = 200
        mock_response_1.json.return_value = {
            "status": "ok",
            "totalResults": 120,  # Total results across all pages
            "articles": [
                {"title": f"Article {i+1}", "description": f"Description {i+1}"}
                for i in range(100)  # First page returns 100 articles
            ]
        }
        
        # Simulate that only the first page is fetched
        mock_get.return_value = mock_response_1

        fetcher = NewsApiFetcher()

        # Fetch articles
        articles = fetcher.fetch_articles("test query", "en")

        # Assert that exactly 100 articles were fetched
        self.assertEqual(len(articles), 100)

        # Check that requests.get was called exactly once for the first page
        mock_get.assert_called_once_with("https://newsapi.org/v2/everything", params={
            "apiKey": fetcher.api_key,
            "q": "test%20query",
            "sortBy": "popularity",
            "pageSize": 100,
            "language": "en",
            "page": 1
        })

        # Ensure no additional API calls for the second page or beyond
        self.assertEqual(mock_get.call_count, 1)  # Only 1 call should be made for page 1