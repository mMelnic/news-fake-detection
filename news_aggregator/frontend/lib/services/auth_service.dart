import 'package:dio/dio.dart';
import 'dio_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final Dio dio = DioClient.dio;
  final FlutterSecureStorage storage = DioClient.storage;

  Future<void> _storeCookies(Response response) async {
    if (response.headers['set-cookie'] != null) {
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
          extra: {'withCredentials': true},
        ),
      );

      if (response.statusCode == 200) {
        await _storeCookies(response);

        if (response.data != null && response.data is Map) {
          final data = response.data;
          if (data.containsKey('data') && data['data'] is Map) {
            final tokenData = data['data'];
            if (tokenData.containsKey('access')) {
              await storage.write(
                key: 'access_token',
                value: tokenData['access'],
              );
            }
            if (tokenData.containsKey('refresh')) {
              await storage.write(
                key: 'refresh_token',
                value: tokenData['refresh'],
              );
            }

            try {
              final userResponse = await getCurrentUser();
              if (userResponse.statusCode == 200 && userResponse.data != null) {
                if (userResponse.data['display_name'] != null) {
                  await storage.write(
                    key: 'user_display_name',
                    value: userResponse.data['display_name'],
                  );
                }
                if (userResponse.data['username'] != null) {
                  await storage.write(
                    key: 'username',
                    value: userResponse.data['username'],
                  );
                }
              }
            } catch (e) {
              debugPrint('Error fetching user data: $e');
            }
          }
        }

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

  Future<bool> checkInitialLoginStatus() async {
    try {
      final hasCookies = await storage.read(key: 'cookies') != null;

      if (hasCookies) {
        final success = await DioClient.tryAutoLogin();
        return success;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}