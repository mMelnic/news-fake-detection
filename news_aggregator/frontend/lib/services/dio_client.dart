// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:flutter/foundation.dart';
// import 'dart:async';

// class DioClient {
//   // Add a callback for auth state changes
//   static Function(bool loggedIn)? onAuthStateChanged;
  
//   static final Dio dio = Dio(
//     BaseOptions(
//       baseUrl:
//           kIsWeb
//               ? 'http://localhost:8000'
//               : 'http://10.0.2.2:8000', // Android emulator
//       headers: {'Content-Type': 'application/json'},
//       connectTimeout: const Duration(seconds: 20),  // Increase from 5 to 20 seconds
//       receiveTimeout: const Duration(seconds: 20),  // Add receive timeout
//       sendTimeout: const Duration(seconds: 20),     // Add send timeout
//       // Enable cookies and credentials for all requests
//       extra: {'withCredentials': true},
//     ),
//   );

//   static final storage = FlutterSecureStorage();
//   static final GlobalKey<NavigatorState> navigatorKey =
//       GlobalKey<NavigatorState>();
  
//   static Timer? _refreshTimer;

//   static void setupInterceptors() {
//     dio.interceptors.clear();
//     dio.interceptors.add(
//       InterceptorsWrapper(
//         onRequest: (options, handler) async {
//           // Ensure cookies are sent with each request
//           options.extra['withCredentials'] = true;
          
//           // For mobile devices, manually add stored cookies if any
//           if (!kIsWeb) {
//             final cookies = await storage.read(key: 'cookies');
//             if (cookies != null) {
//               options.headers['Cookie'] = cookies;
//             }
//           }

//           handler.next(options);
//         },
//         onResponse: (response, handler) async {
//           // Store cookies from response for mobile devices
//           if (!kIsWeb && response.headers['set-cookie'] != null) {
//             final existingCookies = await storage.read(key: 'cookies') ?? '';
//             final newCookies = response.headers['set-cookie']!;

//             final updatedCookies = _mergeCookies(existingCookies, newCookies);
//             await storage.write(key: 'cookies', value: updatedCookies);
            
//             // Notify auth state change if this is an auth-related endpoint
//             if (response.requestOptions.path.contains('/auth/')) {
//               onAuthStateChanged?.call(true);
//             }
//           }
//           handler.next(response);
//         },
//         onError: (DioException error, handler) async {
//           // Handle 401 errors (token expired)
//           if (error.response?.statusCode == 401) {
//             try {
//               final options = error.requestOptions;
              
//               // Try to refresh the token with an empty request
//               final tokenDio = Dio(BaseOptions(
//                 baseUrl: dio.options.baseUrl,
//                 headers: {'Content-Type': 'application/json'},
//                 extra: {'withCredentials': true},
//               ));

//               // For mobile, manually add cookies to the refresh request
//               if (!kIsWeb) {
//                 final cookies = await storage.read(key: 'cookies');
//                 if (cookies != null) {
//                   tokenDio.options.headers['Cookie'] = cookies;
//                 }
//               }

//               final refreshResponse = await tokenDio.post(
//                 '/auth/token/refresh/',
//                 options: Options(extra: {'withCredentials': true}),
//               );

//               if (refreshResponse.statusCode == 200) {
//                 // For mobile, store the new cookies from the response
//                 if (!kIsWeb && refreshResponse.headers['set-cookie'] != null) {
//                   await storage.write(
//                     key: 'cookies',
//                     value: refreshResponse.headers['set-cookie']!.join('; '),
//                   );
//                 }
                
//                 // Notify successful refresh
//                 onAuthStateChanged?.call(true);
                
//                 final response = await dio.fetch(options);
//                 return handler.resolve(response);
//               }
              
//               // If refresh failed, redirect to login and notify auth change
//               onAuthStateChanged?.call(false);
//               navigatorKey.currentState?.pushReplacementNamed('/login');
              
//             } catch (e) {
//               debugPrint('Token refresh failed: $e');
//               onAuthStateChanged?.call(false);
//               navigatorKey.currentState?.pushReplacementNamed('/login');
//             }
//           }
          
//           _handleError(error);
//           handler.next(error);
//         },
//       ),
//     );
    
//     _setupAutoRefresh();
//   }

//   // Auto-refresh timer to refresh token every 4 minutes 40 seconds
//   static void _setupAutoRefresh() {
//     _refreshTimer?.cancel();
    
//     _refreshTimer = Timer.periodic(const Duration(seconds: 280), (timer) async {
//       try {
//         final success = await refreshTokens();
//         if (success) {
//           debugPrint('Token automatically refreshed');
//           // Notify auth state change on successful auto-refresh
//           onAuthStateChanged?.call(true);
//         } else {
//           debugPrint('Automatic token refresh failed');
//           // Notify auth state change on failed auto-refresh
//           onAuthStateChanged?.call(false);
//         }
//       } catch (e) {
//         debugPrint('Automatic token refresh error: $e');
//       }
//     });
//   }
  
//   static Future<bool> refreshTokens() async {
//     try {
//       final tokenDio = Dio(BaseOptions(
//         baseUrl: dio.options.baseUrl,
//         headers: {'Content-Type': 'application/json'},
//         extra: {'withCredentials': true},
//       ));

//       // Manually add cookies to the refresh request
//       if (!kIsWeb) {
//         final cookies = await storage.read(key: 'cookies');
//         if (cookies != null) {
//           tokenDio.options.headers['Cookie'] = cookies;
//         }
//       }

//       final response = await tokenDio.post(
//         '/auth/token/refresh/',
//         options: Options(extra: {'withCredentials': true}),
//       );

//       if (response.statusCode == 200) {
//         if (!kIsWeb && response.headers['set-cookie'] != null) {
//           final existingCookies = await storage.read(key: 'cookies') ?? '';
//           final newCookies = response.headers['set-cookie']!;
//           final updatedCookies = _mergeCookies(existingCookies, newCookies);
//           await storage.write(key: 'cookies', value: updatedCookies);
//         }
//         return true;
//       }
//       return false;
//     } catch (e) {
//       debugPrint('Token refresh error: $e');
//       return false;
//     }
//   }

//   static String _mergeCookies(String existingRaw, List<String> newSetCookies) {
//     final existingMap = <String, String>{};

//     for (final part in existingRaw.split(';')) {
//       final cookie = part.trim();
//       if (cookie.contains('=')) {
//         final split = cookie.split('=');
//         if (split.length == 2) {
//           existingMap[split[0]] = split[1];
//         }
//       }
//     }

//     for (final setCookie in newSetCookies) {
//       final parts = setCookie.split(';')[0].split('=');
//       if (parts.length == 2) {
//         existingMap[parts[0]] = parts[1];
//       }
//     }

//     return existingMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
//   }

  
//   // This method will attempt to restore an authenticated session
//   static Future<bool> tryAutoLogin() async {
//     try {
//       final success = await refreshTokens();
//       if (success) {
//         setupInterceptors();
//         // Notify auth state change
//         onAuthStateChanged?.call(true);
//         return true;
//       }
//       onAuthStateChanged?.call(false);
//       return false;
//     } catch (e) {
//       debugPrint('Auto-login error: $e');
//       onAuthStateChanged?.call(false);
//       return false;
//     }
//   }
  
//   static void cancelRefreshTimer() {
//     _refreshTimer?.cancel();
//     _refreshTimer = null;
//     debugPrint('Auto-refresh timer cancelled');
//   }

//   static void _handleError(DioException e) {
//     String errorMessage;

//     switch (e.type) {
//       case DioExceptionType.connectionTimeout:
//         errorMessage = "Connection timeout. Please try again!";
//         break;
//       case DioExceptionType.sendTimeout:
//         errorMessage = "Request timeout. Check your network!";
//         break;
//       case DioExceptionType.receiveTimeout:
//         errorMessage = "Server took too long to respond!";
//         break;
//       case DioExceptionType.badResponse:
//         errorMessage = "Invalid response from server!";
//         break;
//       case DioExceptionType.cancel:
//         errorMessage = "Request was canceled!";
//         break;
//       case DioExceptionType.unknown:
//       default:
//         errorMessage = "An unexpected error occurred!";
//     }

//     debugPrint("Dio error: $errorMessage");
//   }
// }
