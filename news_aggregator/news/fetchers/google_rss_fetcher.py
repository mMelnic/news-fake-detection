import feedparser
import html
import re
import logging

logger = logging.getLogger(__name__)

class RssFeedFetcher:
    def __init__(self):
        self.base_url = "https://news.google.com/rss"

    def fetch_feed(self, query, language="en", country="US"):
        """
        Fetches and parses the RSS feed from Google News based on the query, language, and region.
        :param query: The search term for the feed (e.g., "technology").
        :param language: The language code for the feed (default is 'en' for English).
        :param country: The region code for the feed (default is 'US' for the United States).
        :return: A list of parsed items, each containing relevant information (title, link, etc.).
        """
        rss_url = f"{self.base_url}/search?q={query}&hl={language}&gl={country}&ceid={country}:{language}"

        logger.info(f"Fetching RSS feed from: {rss_url}")

        feed = feedparser.parse(rss_url)

        if feed.bozo:
            logger.warning("Issue with fetching or parsing the feed.")
            return []

        normalized_articles = self.parse_feed(feed, query, language, country)
        logger.info(f"Found {len(normalized_articles)} articles from RSS feed")
        return normalized_articles

    def parse_feed(self, feed, query, language, country):
        """
        Extracts relevant information from the parsed feed and normalizes the data structure.
        :param feed: The parsed feed object from feedparser.
        :param query: Original search query.
        :param language: Language code used in the query.
        :param country: Country code used in the query.
        :return: A list of dictionaries with normalized article format.
        """
        normalized_articles = []
        
        for entry in feed.entries:
            # Extract source from HTML description if needed
            source_name = entry.get("source", "")
            source_url = ""
            
            # Some entries have source as an attribute, others embed it in the description
            if isinstance(source_name, dict):
                source_url = source_name.get("href", "")
                source_name = source_name.get("title", "")
            elif "source_url" in entry:
                source_url = entry.get("source_url", "")
            
            # Extract real content from description (remove HTML tags)
            description = entry.get("summary", "")
            if description:
                # Remove HTML tags
                clean_description = re.sub(r'<.*?>', '', description)
                # Decode HTML entities
                clean_description = html.unescape(clean_description)
            else:
                clean_description = ""
            
            # If description still contains the source info at the end, extract it
            if not source_name and "target=\"_blank\">" in description:
                try:
                    source_part = description.split("</a>&nbsp;&nbsp;<font color=\"#6f6f6f\">")[1]
                    source_name = source_part.split("</font>")[0]
                except (IndexError, AttributeError):
                    pass
                
            # If no source URL found but we have a source name, try to guess URL
            if not source_url and source_name:
                # Simple heuristic to generate a likely source URL
                domain = source_name.lower().replace(' ', '').replace('.', '')
                source_url = f"https://www.{domain}.com"
            
            normalized_article = {
                "title": entry.get("title", ""),
                "url": entry.get("link", ""),  # Use link as the URL
                "content": clean_description,
                "publishedAt": entry.get("published", ""),
                "author": "",
                "source": {
                    "name": source_name,
                    "url": source_url
                },
                "language": language,
                "country": country,
                "query": query
            }
            
            normalized_articles.append(normalized_article)
            
        return normalized_articles

# Test usage
if __name__ == "__main__":
    fetcher = RssFeedFetcher()
    articles = fetcher.fetch_feed(query="tehnologie", language="ro", country="RO")
    
    for article in articles:
        print(article)
