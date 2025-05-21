import 'package:dio/dio.dart';
import 'dio_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final Dio dio = DioClient.dio;
  final FlutterSecureStorage storage = DioClient.storage;

  Future<void> _storeCookies(Response response) async {
    if (!kIsWeb && response.headers['set-cookie'] != null) {
      await storage.write(
        key: 'cookies',
        value: response.headers['set-cookie']!.join('; '),
      );
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
        options: Options(extra: {'withCredentials': true}),
      );
      
      if (response.statusCode == 201) {
        await _storeCookies(response);
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
        options: Options(
          headers: {'Content-Type': 'application/json'}, 
          extra: {'withCredentials': true}
        ),
      );

      if (response.statusCode == 200) {
        await _storeCookies(response);
        DioClient.setupInterceptors();
      }
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> initializeAuth() async {
    final cookies = await storage.read(key: 'cookies');
    if (cookies != null) {
      DioClient.setupInterceptors();
    }
  }

  Future<Response> logout() async {
    try {
      final response = await dio.post('/auth/logout/');
      await _clearAuthData();
      
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> _clearAuthData() async {
    await storage.delete(key: 'cookies');
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
    
    DioClient.cancelRefreshTimer();
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
  
  Future<bool> isLoggedIn() async {
    final cookies = await storage.read(key: 'cookies');
    return cookies != null;
  }
}

