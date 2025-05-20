import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class DioClient {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl:
          kIsWeb
              ? 'http://localhost:8000'
              : 'http://10.0.2.2:8000', // Android emulator
      headers: {'Content-Type': 'application/json'},
      connectTimeout: const Duration(seconds: 5),
      // Enable cookies and credentials for all requests
      extra: {'withCredentials': true},
    ),
  );

  static final storage = FlutterSecureStorage();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  
  // Timer for auto refresh
  static Timer? _refreshTimer;

  static void setupInterceptors() {
    dio.interceptors.clear(); // Clear existing interceptors to avoid duplicates
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Ensure cookies are sent with each request
          options.extra['withCredentials'] = true;
          
          // For mobile devices, manually add stored cookies if any
          if (!kIsWeb) {
            final cookies = await storage.read(key: 'cookies');
            if (cookies != null) {
              options.headers['Cookie'] = cookies;
            }
          }

          handler.next(options);
        },
        onResponse: (response, handler) async {
          // Store cookies from response for mobile devices
          if (!kIsWeb && response.headers['set-cookie'] != null) {
            await storage.write(
              key: 'cookies',
              value: response.headers['set-cookie']!.join('; '),
            );
          }
          handler.next(response);
        },
        onError: (DioException error, handler) async {
          // Handle 401 errors (token expired)
          if (error.response?.statusCode == 401) {
            try {
              // Get the original request options
              final options = error.requestOptions;
              
              // Try to refresh the token with an empty request
              // Since we're using HTTP-only cookies, the refresh token
              // will be sent automatically with the request
              final tokenDio = Dio(BaseOptions(
                baseUrl: dio.options.baseUrl,
                headers: {'Content-Type': 'application/json'},
                extra: {'withCredentials': true},
              ));

              // For mobile, manually add cookies to the refresh request
              if (!kIsWeb) {
                final cookies = await storage.read(key: 'cookies');
                if (cookies != null) {
                  tokenDio.options.headers['Cookie'] = cookies;
                }
              }

              // Send an empty request to the refresh endpoint
              final refreshResponse = await tokenDio.post(
                '/auth/token/refresh/',
                options: Options(extra: {'withCredentials': true}),
              );

              if (refreshResponse.statusCode == 200) {
                // For mobile, store the new cookies from the response
                if (!kIsWeb && refreshResponse.headers['set-cookie'] != null) {
                  await storage.write(
                    key: 'cookies',
                    value: refreshResponse.headers['set-cookie']!.join('; '),
                  );
                }
                
                // Restart auto-refresh timer
                _setupAutoRefresh();
                
                // Retry the original request
                // The new token cookies will be sent automatically
                final response = await dio.fetch(options);
                return handler.resolve(response);
              }
              
              // If refresh failed, redirect to login
              navigatorKey.currentState?.pushReplacementNamed('/login');
              
            } catch (e) {
              debugPrint('Token refresh failed: $e');
              navigatorKey.currentState?.pushReplacementNamed('/login');
            }
          }
          
          // Handle other errors
          _handleError(error);
          handler.next(error);
        },
      ),
    );
    
    // Setup automatic refresh timer
    _setupAutoRefresh();
  }
  
  // Set up auto-refresh timer to refresh token every 4.5 minutes
  static void _setupAutoRefresh() {
    // Cancel existing timer if any
    _refreshTimer?.cancel();
    
    // Create a new timer - 4.5 minutes = 270 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 270), (timer) async {
      try {
        final success = await refreshTokens();
        if (success) {
          debugPrint('Token automatically refreshed');
        } else {
          debugPrint('Automatic token refresh failed');
        }
      } catch (e) {
        debugPrint('Automatic token refresh error: $e');
        // Don't logout on background refresh failure, 
        // let the interceptor handle it on the next request
      }
    });
  }
  
  // Helper method to refresh tokens - now simplified for HTTP-only cookies
  static Future<bool> refreshTokens() async {
    try {
      final tokenDio = Dio(BaseOptions(
        baseUrl: dio.options.baseUrl,
        headers: {'Content-Type': 'application/json'},
        extra: {'withCredentials': true},
      ));

      // For mobile, manually add cookies to the refresh request
      if (!kIsWeb) {
        final cookies = await storage.read(key: 'cookies');
        if (cookies != null) {
          tokenDio.options.headers['Cookie'] = cookies;
        }
      }

      // Send an empty request to the refresh endpoint
      final response = await tokenDio.post(
        '/auth/token/refresh/',
        options: Options(extra: {'withCredentials': true}),
      );

      if (response.statusCode == 200) {
        // For mobile, store the new cookies from the response
        if (!kIsWeb && response.headers['set-cookie'] != null) {
          await storage.write(
            key: 'cookies',
            value: response.headers['set-cookie']!.join('; '),
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }
  
  // This method will attempt to restore an authenticated session
  static Future<bool> tryAutoLogin() async {
    try {
      // With HTTP-only cookies, we just need to try a refresh
      final success = await refreshTokens();
      if (success) {
        setupInterceptors(); // Set up interceptors with the refreshed cookies
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Auto-login error: $e');
      return false;
    }
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
