import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';

class DioClient {
  // Callback for auth state changes
  static Function(bool loggedIn)? onAuthStateChanged;

  static final Dio dio = Dio(
    BaseOptions(
      // baseUrl: 'http://10.0.2.2:8000', // Android emulator backend
      baseUrl: 'http://192.168.64.5:8000', // Local network backend
      headers: {'Content-Type': 'application/json'},
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      extra: {'withCredentials': true},
    ),
  );

  static final FlutterSecureStorage storage = const FlutterSecureStorage();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Timer? _refreshTimer;

  static void setupInterceptors() {
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Ensure cookies are sent with each request
          options.extra['withCredentials'] = true;

          // Add stored cookies if any
          final cookies = await storage.read(key: 'cookies');
          if (cookies != null) {
            options.headers['Cookie'] = cookies;
          }

          handler.next(options);
        },
        onResponse: (response, handler) async {
          // Store cookies from response
          if (response.headers['set-cookie'] != null) {
            final existingCookies = await storage.read(key: 'cookies') ?? '';
            final newCookies = response.headers['set-cookie']!;

            final updatedCookies = _mergeCookies(existingCookies, newCookies);
            await storage.write(key: 'cookies', value: updatedCookies);

            // Notify auth state change if this is an auth-related endpoint
            if (response.requestOptions.path.contains('/auth/')) {
              onAuthStateChanged?.call(true);
            }
          }
          handler.next(response);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            try {
              final options = error.requestOptions;

              final tokenDio = Dio(
                BaseOptions(
                  baseUrl: dio.options.baseUrl,
                  headers: {'Content-Type': 'application/json'},
                  extra: {'withCredentials': true},
                ),
              );

              // Add cookies to refresh request
              final cookies = await storage.read(key: 'cookies');
              if (cookies != null) {
                tokenDio.options.headers['Cookie'] = cookies;
              }

              final refreshResponse = await tokenDio.post(
                '/auth/token/refresh/',
                options: Options(extra: {'withCredentials': true}),
              );

              if (refreshResponse.statusCode == 200) {
                if (refreshResponse.headers['set-cookie'] != null) {
                  await storage.write(
                    key: 'cookies',
                    value: refreshResponse.headers['set-cookie']!.join('; '),
                  );
                }

                onAuthStateChanged?.call(true);

                final response = await dio.fetch(options);
                return handler.resolve(response);
              }

              onAuthStateChanged?.call(false);
              navigatorKey.currentState?.pushReplacementNamed('/login');
            } catch (e) {
              debugPrint('Token refresh failed: $e');
              onAuthStateChanged?.call(false);
              navigatorKey.currentState?.pushReplacementNamed('/login');
            }
          }

          _handleError(error);
          handler.next(error);
        },
      ),
    );

    _setupAutoRefresh();
  }

  static void _setupAutoRefresh() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(const Duration(seconds: 280), (timer) async {
      try {
        final success = await refreshTokens();
        if (success) {
          debugPrint('Token automatically refreshed');
          onAuthStateChanged?.call(true);
        } else {
          debugPrint('Automatic token refresh failed');
          onAuthStateChanged?.call(false);
        }
      } catch (e) {
        debugPrint('Automatic token refresh error: $e');
      }
    });
  }

  static Future<bool> refreshTokens() async {
    try {
      final tokenDio = Dio(
        BaseOptions(
          baseUrl: dio.options.baseUrl,
          headers: {'Content-Type': 'application/json'},
          extra: {'withCredentials': true},
        ),
      );

      final cookies = await storage.read(key: 'cookies');
      if (cookies != null) {
        tokenDio.options.headers['Cookie'] = cookies;
      }

      final response = await tokenDio.post(
        '/auth/token/refresh/',
        options: Options(extra: {'withCredentials': true}),
      );

      if (response.statusCode == 200) {
        if (response.headers['set-cookie'] != null) {
          final existingCookies = await storage.read(key: 'cookies') ?? '';
          final newCookies = response.headers['set-cookie']!;
          final updatedCookies = _mergeCookies(existingCookies, newCookies);
          await storage.write(key: 'cookies', value: updatedCookies);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }

  static String _mergeCookies(String existingRaw, List<String> newSetCookies) {
    final existingMap = <String, String>{};

    for (final part in existingRaw.split(';')) {
      final cookie = part.trim();
      if (cookie.contains('=')) {
        final split = cookie.split('=');
        if (split.length == 2) {
          existingMap[split[0]] = split[1];
        }
      }
    }

    for (final setCookie in newSetCookies) {
      final parts = setCookie.split(';')[0].split('=');
      if (parts.length == 2) {
        existingMap[parts[0]] = parts[1];
      }
    }

    return existingMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  static Future<bool> tryAutoLogin() async {
    try {
      final success = await refreshTokens();
      if (success) {
        setupInterceptors();
        onAuthStateChanged?.call(true);
        return true;
      }
      onAuthStateChanged?.call(false);
      return false;
    } catch (e) {
      debugPrint('Auto-login error: $e');
      onAuthStateChanged?.call(false);
      return false;
    }
  }

  static void cancelRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    debugPrint('Auto-refresh timer cancelled');
  }

  static void _handleError(DioException e) {
    String errorMessage;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        errorMessage = "Connection timeout. Please try again!";
        break;
      case DioExceptionType.sendTimeout:
        errorMessage = "Request timeout. Check your network!";
        break;
      case DioExceptionType.receiveTimeout:
        errorMessage = "Server took too long to respond!";
        break;
      case DioExceptionType.badResponse:
        errorMessage = "Invalid response from server!";
        break;
      case DioExceptionType.cancel:
        errorMessage = "Request was canceled!";
        break;
      case DioExceptionType.unknown:
      default:
        errorMessage = "An unexpected error occurred!";
    }

    debugPrint("Dio error: $errorMessage");
  }
}