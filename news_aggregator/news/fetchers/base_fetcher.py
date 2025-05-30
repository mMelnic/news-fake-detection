import requests
from urllib.parse import quote
import logging

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

class BaseFetcher:
    def __init__(self):
        self.logger = logger
        
    def _validate_and_format_query(self, query):
        """Validate the search query but don't format it - leave that to specific API fetchers."""
        if not query or not isinstance(query, str):
            raise ValueError("Query must be a non-empty string.")
        if len(query) > 500:
            raise ValueError("Query must not exceed 500 characters.")
        return query.strip()  # Just return the trimmed query without URL encoding

    def _send_request(self, url, params, headers=None):
        """Send an HTTP GET request and return the response."""
        logger.debug(f"Sending request to {url} with params: {params} and headers: {headers}")
        response = requests.get(url, params=params, headers=headers)
        logger.debug(f"Received response: {response.status_code}, {response.text}")

        if response.status_code != 200:
            logger.error(f"Error {response.status_code}: {response.json()}")
            raise Exception(f"Error {response.status_code}: {response.json()}")

        return response.json()