from abc import ABC, abstractmethod

class FetcherInterface(ABC):
    @abstractmethod
    def fetch_articles(self, query, language=None, country=None):
        pass