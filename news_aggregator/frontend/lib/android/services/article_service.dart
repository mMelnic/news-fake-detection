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
  
  // Get saved article status
  static Future<bool> isArticleSaved(String articleId) async {
    try {
      // Assuming there's an endpoint for checking saved status
      final response = await _dio.get('/social/saved/$articleId/');
      
      if (response.statusCode == 200) {
        return response.data['saved'];
      } else {
        return false;
      }
    } catch (e) {
      // Return false as default if there's an error
      return false;
    }
  }
  
  // Save/unsave an article
  static Future<bool> toggleSaved(String articleId) async {
    try {
      // Assuming there's an endpoint for toggling saved status
      final response = await _dio.post(
        '/social/saved/',
        data: {'article_id': articleId},
      );
      
      if (response.statusCode == 200) {
        return response.data['saved'];
      } else {
        return false;
      }
    } catch (e) {
      throw Exception('Failed to toggle saved status: $e');
    }
  }
}