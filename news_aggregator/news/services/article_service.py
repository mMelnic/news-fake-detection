from news.models import Articles, Sources, Keyword
from django.utils.timezone import now
from django.db.utils import IntegrityError

class ArticleService:
    def store_articles(self, articles, query):
        parsed_keywords = self._parse_query(query)

        for article in articles:
            source_name = article["source"]["name"]
            source_url = article["source"].get("url", source_name)
            try:
                source_obj, _ = Sources.objects.get_or_create(
                    url=source_url,
                    defaults=source_name
                )

                article_obj, created = Articles.objects.get_or_create(
                    url=article["url"],
                    defaults={
                        "title": article["title"],
                        "content": article["content"] or "",
                        "source": source_obj,
                        "published_date": article["publishedAt"],
                        "category": None,
                        "location": None,
                        "fake_score": None,
                        "embedding": None,
                        "created_at": now(),
                    }
                )

            except IntegrityError:
                print(f"Skipping duplicate article: {article['url']}")
                article_obj = Articles.objects.get(url=article["url"])
                created = False

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
