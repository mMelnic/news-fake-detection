import feedparser

class RssFeedFetcher:
    def __init__(self):
        self.base_url = "https://news.google.com/rss"

    def fetch_feed(self, query, language="en", region="US"):
        """
        Fetches and parses the RSS feed from Google News based on the query, language, and region.
        :param query: The search term for the feed (e.g., "technology").
        :param language: The language code for the feed (default is 'en' for English).
        :param region: The region code for the feed (default is 'US' for the United States).
        :return: A list of parsed items, each containing relevant information (title, link, etc.).
        """
        rss_url = f"{self.base_url}/search?q={query}&hl={language}&gl={region}&ceid={region}:{language}"

        print(f"Fetching RSS feed from: {rss_url}")

        feed = feedparser.parse(rss_url)

        if feed.bozo:
            print("Warning: Issue with fetching or parsing the feed.")
            return []

        return self.parse_feed(feed)

    def parse_feed(self, feed):
        """
        Extracts relevant information from the parsed feed.
        :param feed: The parsed feed object from feedparser.
        :return: A list of dictionaries, each representing an item in the feed.
        """
        items = []
        for entry in feed.entries:
            items.append({
                "title": entry.get("title"),
                "link": entry.get("link"),
                "pub_date": entry.get("published"),
                "description": entry.get("summary"), # May contain HTML content
                "source": entry.get("source", {}).get("title"),
                "source_url": entry.get("source", {}).get("href")
            })

        return items

# Test usage
if __name__ == "__main__":
    fetcher = RssFeedFetcher()
    articles = fetcher.fetch_feed(query="tehnologie", language="ro", region="RO")  # Romanian for "technology"
    
    for article in articles:
        print(article)
