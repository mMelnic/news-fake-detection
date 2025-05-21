from celery import shared_task
from pgvector.django import CosineDistance
from .models import Articles, UserInteraction, Recommendation, Sources, Keyword
from django.contrib.auth import get_user_model
import numpy as np
from sentence_transformers import SentenceTransformer
import logging
import traceback
from django.utils import timezone
from datetime import timedelta
import re
from dateutil import parser

logger = logging.getLogger(__name__)

# Load embedding model (use a lightweight option) - outside of tasks
# This will be loaded once when the module is imported
try:
    logger.info("Initializing SentenceTransformer model...")
    embedding_model = SentenceTransformer("all-MiniLM-L6-v2")
    logger.info("SentenceTransformer model initialized successfully")
except Exception as e:
    logger.error(f"Error initializing SentenceTransformer: {str(e)}")
    embedding_model = None

@shared_task(bind=True, max_retries=3)
def store_article_async(self, article, query=None):
    """Store a single article asynchronously"""
    logger.info("Started fetching articles in store_article_async")

    try:
        logger.debug(f"Processing article: {article.get('title', 'Unknown')[:50]}...")
        
        # Extract normalized source information based on different API formats
        source_data = {}
        if "source" in article:
            # Handle different source formats
            if isinstance(article["source"], dict):
                # NewsAPI and GNews format
                source_data = {
                    "name": article["source"].get("name", "Unknown"),
                    "url": article["source"].get("url", article["source"].get("id", "")),
                }
            elif isinstance(article["source"], str):
                # RSS feed format in some cases
                source_data = {
                    "name": article["source"],
                    "url": article.get("source_url", "")
                }
        
        # Create source object
        source_obj, _ = Sources.objects.get_or_create(
            url=source_data.get("url", ""),
            defaults={
                "name": source_data.get("name", "Unknown"),
                "country": article.get("country", None),
                "language": article.get("language", None)
            }
        )

        # Normalize article fields
        title = article.get("title", "")
        
        # Handle different URL field names
        url = article.get("url", article.get("link", ""))
        if not url:  # Ensure we have a URL
            logger.warning(f"Article missing URL: {title}")
            return None
            
        # Handle different content field names
        content = article.get("content", article.get("description", ""))
            
        # Handle different image URL field names
        image_url = article.get("urlToImage", article.get("image", ""))
            
        # Handle different published date field names
        published_at_raw = article.get("publishedAt", article.get("pub_date", None))
        published_at = None
        if published_at_raw:
            try:
                published_at = parser.parse(published_at_raw)
            except Exception as e:
                logger.warning(f"Could not parse publishedAt '{published_at_raw}' for article '{article.get('title', '')[:50]}': {e}")
                logger.debug(f"Creating/updating article with URL: {url}")
                    
        # Create or update article
        article_obj, created = Articles.objects.update_or_create(
            url=url,
            defaults={
                "title": title,
                "author": article.get("author", "Unknown"),
                "content": content,
                "image_url": image_url,
                "source": source_obj,
                "published_date": published_at,
                "country": article.get("country", None),
                "fake_score": None,  # Placeholder
            }
        )
        
        logger.debug(f"Article {'created' if created else 'updated'} with ID: {article_obj.id}")

        # Only compute embeddings if it's a new article or there's no existing embedding
        if created or article_obj.embedding is None:
            if embedding_model is not None:
                # Combine title and content for better semantic representation
                text_for_embedding = f"{article_obj.title} {article_obj.content}"
                if not text_for_embedding.strip():
                    logger.warning(f"Empty text for embedding for article {article_obj.id}")
                    return None
                    
                try:
                    logger.debug(f"Computing embedding for article {article_obj.id}")
                    text_embedding = embedding_model.encode(text_for_embedding).tolist()
                    logger.debug(f"Embedding computed, length: {len(text_embedding)}")
                    article_obj.embedding = text_embedding
                    article_obj.save(update_fields=['embedding'])
                    logger.debug(f"Embedding saved for article {article_obj.id}")
                except Exception as e:
                    logger.error(f"Embedding error for article {article_obj.id}: {e}")
                    logger.error(traceback.format_exc())
            else:
                logger.warning("Embedding model not available, skipping embedding generation")

        # Store keywords from query and title - only if it's a new article
        if created:
            # Extract keywords from query
            query_keywords = []
            if query:
                query_keywords = [word.lower() for word in query.split() if len(word) > 5]
            
            # Extract keywords from title
            title_keywords = []
            if title:
                # Remove special characters and split
                cleaned_title = re.sub(r'[^\w\s]', ' ', title)
                title_keywords = [word.lower() for word in cleaned_title.split() if len(word) > 5]
            
            # Combine unique keywords
            all_keywords = set(query_keywords + title_keywords)
            
            # Store in database
            for keyword in all_keywords:
                if keyword:
                    keyword_obj, _ = Keyword.objects.get_or_create(keyword=keyword)
                    article_obj.keywords.add(keyword_obj)
                    
            logger.debug(f"Added {len(all_keywords)} keywords to article {article_obj.id}")

        article_data = {
            "id": article_obj.id,
            "title": article_obj.title,
            "url": article_obj.url,
            "content": article_obj.content[:200] + "..." if len(article_obj.content) > 200 else article_obj.content,
            "image_url": article_obj.image_url,
            "author": article_obj.author,
            "published_date": article_obj.published_date,
            "source": article_obj.source.name if article_obj.source else "Unknown",
            "created": created,
            "has_embedding": article_obj.embedding is not None
        }
        
        logger.debug(f"Article processing completed: {article_obj.id}")
        return article_data

    except Exception as e:
        logger.error(f"Error storing article: {str(e)}")
        logger.error(traceback.format_exc())
        # Retry with exponential backoff
        raise self.retry(exc=e, countdown=2 ** self.request.retries)

@shared_task
def store_articles_batch(articles, query=None):
    """Process a batch of articles, queueing each for individual processing"""
    logger.info(f"Processing batch of {len(articles)} articles for query: {query}")
    for article in articles:
        # If the article doesn't already have query info, add it
        if query and 'query' not in article:
            article['query'] = query
            
        # Process each article in its own task
        store_article_async.delay(article, query)
    return {"queued_articles": len(articles)}

User = get_user_model()

@shared_task
def generate_recommendations(user_id):
    try:
        logger.info(f"Generating recommendations for user {user_id}")
        user = User.objects.get(id=user_id)

        interactions = UserInteraction.objects.filter(user=user)
        interacted_articles = Articles.objects.filter(id__in=interactions.values_list('article_id', flat=True))

        if not interacted_articles.exists():
            logger.info(f"No interacted articles found for user {user_id}")
            return {"status": "No interacted articles found"}

        # Mean embedding of interacted articles
        embeddings = [a.embedding for a in interacted_articles if a.embedding is not None]
        if not embeddings:
            logger.info(f"No embeddings found for articles interacted by user {user_id}")
            return {"status": "No embeddings found for interacted articles"}
            
        embeddings_array = np.array(embeddings)
        mean_embedding = np.mean(embeddings_array, axis=0).tolist()

        # Query
        similar_articles = Articles.objects \
            .exclude(id__in=interacted_articles.values_list('id', flat=True)) \
            .exclude(embedding=None) \
            .annotate(similarity=CosineDistance('embedding', mean_embedding)) \
            .order_by('similarity')[:10]

        logger.info(f"Found {len(similar_articles)} recommendations for user {user_id}")
        
        # Top recommendations
        Recommendation.objects.filter(user=user).delete()
        for article in similar_articles:
            Recommendation.objects.create(user=user, article=article)
            
        return {"status": "success", "recommendations_count": len(similar_articles)}
    
    except Exception as e:
        logger.error(f"Error generating recommendations: {str(e)}")
        logger.error(traceback.format_exc())
        return {"status": "error", "message": str(e)}