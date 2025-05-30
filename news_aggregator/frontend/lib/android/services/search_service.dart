import 'package:dio/dio.dart';
import '../../services/dio_client.dart';
import '../model/news.dart';

class SearchService {
  static final Dio _dio = DioClient.dio;
  
  // Direct synchronous search
  static Future<List<News>> search({
    required String query,
    String? language,
    String? country,
    String mode = 'and',  // 'and' or 'or'
  }) async {
    try {
      // Construct query parameters
      final Map<String, dynamic> params = {
        'q': query,
        'mode': mode,
      };
      
      if (language != null && language.isNotEmpty) {
        params['language'] = language;
      }
      
      if (country != null && country.isNotEmpty) {
        params['country'] = country;
      }
            final response = await _dio.get('/direct-search/', queryParameters: params);
      
      if (response.statusCode == 200) {
        // Convert articles to News objects
        final List<dynamic> articlesData = response.data['articles'];
        return articlesData.map((articleData) => _convertToNews(articleData)).toList();
      } else {
        throw Exception('Failed to perform search');
      }
    } catch (e) {
      print('Search error: $e');
      throw Exception('Search failed: $e');
    }
  }
  
  static News _convertToNews(Map<String, dynamic> data) {
    return News(
      id: data['id'].toString(),
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      image: data['image_url'] ?? '',
      author: data['author'] ?? 'Unknown',
      date: DateTime.tryParse(data['published_date'] ?? '') ?? DateTime.now(),
      sourceUrl: data['url'] ?? '',
      sourceName: data['source'] ?? '',
      category: data['categories'] ?? '',
      isFake: data['is_fake'] ?? false,
      sentiment: data['sentiment'] ?? 'neutral',
    );
  }
}