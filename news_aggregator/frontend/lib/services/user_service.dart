// import 'package:dio/dio.dart';
// import '../models/user_profile.dart';
// import 'dio_client.dart';

// class UserService {
//   final Dio dio = DioClient.dio;
  
//   Future<UserProfile> getCurrentUserProfile() async {
//     try {
//       final response = await dio.get('/auth/user-profile/');
//       return UserProfile.fromJson(response.data);
//     } on DioException catch (e) {
//       throw _handleError(e);
//     }
//   }
  
//   Future<UserProfile> updateUserProfile({
//     String? displayName,
//     String? bio,
//   }) async {
//     try {
//       final response = await dio.patch(
//         '/auth/user-profile/',
//         data: {
//           if (displayName != null) 'display_name': displayName,
//           if (bio != null) 'bio': bio,
//         },
//       );
//       return UserProfile.fromJson(response.data);
//     } on DioException catch (e) {
//       throw _handleError(e);
//     }
//   }
  
//   String _handleError(DioException e) {
//     if (e.response?.statusCode == 400) {
//       return e.response?.data['error'] ?? 'Profile update failed';
//     }
//     return 'Network error occurred';
//   }
// }