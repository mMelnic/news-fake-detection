from news.models import Articles
from .interfaces import ArticleRepositoryInterface
from django.utils.timezone import now
from django.db.utils import IntegrityError

class ArticleRepository(ArticleRepositoryInterface):
    def get_or_create_article(self, **kwargs) -> Articles:
        try:
            article, created = Articles.objects.get_or_create(**kwargs)
            if created:
                article.created_at = now()
                article.save()
            return article, created
        except IntegrityError:
            return Articles.objects.get(url=kwargs['url']), False

    def get_article_by_url(self, url: str) -> Articles:
        return Articles.objects.get(url=url)