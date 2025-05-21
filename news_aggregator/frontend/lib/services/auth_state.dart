import 'package:flutter/material.dart';
import 'dio_client.dart';

class AuthState extends ChangeNotifier {
  bool _loggedIn = false;

  bool get isLoggedIn => _loggedIn;

  void login() {
    _loggedIn = true;
    notifyListeners();
  }

  void logout() {
    _loggedIn = false;
    notifyListeners();
  }

  Future<void> checkInitialLoginStatus() async {
    _loggedIn = await DioClient.tryAutoLogin();
    notifyListeners();
  }
}