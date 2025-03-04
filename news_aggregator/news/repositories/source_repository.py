from news.models import Sources
from .interfaces import SourceRepositoryInterface

class SourceRepository(SourceRepositoryInterface):
    def get_or_create_source(self, **kwargs) -> Sources:
        source, created = Sources.objects.get_or_create(**kwargs)
        return source, created