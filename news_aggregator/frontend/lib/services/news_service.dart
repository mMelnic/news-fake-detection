import 'package:dio/dio.dart';
import '../models/news_response.dart';
import 'dio_client.dart';

class NewsService {
  Future<NewsResponse> fetchArticles({
    required String query,
    String language = 'en',
    String? country,
    bool freshOnly = true,
    bool refresh = false,
  }) async {
    try {
      final queryParams = {
        'query': query,
        'language': language,
        'fresh_only': freshOnly.toString(),
        'refresh': refresh.toString(),
      };
      
      if (country != null) {
        queryParams['country'] = country;
      }
      
      final response = await DioClient.dio.get(
        '/news/',
        queryParameters: queryParams,
      );
      
      return NewsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to load articles: ${e.message}');
    }
  }
}