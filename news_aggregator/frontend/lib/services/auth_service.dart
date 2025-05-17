import 'package:dio/dio.dart';
import 'dio_client.dart';
class AuthService {
  final Dio dio = DioClient.dio;

  Future<Response> register(
    String username,
    String email,
    String password,
  ) async {
    return await dio.post(
      '/auth/register/',
      data: {'username': username, 'email': email, 'password': password},
    );
  }

  Future<Response> login(String username, String password) async {
    final response = await dio.post(
      '/auth/login/',
      data: {'username': username, 'password': password},
      options: Options(headers: {'Content-Type': 'application/json'}, extra: {'withCredentials': true},),
    );

    if (response.statusCode == 200) {
      DioClient.setupInterceptors(); // Cookie handling is active
    }

    return response;
  }

  Future<Response> logout() async {
    return await dio.post('/auth/logout/');
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
}

