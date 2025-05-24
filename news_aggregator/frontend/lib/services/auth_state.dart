// import 'package:flutter/material.dart';
// import 'dio_client.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// class AuthState extends ChangeNotifier {
//   bool _loggedIn = false;
//   final _storage = const FlutterSecureStorage();

//   bool get isLoggedIn => _loggedIn;

//   void login() {
//     _loggedIn = true;
//     notifyListeners();
//   }

//   void logout() {
//     _loggedIn = false;
//     DioClient.cancelRefreshTimer(); // Cancel refresh timer on logout
//     notifyListeners();
//   }

//   // Listen for token refresh events
//   AuthState() {
//     // Setup a listener for token refresh events
//     DioClient.onAuthStateChanged = (bool loggedIn) {
//       if (_loggedIn != loggedIn) {
//         _loggedIn = loggedIn;
//         notifyListeners();
//       }
//     };
//   }

//   Future<void> checkInitialLoginStatus() async {
//     try {
//       // Check if we have valid cookies or can refresh tokens
//       final hasCookies = await _storage.read(key: 'cookies') != null;
      
//       if (hasCookies) {
//         final success = await DioClient.tryAutoLogin();
//         _loggedIn = success;
//       } else {
//         _loggedIn = false;
//       }
//     } catch (e) {
//       _loggedIn = false;
//     }
//     notifyListeners();
//   }
// }