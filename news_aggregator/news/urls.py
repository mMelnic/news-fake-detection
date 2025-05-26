from django.urls import path
from .views import  (
    ArticleListView, ArticleOrSearchView, search_and, search_or, poll_task_articles,
    FeedCategoryListView, FeedCategoryArticlesView,
    SourceListView, SourceArticlesView, RecommendationView, ArticleTopicClassificationAPIView,
    ArticleCategoryView,
)
from . import views

urlpatterns = [
    path('api/recommendations/', RecommendationView.as_view()),
    path('social/likes/', views.toggle_like, name='toggle_like'),
    path('social/likes/<int:article_id>/', views.is_article_liked, name='is_article_liked'),
    path('social/likes/<int:article_id>/count/', views.get_article_like_count, name='get_article_like_count'),
    path('social/comments/', views.add_comment, name='add_comment'),
    path('social/comments/<int:article_id>/', views.get_article_comments, name='get_article_comments'),
    path('articles/', ArticleListView.as_view(), name='article-list'),
    path('articles/or/', ArticleOrSearchView.as_view(), name='article-or-search'),
    path('articles/category/<str:category>/', ArticleCategoryView.as_view(), name='article-category'),
    path('search/and/', search_and, name='search-and'),
    path('search/or/', search_or, name='search-or'),
    path('poll-task-articles/<str:task_id>/', poll_task_articles, name='poll-task-articles'),
    path('feed/categories/', FeedCategoryListView.as_view(), name='feed-category-list'),
    path('feed/categories/<str:category>/', FeedCategoryArticlesView.as_view(), name='feed-category-articles'),
    path('sources/', SourceListView.as_view(), name='source-list'),
    path('sources/<int:source_id>/articles/', SourceArticlesView.as_view(), name='source-articles'),
    path('api/classify-topic/<int:article_id>/', ArticleTopicClassificationAPIView.as_view(), name='classify-topic'),
    path('social/saved/', views.toggle_saved, name='toggle_saved'),
    path('social/saved/<int:article_id>/', views.is_article_saved, name='is_article_saved'),
    path('collections/', views.collection_list, name='collection_list'),
    path('collections/<int:collection_id>/', views.collection_detail, name='collection_detail'),
    path('collections/<int:collection_id>/articles/', views.collection_articles, name='collection_articles'),
    path('user/stats/', views.user_interaction_stats, name='user_interaction_stats'),
    path('articles/null-category/', views.articles_null_category, name='articles-null-category'),
    path('direct-search/', views.direct_search, name='direct-search'),
]