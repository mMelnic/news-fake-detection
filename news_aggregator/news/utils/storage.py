import redis
import os
import json

redis_client = redis.Redis(host=os.getenv('REDIS_HOST', 'localhost'), port=os.getenv('REDIS_PORT', 6379), db=0)
CACHE_DURATION = 36000

def get_cached_result(query, language):
    cache_key = generate_cache_key(query, language)
    cached_data = redis_client.get(cache_key)
    if cached_data:
        return json.loads(cached_data)
    return None

def cache_result(query, language, articles):
    cache_key = generate_cache_key(query, language)
    redis_client.setex(cache_key, CACHE_DURATION, json.dumps(articles))

def generate_cache_key(query, language):
    return f"news:{query}:{language if language else 'all'}"
