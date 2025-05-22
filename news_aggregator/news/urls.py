from django.urls import path
from .views import RecommendationView, NewsAggregatorView
from . import views

urlpatterns = [
    path('api/recommendations/', RecommendationView.as_view()),
    path('api/news/', NewsAggregatorView.as_view(), name='news-aggregator'),
    path('social/likes/', views.toggle_like, name='toggle_like'),
    path('social/likes/<int:article_id>/', views.is_article_liked, name='is_article_liked'),
    path('social/likes/<int:article_id>/count/', views.get_article_like_count, name='get_article_like_count'),
    path('social/comments/', views.add_comment, name='add_comment'),
    path('social/comments/<int:article_id>/', views.get_article_comments, name='get_article_comments'),
]