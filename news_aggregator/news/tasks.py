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
    try:
        logger.debug(f"Processing article: {article.get('title', 'Unknown')[:50]}...")
        
        # Extract normalized source information based on different API formats
        source_name = "Unknown"
        source_url = ""
        
        if "source" in article:
            # Handle different source formats
            if isinstance(article["source"], dict):
                # NewsAPI and GNews format
                source_name = article["source"].get("name", "Unknown")
                
                # Handle case when URL might be null
                source_url = article["source"].get("url", "")
                if not source_url and "id" in article["source"]:
                    # Try to use ID to generate a URL if explicit URL is missing
                    source_id = article["source"].get("id", "")
                    if source_id:
                        source_url = f"https://www.{source_id.lower()}.com"
                    else:
                        # Generate URL from name as fallback
                        name_slug = source_name.lower().replace(' ', '').replace('.', '')
                        source_url = f"https://www.{name_slug}.com"
                        
            elif isinstance(article["source"], str):
                # RSS feed format in some cases
                source_name = article["source"]
                source_url = article.get("source_url", "")
                
        # If we still don't have a URL, generate one from the name
        if not source_url and source_name:
            # Create a slug from the source name
            name_slug = source_name.lower().replace(' ', '').replace('.', '')
            source_url = f"https://www.{name_slug}.com"
        
        # If we still have no URL (very unlikely at this point), use a placeholder
        if not source_url:
            source_url = "https://unknown-source.com"
            
        logger.debug(f"Source data normalized: name={source_name}, url={source_url}")
        
        # Create source object
        try:
            source_obj, _ = Sources.objects.get_or_create(
                url=source_url,
                defaults={
                    "name": source_name,
                    "country": article.get("country", None),
                    "language": article.get("language", None)
                }
            )
        except Exception as source_error:
            logger.error(f"Error creating source: {str(source_error)}")
            # Create a fallback source if needed
            source_obj, _ = Sources.objects.get_or_create(
                url="https://unknown-source.com",
                defaults={"name": "Unknown Source"}
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
                logger.warning(f"Could not parse publishedAt '{published_at_raw}' for article '{title[:100]}': {e}")
                    
        logger.debug(f"Creating/updating article with URL: {url}")
                    
        # Create or update article - note we're removing the category field
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
                # No longer storing category
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

        # Store keywords - either from article['keywords'] or parse from query
        if created:
            parsed_keywords = []
            
            # First priority: use keywords already parsed and included in the article object
            if 'keywords' in article and article['keywords']:
                parsed_keywords = article['keywords']
                logger.debug(f"Using pre-parsed keywords: {parsed_keywords}")
            # Second priority: parse from query
            elif query:
                parsed_keywords = _parse_query(query)
                logger.debug(f"Using keywords parsed from query: {parsed_keywords}")
            
            # Get existing keywords if article is being updated
            existing_keywords = set(article_obj.keywords.values_list('keyword', flat=True)) if not created else set()
            
            # Add new keywords
            added_keywords = 0
            for keyword in parsed_keywords:
                if keyword.lower() not in existing_keywords:
                    keyword_obj, _ = Keyword.objects.get_or_create(keyword=keyword.lower())
                    article_obj.keywords.add(keyword_obj)
                    added_keywords += 1
                    
            logger.debug(f"Added {added_keywords} keywords to article {article_obj.id}")

        # After storing the article, send a notification via WebSocket
        if created:
            try:
                # Import here to avoid circular imports
                from channels.layers import get_channel_layer
                from asgiref.sync import async_to_sync
                
                channel_layer = get_channel_layer()
                
                # Format the article for sending
                article_data = {
                    "id": article_obj.id,
                    "title": article_obj.title,
                    "url": article_obj.url,
                    "content": article_obj.content[:200] + "..." if len(article_obj.content) > 200 else article_obj.content,
                    "image_url": article_obj.image_url,
                    "author": article_obj.author,
                    "published_date": article_obj.published_date.isoformat() if article_obj.published_date else None,
                    "source": article_obj.source.name if article_obj.source else "Unknown",
                    "has_embedding": article_obj.embedding is not None,
                    "is_fake": article_obj.is_fake,
                    "fake_score": article_obj.fake_score,
                    "sentiment": article_obj.sentiment
                }
                
                # Create a group name that matches the one in the consumer
                if query:
                    # Extract language and country from article
                    language = article.get('language', 'en')
                    country = article.get('country', 'all')
                    room_group_name = f"news_{query}_{language}_{country}"
                    
                    # Send the update to the group
                    async_to_sync(channel_layer.group_send)(
                        room_group_name,
                        {
                            'type': 'article_update',
                            'article': article_data
                        }
                    )
                    logger.debug(f"WebSocket notification sent for article {article_obj.id} to group {room_group_name}")
            except Exception as ws_error:
                logger.error(f"WebSocket notification error: {str(ws_error)}")
                # Don't raise here, just log the error and continue
                
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

# Helper function for parsing queries into keywords
def _parse_query(query):
    """Parse a query string into a list of keywords and phrases."""
    import re
    # Extract quoted phrases
    phrases = re.findall(r'"(.*?)"', query)
    # Remove quoted phrases from query
    remaining_query = re.sub(r'"(.*?)"', '', query)
    # Extract individual keywords, ignoring logical operators
    keywords = re.findall(r'([+-]?\b(?!AND\b|OR\b|NOT\b)\w+\b)', remaining_query)
    keywords = [k for k in keywords if k.strip() and len(k.strip()) > 2]  # Skip very short words
    return phrases + keywords

@shared_task
def store_articles_batch(articles, query=None):
    """Process a batch of articles, queueing each for individual processing"""
    logger.info(f"Processing batch of {len(articles)} articles for query: {query}")
    
    # Parse query once for all articles if not already done
    if query and not any('keywords' in article for article in articles):
        parsed_keywords = _parse_query(query)
        logger.info(f"Parsed query '{query}' into keywords: {parsed_keywords}")
    else:
        parsed_keywords = None
        
    # Keep track of stored article IDs for NLP processing
    stored_article_ids = []
    
    # Store all successfully processed articles for batch notification
    processed_articles = []
    
    for article in articles:
        # If the article doesn't already have query info, add it
        if query and 'query' not in article:
            article['query'] = query
            
        # If parsed keywords available but article doesn't have keywords, add them
        if parsed_keywords and 'keywords' not in article:
            article['keywords'] = parsed_keywords
            
        # Process each article in its own task
        result = store_article_async(article, query)
        
        # If article was stored successfully, add its ID to the list for NLP processing
        if result and isinstance(result, dict) and 'id' in result:
            stored_article_ids.append(result['id'])
            processed_articles.append(result)
    
    # Process stored articles with NLP in a separate task
    if stored_article_ids:
        logger.info(f"Queueing {len(stored_article_ids)} articles for NLP processing")
        process_articles_nlp.delay(stored_article_ids)
    
    # Send batch notification via WebSocket
    if processed_articles and query:
        try:
            # Import here to avoid circular imports
            from channels.layers import get_channel_layer
            from asgiref.sync import async_to_sync
            
            # Get the first article to extract language and country
            first_article = articles[0]
            language = first_article.get('language', 'en')
            country = first_article.get('country', 'all')
            
            channel_layer = get_channel_layer()
            room_group_name = f"news_{query}_{language}_{country}"
            
            # Send the batch update to the group
            async_to_sync(channel_layer.group_send)(
                room_group_name,
                {
                    'type': 'batch_update',
                    'articles': processed_articles,
                    'count': len(processed_articles)
                }
            )
            logger.debug(f"WebSocket batch notification sent for {len(processed_articles)} articles to group {room_group_name}")
        except Exception as ws_error:
            logger.error(f"WebSocket batch notification error: {str(ws_error)}")
            # Don't raise here, just log the error and continue
    
    return {"queued_articles": len(articles), "stored_articles": len(stored_article_ids)}

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
                    # For compatibility with existing code, also set fake_score
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