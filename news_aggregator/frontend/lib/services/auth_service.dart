import 'package:dio/dio.dart';
import 'dio_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final Dio dio = DioClient.dio;
  final FlutterSecureStorage storage = DioClient.storage;

  Future<void> _storeTokens(Map<String, dynamic> data) async {
    if (data.containsKey('data') && data['data'] is Map) {
      // Handle case when tokens are in a nested 'data' object
      final tokenData = data['data'];
      await storage.write(key: 'access_token', value: tokenData['access']);
      await storage.write(key: 'refresh_token', value: tokenData['refresh']);
    } else if (data.containsKey('access') && data.containsKey('refresh')) {
      // Handle direct token structure
      await storage.write(key: 'access_token', value: data['access']);
      await storage.write(key: 'refresh_token', value: data['refresh']);
    }
  }

  Future<Response> register(
    String username,
    String email,
    String password,
  ) async {
    try {
      final response = await dio.post(
        '/auth/register/',
        data: {'username': username, 'email': email, 'password': password},
      );
      
      if (response.statusCode == 201) {
        // If the backend gives us tokens in the registration response, store them
        if (response.data is Map) {
          await _storeTokens(response.data);
        }
        
        // Set up interceptors for future requests
        DioClient.setupInterceptors(); 
      }
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  String _handleDioError(DioException e) {
    if (e.response?.statusCode == 400) {
      return e.response?.data['error'] ?? 'Registration failed';
    }
    return 'Network error occurred';
  }

  Future<Response> login(String username, String password) async {
    try {
      final response = await dio.post(
        '/auth/login/',
        data: {'username': username, 'password': password},
        options: Options(headers: {'Content-Type': 'application/json'}, extra: {'withCredentials': true}),
      );

      if (response.statusCode == 200) {
        // Store tokens from response
        await _storeTokens(response.data);
        
        // Setup interceptors with the fresh tokens
        DioClient.setupInterceptors();
      }
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Automatic token refresh setup
  Future<void> initializeAuth() async {
    // Check if we have a refresh token
    final refreshToken = await storage.read(key: 'refresh_token');
    if (refreshToken != null) {
      // Setup interceptors if we have a refresh token
      DioClient.setupInterceptors();
    }
  }

  Future<Response> logout() async {
    try {
      final response = await dio.post('/auth/logout/');
      // Clear local storage on logout
      await storage.delete(key: 'access_token');
      await storage.delete(key: 'refresh_token');
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> getCurrentUser() async {
    return await dio.get('/auth/user/');
  }

  Future<Response> changePassword(String oldPass, String newPass) async {
    return await dio.post(
      '/auth/change-password/',
      data: {'old_password': oldPass, 'new_password': newPass},
    );
  }
  
  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final accessToken = await storage.read(key: 'access_token');
    final refreshToken = await storage.read(key: 'refresh_token');
    return accessToken != null && refreshToken != null;
  }
}

