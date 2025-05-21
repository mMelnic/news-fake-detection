from news.models import Keyword
from news.repositories.article_repository import ArticleRepository
from news.repositories.source_repository import SourceRepository

class ArticleService:
    def __init__(self):
        self.article_repo = ArticleRepository()
        self.source_repo = SourceRepository()

    def store_articles(self, articles, query):
        parsed_keywords = self._parse_query(query)

        for article in articles:
            source_name = article["source"]["name"]
            source_url = article["source"].get("url", source_name)

            source_obj, _ = self.source_repo.get_or_create_source(
                url=source_url,
                defaults={"name": source_name}
            )

            article_obj, created = self.article_repo.get_or_create_article(
                url=article["url"],
                defaults={
                    "title": article["title"],
                    "content": article.get("content", "") or "",
                    "source": source_obj,
                    "published_date": article["publishedAt"],
                    "location": None,
                    "fake_score": None,
                    "embedding": None,
                }
            )

            existing_keywords = set(article_obj.keywords.values_list('keyword', flat=True)) if not created else set()
            
            for keyword in parsed_keywords:
                if created or keyword not in existing_keywords:
                    keyword_obj, _ = Keyword.objects.get_or_create(keyword=keyword)
                    article_obj.keywords.add(keyword_obj)

    def _parse_query(self, query):
        import re
        phrases = re.findall(r'"(.*?)"', query)
        remaining_query = re.sub(r'"(.*?)"', '', query)
        keywords = re.findall(r'([+-]?\b(?!AND\b|OR\b|NOT\b)\w+\b)', remaining_query)
        keywords = [k for k in keywords if k.strip()]
        return phrases + keywords
