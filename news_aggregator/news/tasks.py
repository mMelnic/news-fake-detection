from celery import shared_task
from pgvector.django import CosineDistance
from .models import Articles, UserInteraction, Recommendation, Sources, Keyword
from django.contrib.auth import get_user_model
import numpy as np
from sentence_transformers import SentenceTransformer
from news.services.nlp_service import NLPPredictionService
import logging
import traceback
from django.db import transaction
from datetime import datetime
import uuid

logger = logging.getLogger(__name__)

try:
    logger.info("Initializing SentenceTransformer model...")
    embedding_model = SentenceTransformer("all-MiniLM-L6-v2")
    logger.info("SentenceTransformer model initialized successfully")
except Exception as e:
    logger.error(f"Error initializing SentenceTransformer: {str(e)}")
    embedding_model = None


DEFAULT_IMAGE_URL = 'https://raw.githubusercontent.com/mMelnic/news-fake-detection/refs/heads/users/news_aggregator/newspaper_beige.jpg'
nlp_service = NLPPredictionService()

def normalize_article(article, source_name=None, source_url=None, default_language=None, default_country=None):
    """Normalize article fields across different sources."""
    title = article.get("title", "") or ""
    url = article.get("url") or article.get("link") or ""
    content = article.get("content") or article.get("description") or ""
    published_at = article.get("publishedAt") or article.get("pub_date") or article.get("published") or ""
    author = article.get("author") or ""
    image_url = article.get("urlToImage") or article.get("image") or DEFAULT_IMAGE_URL
    language = article.get("language") or default_language or "en"
    country = article.get("country") or default_country or ""
    categories = article.get("categories") or ""
    is_fake = article.get("is_fake")
    sentiment = article.get("sentiment")
    fake_score = article.get("fake_score")

    # Source info normalization
    if "source" in article:
        if isinstance(article["source"], dict):
            source_name = article["source"].get("name") or source_name
            source_url = article["source"].get("url") or source_url
        elif isinstance(article["source"], str):
            source_name = article["source"]

    if not source_url and source_name:
        domain = source_name.lower().replace(" ", "").replace(".", "")
        source_url = f"https://www.{domain}.com"

    # Parse published date if string
    from dateutil import parser
    try:
        if published_at:
            published_at = parser.parse(published_at)
    except Exception:
        published_at = None

    # Cast is_fake to boolean or None
    if is_fake is not None:
        if isinstance(is_fake, str):
            is_fake = is_fake.lower() in ("true", "1", "yes")
        else:
            is_fake = bool(is_fake)
    else:
        is_fake = None

    return {
        "title": title,
        "url": url,
        "content": content,
        "published_date": published_at,
        "author": author,
        "image_url": image_url,
        "source_name": source_name,
        "source_url": source_url,
        "language": language,
        "country": country,
        "categories": categories,
        "is_fake": is_fake,
        "sentiment": sentiment,
        "fake_score": fake_score,
    }


from django.core.cache import cache

@shared_task(bind=True)
def process_and_store_articles(self, raw_articles, language=None, country=None, extracted_terms=None, extracted_phrases=None):
    extracted_terms = extracted_terms or []
    extracted_phrases = extracted_phrases or []
    task_id = self.request.id
    redis_key = f"articles_task:{task_id}"

    normalized = []
    for article in raw_articles:
        norm = normalize_article(article, default_language=language, default_country=country)
        norm['keywords'] = extracted_terms + extracted_phrases
        normalized.append(norm)

    stored_ids = []

    batch_size = 20
    for i in range(0, len(normalized), batch_size):
        batch = normalized[i:i + batch_size]

        with transaction.atomic():
            for art in batch:
                if not art["url"] or Articles.objects.filter(url=art["url"]).exists():
                    continue

                source_obj, _ = Sources.objects.get_or_create(
                    url=art["source_url"],
                    defaults={"name": art["source_name"] or ""}
                )

                article_obj = Articles.objects.create(
                    title=art["title"],
                    url=art["url"],
                    content=art["content"],
                    author=art["author"],
                    image_url=art["image_url"] or DEFAULT_IMAGE_URL,
                    source=source_obj,
                    published_date=art["published_date"],
                    language=art["language"],
                    country=art["country"],
                    categories=art["categories"],
                    is_fake=art["is_fake"],
                    sentiment=art["sentiment"],
                    fake_score=art["fake_score"],
                )

                text = f"{article_obj.title} {article_obj.content}"
                if embedding_model and text.strip():
                    try:
                        article_obj.embedding = embedding_model.encode(text).tolist()
                    except Exception as e:
                        logger.error(f"Embedding error for article {article_obj.id}: {e}")

                try:
                    nlp_preds = nlp_service.predict_batch([text])
                    if nlp_preds and isinstance(nlp_preds[0], dict):
                        article_obj.is_fake = nlp_preds[0].get("is_fake")
                        article_obj.sentiment = nlp_preds[0].get("sentiment")
                        article_obj.fake_score = 1.0 if article_obj.is_fake else 0.0
                except Exception as e:
                    logger.error(f"NLP error for article {article_obj.id}: {e}")

                article_obj.save()
                stored_ids.append(article_obj.id)

        # Update Redis after each batch
        cache.set(redis_key, {
            "article_ids": stored_ids,
            "status": "processing"
        }, timeout=3600)

    # Mark task as completed
    cache.set(redis_key, {
        "article_ids": stored_ids,
        "status": "completed"
    }, timeout=3600)

    logger.info(f"Processed and stored {len(stored_ids)} articles.")
    return {"stored": len(stored_ids)}

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

@shared_task
def process_articles_nlp(article_ids):
    """
    Process a batch of articles with NLP model to get fake news and sentiment predictions
    """
    try:
        if not article_ids:
            return {"status": "No articles to process"}
            
        logger.info(f"Processing {len(article_ids)} articles for NLP predictions")
        
        # Get articles from database
        articles = Articles.objects.filter(id__in=article_ids)
        if not articles.exists():
            logger.warning(f"No articles found with provided IDs")
            return {"status": "No articles found"}
            
        # Prepare article texts (combine title and content for better prediction)
        article_dict = {}  # Map ID to article object for updating later
        texts = []
        
        for article in articles:
            # Check if we already have predictions
            if article.is_fake is not None and article.sentiment is not None:
                logger.debug(f"Article {article.id} already has predictions - skipping")
                continue
                
            # Prepare text for prediction
            text = f"{article.title} {article.content}"
            texts.append(text)
            article_dict[len(texts) - 1] = article  # Map index to article
            
        if not texts:
            logger.info("No new articles need NLP processing")
            return {"status": "No new articles to process"}
            
        # Get predictions
        from news.services.nlp_service import NLPPredictionService
        nlp_service = NLPPredictionService()
        predictions = nlp_service.predict_batch(texts)
        
        # Update articles with predictions
        updated_count = 0
        for idx, prediction in enumerate(predictions):
            if idx in article_dict:
                article = article_dict[idx]
                updates = {}
                
                if prediction["is_fake"] is not None:
                    updates["is_fake"] = prediction["is_fake"]
                    updates["fake_score"] = 1.0 if prediction["is_fake"] else 0.0
                    
                if prediction["sentiment"] is not None:
                    updates["sentiment"] = prediction["sentiment"]
                    
                if updates:
                    Articles.objects.filter(id=article.id).update(**updates)
                    updated_count += 1
        
        logger.info(f"Updated {updated_count} articles with NLP predictions")
        return {"status": "success", "updated_count": updated_count}
        
    except Exception as e:
        logger.error(f"Error processing articles with NLP: {str(e)}")
        logger.error(traceback.format_exc())
        return {"status": "error", "error": str(e)}

import uuid
from celery import shared_task
from datetime import datetime

@shared_task
def process_search_results(articles):
    """Process and format search results from external APIs"""
    DEFAULT_IMAGE_URL = 'https://raw.githubusercontent.com/mMelnic/news-fake-detection/refs/heads/users/news_aggregator/newspaper_beige.jpg'
    
    processed_articles = []
    for article in articles:
        # Extract data from the article
        title = article.get('title', '')
        url = article.get('url', '')
        content = article.get('content', '') or article.get('description', '')
        image_url = article.get('urlToImage') or article.get('image') or DEFAULT_IMAGE_URL
        author = article.get('author', 'Unknown')
        published_at = article.get('publishedAt', '') or article.get('published_date', '')
        
        # Source might be a string or a dict
        if isinstance(article.get('source'), dict):
            source_name = article.get('source', {}).get('name', 'Unknown')
        else:
            source_name = article.get('source', 'Unknown')
        
        if published_at:
            try:
                # Try to parse ISO format
                if isinstance(published_at, str):
                    # Remove the Z and replace with timezone offset
                    published_at = published_at.replace('Z', '+00:00')
                    published_date = published_at
                else:
                    published_date = published_at.isoformat()
            except (ValueError, TypeError, AttributeError):
                # Fallback to current date
                published_date = datetime.now().isoformat()
        else:
            published_date = datetime.now().isoformat()
        
        processed_article = {
            'id': str(uuid.uuid4()),  # Generate a temporary ID as string
            'title': title,
            'content': content,
            'url': url,
            'image_url': image_url,
            'author': author,
            'published_date': published_date,
            'source': source_name,
            'categories': '',
            'is_fake': False,  # Default, would need actual classification
            'sentiment': 'neutral'
        }
        
        processed_articles.append(processed_article)
    
    return processed_articles