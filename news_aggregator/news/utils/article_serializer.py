from rest_framework import serializers
from news.models import Articles, Sources

class SourceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Sources
        fields = ['id', 'name', 'url']

class ArticleSerializer(serializers.ModelSerializer):
    source = SourceSerializer(read_only=True)

    class Meta:
        model = Articles
        fields = [
            'id',
            'title',
            'url',
            'content',
            'author',
            'image_url',
            'source',
            'published_date',
            'language',
            'country',
            'categories',
            'is_fake',
            'sentiment',
            'fake_score',
        ]
