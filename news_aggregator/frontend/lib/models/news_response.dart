import 'article.dart';

class WebSocketInfo {
  final bool useWebsocket;
  final String websocketUrl;
  
  WebSocketInfo({
    required this.useWebsocket,
    required this.websocketUrl,
  });
  
  factory WebSocketInfo.fromJson(Map<String, dynamic> json) {
    return WebSocketInfo(
      useWebsocket: json['use_websocket'] ?? false,
      websocketUrl: json['websocket_url'] ?? '',
    );
  }
}

class NewsResponse {
  final String message;
  final List<Article> articles;
  final int articleCount;
  final bool fromDbOnly;
  final WebSocketInfo? websocketInfo;
  
  NewsResponse({
    required this.message,
    required this.articles,
    required this.articleCount,
    required this.fromDbOnly,
    this.websocketInfo,
  });
  
  factory NewsResponse.fromJson(Map<String, dynamic> json) {
    return NewsResponse(
      message: json['message'] ?? '',
      articles: (json['articles'] as List)
          .map((article) => Article.fromJson(article))
          .toList(),
      articleCount: json['article_count'] ?? 0,
      fromDbOnly: json['from_db_only'] ?? true,
      websocketInfo: json.containsKey('websocket') 
          ? WebSocketInfo.fromJson(json['websocket']) 
          : null,
    );
  }
}