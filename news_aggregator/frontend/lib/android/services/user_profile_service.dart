import 'package:dio/dio.dart';
import '../../services/dio_client.dart';

class UserProfileService {
  static final Dio _dio = DioClient.dio;
  
  // Fetch user profile
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await _dio.get('/auth/user-profile/');
      
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to load user profile');
      }
    } catch (e) {
      throw Exception('Failed to load user profile: $e');
    }
  }
  
  // Update user profile
  static Future<Map<String, dynamic>> updateUserProfile({
    String? displayName,
    String? bio,
    String? preferredLanguage,
    String? country,
  }) async {
    try {
      final response = await _dio.patch(
        '/auth/user-profile/',
        data: {
          if (displayName != null) 'display_name': displayName,
          if (bio != null) 'bio': bio,
          if (preferredLanguage != null) 'preferred_language': preferredLanguage,
          if (country != null) 'country': country,
        },
      );
      
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to update user profile');
      }
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }
  
  // Get user interaction stats
  static Future<Map<String, dynamic>> getUserStats() async {
    try {
      final response = await _dio.get('/user/stats/');
      
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to load user stats');
      }
    } catch (e) {
      throw Exception('Failed to load user stats: $e');
    }
  }
  
  // Get user's saved collections
  static Future<List<Map<String, dynamic>>> getSavedCollections() async {
    try {
      final response = await _dio.get('/collections/');
      
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['collections']);
      } else {
        throw Exception('Failed to load collections');
      }
    } catch (e) {
      throw Exception('Failed to load collections: $e');
    }
  }
  
  // Get articles in a collection
  static Future<List<Map<String, dynamic>>> getCollectionArticles(int collectionId) async {
    try {
      final response = await _dio.get('/collections/$collectionId/articles/');
      
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['articles']);
      } else {
        throw Exception('Failed to load collection articles');
      }
    } catch (e) {
      throw Exception('Failed to load collection articles: $e');
    }
  }
}