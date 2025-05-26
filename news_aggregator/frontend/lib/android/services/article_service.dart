import 'package:dio/dio.dart';
import '../model/news.dart';
import '../../services/dio_client.dart';

class ArticleService {
  // Use DioClient for all requests instead of direct URL
  static final Dio _dio = DioClient.dio;
  
  // Fetch articles by category with pagination
  static Future<Map<String, dynamic>> fetchArticlesByCategory({
    required String category,
    required int page,
    required int pageSize,
    String sort = 'newest',
  }) async {
    try {
      final response = await _dio.get(
        '/articles/category/$category/',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          'sort': sort,
        },
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final List<News> articles = [];
        
        for (var article in data['articles']) {
          articles.add(News.fromMap(article));
        }
        
        return {
          'articles': articles,
          'hasMore': data['has_more'],
          'page': data['page'],
        };
      } else {
        throw Exception('Failed to load articles: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // Let DioClient handle the error and auth failures
      rethrow;
    } catch (e) {
      throw Exception('Failed to load articles: $e');
    }
  }
  
  // Fetch all categories
  static Future<List<String>> fetchCategories() async {
    try {
      final response = await _dio.get('/feed/categories/');
      
      if (response.statusCode == 200) {
        final data = response.data;
        return List<String>.from(data['categories']);
      } else {
        throw Exception('Failed to load categories');
      }
    } on DioException catch (e) {
      // Let DioClient handle the error and auth failures
      rethrow;
    } catch (e) {
      throw Exception('Failed to load categories: $e');
    }
  }
  
  // Get like count for an article
  static Future<int> getLikeCount(String articleId) async {
    try {
      final response = await _dio.get('/social/likes/$articleId/count/');
      
      if (response.statusCode == 200) {
        return response.data['count'];
      } else {
        return 0;
      }
    } catch (e) {
      // Return 0 as default if there's an error
      return 0;
    }
  }
  
  // Check if current user has liked an article
  static Future<bool> isArticleLiked(String articleId) async {
    try {
      final response = await _dio.get('/social/likes/$articleId/');
      
      if (response.statusCode == 200) {
        return response.data['liked'];
      } else {
        return false;
      }
    } catch (e) {
      // Return false as default if there's an error
      return false;
    }
  }
  
  // Toggle like for an article
  static Future<bool> toggleLike(String articleId) async {
    try {
      final response = await _dio.post(
        '/social/likes/',
        data: {'article_id': articleId},
      );
      
      if (response.statusCode == 200) {
        return response.data['liked'];
      } else {
        return false;
      }
    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }
  
  // Get comments for an article
  static Future<List<Map<String, dynamic>>> getArticleComments(String articleId) async {
    try {
      final response = await _dio.get('/social/comments/$articleId/');
      
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['comments']);
      } else {
        return [];
      }
    } catch (e) {
      // Return empty list as default if there's an error
      return [];
    }
  }
  
  // Add a comment to an article
  static Future<bool> addComment(String articleId, String content) async {
    try {
      final response = await _dio.post(
        '/social/comments/',
        data: {
          'article_id': articleId,
          'content': content,
        },
      );
      
      return response.statusCode == 201;
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }
  
  // Check if article is saved
  static Future<Map<String, dynamic>> isArticleSaved(String articleId) async {
    try {
      final response = await _dio.get('/social/saved/$articleId/');
      
      if (response.statusCode == 200) {
        return response.data;
      } else {
        return {'saved': false};
      }
    } catch (e) {
      // Return default if there's an error
      return {'saved': false};
    }
  }
  
  // Save/unsave an article to a collection
  static Future<Map<String, dynamic>> toggleSaved(String articleId, String collectionName) async {
    try {
      final response = await _dio.post(
        '/social/saved/',
        data: {
          'article_id': articleId,
          'collection_name': collectionName,
        },
      );
      
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to toggle saved status');
      }
    } catch (e) {
      throw Exception('Failed to toggle saved status: $e');
    }
  }
  
  // Get article topic classification
  static Future<String> classifyArticleTopic(String articleId) async {
    try {
      final response = await _dio.get('/api/classify-topic/$articleId/');
      
      if (response.statusCode == 200) {
        return response.data['topic'];
      } else {
        throw Exception('Failed to classify article topic');
      }
    } catch (e) {
      throw Exception('Failed to classify article topic: $e');
    }
  }
  
  // Get articles with optional category filter
  static Future<ArticleResponse> getArticles({
    int page = 1, 
    int pageSize = 10,
    String sort = 'newest',
    String? category,
  }) async {
    try {
      Map<String, dynamic> params = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'sort': sort,
      };
      
      final String endpoint = category != null && category.toLowerCase() != 'all categories'
          ? '/category/${Uri.encodeComponent(category)}/'
          : '/category/all%20categories/';
      
      final response = await _dio.get(endpoint, queryParameters: params);
      
      if (response.statusCode == 200) {
        List<News> articles = [];
        for (var articleData in response.data['articles']) {
          articles.add(News(
            id: articleData['id'].toString(),
            title: articleData['title'] ?? '',
            content: articleData['content'] ?? '',
            image: articleData['image_url'] ?? '',
            author: articleData['author'] ?? 'Unknown',
            date: DateTime.tryParse(articleData['published_date'] ?? '') ?? DateTime.now(),
            sourceUrl: articleData['url'] ?? '',
            sourceName: articleData['source'] ?? '',
            category: articleData['categories'] ?? '',
            isFake: articleData['is_fake'] ?? false,
            sentiment: articleData['sentiment'] ?? 'neutral',
          ));
        }
        
        return ArticleResponse(
          articles: articles,
          hasMore: response.data['has_more'] ?? false,
        );
      } else {
        throw Exception('Failed to load articles');
      }
    } catch (e) {
      throw Exception('Failed to load articles: $e');
    }
  }
  
  // Get articles with null category
  static Future<ArticleResponse> getArticlesWithNullCategory({
    int page = 1, 
    int pageSize = 10,
  }) async {
    try {
      Map<String, dynamic> params = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      
      final response = await _dio.get('/articles/null-category/', queryParameters: params);
      
      if (response.statusCode == 200) {
        List<News> articles = [];
        for (var articleData in response.data['articles']) {
          articles.add(News(
            id: articleData['id'].toString(),
            title: articleData['title'] ?? '',
            content: articleData['content'] ?? '',
            image: articleData['image_url'] ?? '',
            author: articleData['author'] ?? 'Unknown',
            date: DateTime.tryParse(articleData['published_date'] ?? '') ?? DateTime.now(),
            sourceUrl: articleData['url'] ?? '',
            sourceName: articleData['source'] ?? '',
            category: articleData['categories'] ?? '',
            isFake: articleData['is_fake'] ?? false,
            sentiment: articleData['sentiment'] ?? 'neutral',
          ));
        }
        
        return ArticleResponse(
          articles: articles,
          hasMore: response.data['has_more'] ?? false,
          totalCount: response.data['total_count'] ?? 0,
        );
      } else {
        throw Exception('Failed to load articles with null category');
      }
    } catch (e) {
      print('Error fetching null category articles: $e');
      throw Exception('Failed to load articles with null category: $e');
    }
  }
}

// Class to hold article response data
class ArticleResponse {
  final List<News> articles;
  final bool hasMore;
  final int totalCount;
  
  ArticleResponse({
    required this.articles,
    required this.hasMore,
    this.totalCount = 0,
  });
}