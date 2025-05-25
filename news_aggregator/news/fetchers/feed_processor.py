import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'news_aggregator.settings')

import django
django.setup()

import feedparser
from datetime import datetime
from django.db import transaction
from news.models import Feed, Articles
from news.utils.content_extractor import ContentExtractor
from sentence_transformers import SentenceTransformer
from news.services.nlp_service import NLPPredictionService
from django.utils.timezone import make_aware, is_naive, get_default_timezone
import logging

logger = logging.getLogger(__name__)
DEFAULT_IMAGE_URL = 'https://raw.githubusercontent.com/mMelnic/news-fake-detection/refs/heads/users/news_aggregator/newspaper_beige.jpg'
embedding_model = SentenceTransformer("all-MiniLM-L6-v2")

class FeedParser:
    def __init__(self):
        self.extractor = ContentExtractor()
        self.nlp_service = NLPPredictionService()

    def fetch_new_articles(self):
        """Main method to fetch new articles from all active feeds"""
        active_feeds = Feed.objects.filter(is_active=True)

        for feed in active_feeds:
            try:
                self.process_feed(feed)
            except Exception as e:
                logger.error(f"Failed to process feed {feed.url}: {e}")

    def process_feed(self, feed):
        """Process a single RSS feed"""
        parsed_feed = feedparser.parse(feed.url)

        if not self.has_feed_updated(feed, parsed_feed):
            logger.info(f"Skipping {feed.url} - no updates since last fetch")
            return

        for entry in parsed_feed.entries:
            self.process_article_entry(entry, feed)

        # Update feed metadata
        feed.last_fetched = datetime.now()
        if hasattr(parsed_feed.feed, 'updated_parsed'):
            feed.last_built = datetime(*parsed_feed.feed.updated_parsed[:6])
        if is_naive(feed.last_built):
            feed.last_built = make_aware(feed.last_built, get_default_timezone())
        feed.save()

    def has_feed_updated(self, feed, parsed_feed):
        """Check if feed has been updated since last fetch"""
        if not feed.last_built:
            return True

        # if hasattr(parsed_feed.feed, 'updated_parsed'):
        #     feed_updated = datetime(*parsed_feed.feed.updated_parsed[:6])

        #     if is_naive(feed_updated):
        #         feed_updated = make_aware(feed_updated)

        #     return feed_updated > feed.last_built

        return True

    def process_article_entry(self, entry, feed):
        """Process and store a new article with NLP features"""
        if Articles.objects.filter(url=entry.link).exists():
            return

        result = self.extractor.get_article_content(entry.link, entry.title)
        if not result or result["word_count"] < 100:
            return

        try:
            with transaction.atomic():
                # Create basic article
                article = self.create_base_article(entry, feed, result)
                
                # Process NLP features in same transaction
                self.process_article_nlp(article)
        except Exception as e:
            logger.error(f"Error processing article '{entry.title}' from {feed.url}: {e}")

    def create_base_article(self, entry, feed, content_result):
        """Create the article with basic fields"""
        image_url = self.extractor.get_article_image(entry) or DEFAULT_IMAGE_URL

        pub_date = datetime.now()
        if hasattr(entry, 'published_parsed'):
            pub_date = datetime(*entry.published_parsed[:6])

        if is_naive(pub_date):
            pub_date = make_aware(pub_date, get_default_timezone())

        categories = []
        if feed.category:
            categories.append(feed.category)
        if hasattr(entry, 'tags'):
            categories.extend(tag.term.lower() for tag in entry.tags)
        if hasattr(entry, 'category') and entry.category:
            categories.append(entry.category.lower())

        language = None
        if hasattr(entry, 'language'):
            language = entry.language.split('-')[0].lower()
        elif feed.language:
            language = feed.language

        return Articles.objects.create(
            title=entry.title,
            author=entry.get('author', ''),
            content=content_result["truncated_content"],
            url=entry.link,
            image_url=image_url,
            source=feed.source,
            published_date=pub_date,
            country=feed.country,
            language=language,
            categories=', '.join(set(categories)) if categories else None,
            feed=feed,
        )

    def process_article_nlp(self, article):
        """Compute and store NLP features for an article"""
        try:
            text = f"{article.title} {article.content}"
            
            # Generate embedding
            if text.strip():
                article.embedding = embedding_model.encode(text).tolist()
            
            # Get NLP predictions
            predictions = self.nlp_service.predict_batch([text])
            if predictions and isinstance(predictions[0], dict):
                pred = predictions[0]
                article.is_fake = pred.get("is_fake")
                article.fake_score = 1.0 if pred.get("is_fake") else 0.0
                article.sentiment = pred.get("sentiment")
            
            # Save all updates at once
            article.save(update_fields=[
                "embedding", 
                "is_fake", 
                "fake_score", 
                "sentiment"
            ])
            
            logger.info(f"Processed NLP for article {article.id}")
            
        except Exception as e:
            logger.error(f"Error processing NLP for article {article.id}: {e}")
            raise

if __name__ == "__main__":
    parser = FeedParser()
    parser.fetch_new_articles()