import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from .models import Articles
import logging

logger = logging.getLogger(__name__)

class NewsConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        # Extract query parameters from the scope
        query_string = self.scope.get('query_string', b'').decode()
        query_params = {
            param.split('=')[0]: param.split('=')[1] 
            for param in query_string.split('&') 
            if '=' in param
        }

        self.query = query_params.get('query', 'default_query')
        self.language = query_params.get('language', 'en')
        self.country = query_params.get('country', None)
        
        # Create a unique group name for this search query
        self.room_group_name = f"news_{self.query}_{self.language}_{self.country or 'all'}"
        
        logger.info(f"WebSocket connection: {self.channel_name} joining {self.room_group_name}")
        
        # Join room group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )

        await self.accept()

    async def disconnect(self, close_code):
        # Leave room group
        logger.info(f"WebSocket disconnection: {self.channel_name} leaving {self.room_group_name}")
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )

    # Receive message from WebSocket
    async def receive(self, text_data):
        text_data_json = json.loads(text_data)
        message_type = text_data_json.get('type')
        
        if message_type == 'get_updates':
            # Client is requesting updates - send them any new articles
            articles = await self.get_recent_articles(self.query, self.language, self.country)
            await self.send(text_data=json.dumps({
                'type': 'article_updates',
                'articles': articles,
                'count': len(articles)
            }))

    # Receive message from room group
    async def article_update(self, event):
        # Send article update to WebSocket
        await self.send(text_data=json.dumps({
            'type': 'article_update',
            'article': event['article']
        }))
        
    async def batch_update(self, event):
        # Send multiple articles at once
        await self.send(text_data=json.dumps({
            'type': 'batch_update',
            'articles': event['articles'],
            'count': event['count']
        }))

    @database_sync_to_async
    def get_recent_articles(self, query, language, country):
        # Import here to avoid circular imports
        from django.db.models import Q
        import re
        
        # Helper function to build query filter similar to the one in views.py
        def build_keyword_filter(query):
            # Extract phrases
            phrases = re.findall(r'"(.*?)"', query)
            remaining_query = re.sub(r'"(.*?)"', '', query)
            keywords = re.findall(r'([+-]?\b(?!AND\b|OR\b|NOT\b)\w+\b)', remaining_query)
            keywords = [k.lower() for k in keywords if k.strip() and len(k.strip()) > 2]
            
            if not phrases and not keywords:
                return None
                
            keyword_filter = Q()
            for phrase in phrases:
                keyword_filter |= Q(title__icontains=phrase)
            
            for keyword in keywords:
                keyword_filter |= Q(keywords__keyword=keyword) | Q(title__icontains=keyword)
                
            return keyword_filter
            
        # Query for recent articles (last 10 minutes)
        from django.utils import timezone
        from datetime import timedelta
        
        queryset = Articles.objects.all()
        
        # Apply keyword filtering
        if query:
            keyword_filter = build_keyword_filter(query)
            if keyword_filter:
                queryset = queryset.filter(keyword_filter)
        
        # Apply language filter
        if language:
            queryset = queryset.filter(Q(source__language=language) | Q(source__language__isnull=True))
            
        # Apply country filter
        if country:
            queryset = queryset.filter(Q(country=country) | Q(country__isnull=True))
            
        # Get recently added/updated articles
        ten_minutes_ago = timezone.now() - timedelta(minutes=10)
        queryset = queryset.filter(created_at__gte=ten_minutes_ago)
        
        queryset = queryset.order_by('-created_at').distinct()[:20]
        
        # Convert to list of dictionaries
        return [
            {
                "id": article.id,
                "title": article.title,
                "content": article.content[:200] + "..." if len(article.content) > 200 else article.content,
                "url": article.url,
                "image_url": article.image_url,
                "author": article.author,
                "published_date": article.published_date.isoformat() if article.published_date else None,
                "source": article.source.name if article.source else "Unknown",
                "has_embedding": article.embedding is not None,
                "is_fake": article.is_fake,
                "fake_score": article.fake_score,
                "sentiment": article.sentiment
            }
            for article in queryset
        ]