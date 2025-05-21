from celery import shared_task
from pgvector.django import CosineDistance
from .models import Articles, UserInteraction, Recommendation, Sources, Keyword
from django.contrib.auth import get_user_model
import numpy as np
from sentence_transformers import SentenceTransformer
import pyfiglet
import logging

logger = logging.getLogger(__name__)

# Load embedding model (use a lightweight option)
embedding_model = SentenceTransformer("all-MiniLM-L6-v2")

@shared_task
def store_articles_async(articles):
    for article in articles:
        try:
            # Ensure source is stored correctly
            source_data = article.get("source", {})
            source_obj, _ = Sources.objects.get_or_create(
                url=source_data.get("url", ""),
                defaults={"name": source_data.get("name", "Unknown")}
            )

            # Create or update article
            article_obj, _ = Articles.objects.update_or_create(
                url=article["url"],
                defaults={
                    "title": article["title"],
                    "author": article.get("author", "Unknown"),
                    "content": article.get("content", ""),
                    "image_url": article.get("urlToImage", ""),
                    "source": source_obj,
                    "published_date": article.get("publishedAt"),
                    "location": source_data.get("country", None),
                    "fake_score": None,  # Placeholder
                }
            )

            # Compute vector embedding for recommendations
            text_embedding = embedding_model.encode(article_obj.title + " " + article_obj.content).tolist()
            article_obj.embedding = text_embedding
            article_obj.save()

            # Store keywords
            keywords = article["title"].split(" ") + article["description"].split(" ")
            for keyword in set(keywords):
                keyword_obj, _ = Keyword.objects.get_or_create(keyword=keyword.lower())
                article_obj.keywords.add(keyword_obj)

        except Exception as e:
            logger.error(f"Error storing article: {e}")



User = get_user_model()

@shared_task
def generate_recommendations(user_id):
    user = User.objects.get(id=user_id)

    interactions = UserInteraction.objects.filter(user=user)
    interacted_articles = Articles.objects.filter(id__in=interactions.values_list('article_id', flat=True))

    if not interacted_articles.exists():
        return

    # Mean embedding of interacted articles
    embeddings = np.array([a.embedding for a in interacted_articles if a.embedding is not None])
    if embeddings.size == 0:
        return

    mean_embedding = np.mean(embeddings, axis=0).tolist()

    # Query
    similar_articles = Articles.objects \
        .exclude(id__in=interacted_articles.values_list('id', flat=True)) \
        .exclude(embedding=None) \
        .annotate(similarity=CosineDistance('embedding', mean_embedding)) \
        .order_by('similarity')[:10]

    # Top recommendations
    Recommendation.objects.filter(user=user).delete()
    for article in similar_articles:
        Recommendation.objects.create(user=user, article=article)