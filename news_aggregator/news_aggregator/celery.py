import os
from celery import Celery
from dotenv import load_dotenv
load_dotenv()

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'news_aggregator.settings')
app = Celery('news_app')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()

# Use solo pool for Windows to prevent worker crashes
app.conf.worker_pool = 'solo'
# Set concurrency to avoid memory issues with SentenceTransformer
app.conf.worker_concurrency = 1