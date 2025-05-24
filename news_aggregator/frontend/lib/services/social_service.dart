// import 'package:dio/dio.dart';
// import '../models/comment.dart';
// import 'dio_client.dart';

// class SocialService {
//   final Dio dio = DioClient.dio;
  
//   Future<bool> toggleLike(dynamic articleId) async {
//     try {
//       final response = await dio.post(
//         '/social/likes/',
//         data: {'article_id': articleId.toString()},
//       );
//       return response.statusCode == 200 || response.statusCode == 201;
//     } on DioException catch (e) {
//       throw _handleError(e);
//     }
//   }
  
//   Future<bool> isArticleLiked(dynamic articleId) async {
//     try {
//       final response = await dio.get(
//         '/social/likes/${articleId.toString()}/',
//       );
//       return response.data['liked'] ?? false;
//     } on DioException catch (e) {
//       if (e.response?.statusCode == 404) {
//         return false;
//       }
//       throw _handleError(e);
//     }
//   }
  
//   Future<int> getArticleLikeCount(dynamic articleId) async {
//     try {
//       final response = await dio.get(
//         '/social/likes/${articleId.toString()}/count/',
//       );
//       return response.data['count'] ?? 0;
//     } on DioException catch (e) {
//       throw _handleError(e);
//     }
//   }
  
//   Future<Comment> addComment(dynamic articleId, String content) async {
//     try {
//       final response = await dio.post(
//         '/social/comments/',
//         data: {
//           'article_id': articleId.toString(),
//           'content': content,
//         },
//       );
//       return Comment.fromJson(response.data);
//     } on DioException catch (e) {
//       throw _handleError(e);
//     }
//   }
  
//   Future<List<Comment>> getArticleComments(dynamic articleId) async {
//     try {
//       final response = await dio.get(
//         '/social/comments/${articleId.toString()}/',
//       );
      
//       final List<dynamic> commentData = response.data['comments'] ?? [];
//       return commentData.map((json) => Comment.fromJson(json)).toList();
//     } on DioException catch (e) {
//       throw _handleError(e);
//     }
//   }
  
//   String _handleError(DioException e) {
//     if (e.response?.statusCode == 400) {
//       return e.response?.data['error'] ?? 'Operation failed';
//     }
//     if (e.response?.statusCode == 401) {
//       return 'You need to be logged in';
//     }
//     return 'Network error occurred';
//   }
// }