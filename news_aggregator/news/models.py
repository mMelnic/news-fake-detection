# This is an auto-generated Django model module.
# You'll have to do the following manually to clean this up:
#   * Rearrange models' order
#   * Make sure each model has one field with primary_key=True
#   * Make sure each ForeignKey and OneToOneField has `on_delete` set to the desired behavior
#   * Remove `managed = False` lines if you wish to allow Django to create, modify, and delete the table
# Feel free to rename the models, but don't rename db_table values or field names.
from django.db import models
from django.utils import timezone
from pgvector.django import VectorField
from django.conf import settings
from django.db import models

class Keyword(models.Model):
    keyword = models.TextField(unique=True)

    def __str__(self):
        return self.keyword

class Articles(models.Model):
    title = models.TextField()
    author = models.TextField(blank=True, null=True)
    content = models.TextField()
    url = models.TextField(unique=True)
    image_url = models.TextField(blank=True, null=True)
    source = models.ForeignKey('Sources', models.SET_NULL, blank=True, null=True)
    published_date = models.DateTimeField(blank=True, null=True)
    country = models.TextField(blank=True, null=True)
    fake_score = models.FloatField(blank=True, null=True)  # For backward compatibility
    is_fake = models.BooleanField(blank=True, null=True)   # New field: True=fake, False=real
    sentiment = models.CharField(max_length=10, blank=True, null=True)  # New field: 'positive' or 'negative'
    embedding = VectorField(dimensions=384, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    keywords = models.ManyToManyField(Keyword, related_name='articles')
    language = models.CharField(max_length=10, blank=True, null=True)
    categories = models.TextField(blank=True, null=True)
    feed = models.ForeignKey('Feed', on_delete=models.SET_NULL, null=True, blank=True)

    class Meta:
        managed = True
        db_table = 'articles'
        indexes = [
            models.Index(fields=['published_date']),
            models.Index(fields=['source']),
            models.Index(fields=['is_fake']),
            models.Index(fields=['sentiment']),
        ]


class Sources(models.Model):
    name = models.TextField()
    url = models.TextField(unique=True)
    country = models.TextField(blank=True, null=True)
    language = models.TextField(blank=True, null=True)
    last_fetched = models.DateTimeField(default=timezone.now)

    class Meta:
        managed = True
        db_table = 'sources'

class UserInteraction(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    article = models.ForeignKey('Articles', on_delete=models.CASCADE)
    interaction_type = models.CharField(max_length=50, default='view')  # 'view', 'like', 'save', 'comment'
    timestamp = models.DateTimeField(auto_now_add=True)
    strength = models.FloatField(default=1.0)

    class Meta:
        indexes = [
            models.Index(fields=['user', 'interaction_type']),
            models.Index(fields=['article']),
            models.Index(fields=['timestamp']),
        ]

class Recommendation(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    article = models.ForeignKey('Articles', on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

class Like(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    article = models.ForeignKey(Articles, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'article')


class Comment(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    article = models.ForeignKey(Articles, on_delete=models.CASCADE)
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

class Feed(models.Model):
    url = models.URLField(unique=True)
    title = models.TextField()
    description = models.TextField(blank=True, null=True)
    source = models.ForeignKey('Sources', on_delete=models.CASCADE, blank=True, null=True)
    category = models.TextField(blank=True, null=True)
    country = models.TextField(blank=True, null=True)
    language = models.TextField(blank=True, null=True)
    last_built = models.DateTimeField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'feeds'

    def __str__(self):
        return f"{self.title} ({self.url})"

class SavedCollection(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ('user', 'name')
        
    def __str__(self):
        return f"{self.user.username} - {self.name}"

class SavedArticle(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    article = models.ForeignKey(Articles, on_delete=models.CASCADE)
    collection = models.ForeignKey(SavedCollection, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ('user', 'article', 'collection')