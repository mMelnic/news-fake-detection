from abc import ABC, abstractmethod
from news.models import Articles, Sources

class ArticleRepositoryInterface(ABC):
    @abstractmethod
    def get_or_create_article(self, **kwargs) -> Articles:
        pass

    @abstractmethod
    def get_article_by_url(self, url: str) -> Articles:
        pass

class SourceRepositoryInterface(ABC):
    @abstractmethod
    def get_or_create_source(self, **kwargs) -> Sources:
        pass