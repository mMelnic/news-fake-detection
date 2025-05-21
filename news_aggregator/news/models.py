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
    content = models.TextField()
    url = models.TextField(unique=True)
    source = models.ForeignKey('Sources', models.SET_NULL, blank=True, null=True)
    published_date = models.DateTimeField(blank=True, null=True)
    category = models.TextField(blank=True, null=True)
    location = models.TextField(blank=True, null=True)
    fake_score = models.FloatField(blank=True, null=True)
    embedding = VectorField(dimensions=768, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    keywords = models.ManyToManyField(Keyword, related_name='articles')

    class Meta:
        managed = True
        db_table = 'articles'
        indexes = [
            models.Index(fields=['published_date']),
            models.Index(fields=['source']),
            models.Index(fields=['category']),
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
    interaction_type = models.CharField(max_length=50, default='view')  # e.g., 'view', 'like'
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'article')

class Recommendation(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    article = models.ForeignKey('Articles', on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)