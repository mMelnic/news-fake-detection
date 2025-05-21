from django.urls import path
from .views import RecommendationView, NewsAggregatorView

urlpatterns = [
    path('api/recommendations/', RecommendationView.as_view()),
    path('api/news/', NewsAggregatorView.as_view(), name='news-aggregator'),
]