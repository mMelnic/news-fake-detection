import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class DioClient {
  static final Dio dio = Dio(
    BaseOptions(
      // 10.0.2.2 for Android emulator to access localhost
      baseUrl:
          kIsWeb
              ? 'http://localhost:8000'
              : 'http://10.0.2.2:8000', // Android emulator
      headers: {'Content-Type': 'application/json'},
      connectTimeout: const Duration(seconds: 5),
    ),
  );

  static final storage = FlutterSecureStorage();

  static void setupInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!kIsWeb) {
            // Android: Load cookies from secure storage
            final cookies = await storage.read(key: 'cookies');
            if (cookies != null) {
              options.headers['Cookie'] = cookies;
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          if (!kIsWeb && response.headers['set-cookie'] != null) {
            // Android: Save cookies to secure storage
            await storage.write(
              key: 'cookies',
              value: response.headers['set-cookie']!.join('; '),
            );
          }
          handler.next(response);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await refreshToken();
            if (refreshed) {
              return handler.resolve(await dio.fetch(error.requestOptions));
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  static Future<bool> refreshToken() async {
    try {
      final response = await dio.post(
        '/token/refresh/',
        options: Options(
          headers: {'Content-Type': 'application/json'},
          extra: kIsWeb ? {'withCredentials': true} : {},
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Refresh token error: $e');
      return false;
    }
  }
}