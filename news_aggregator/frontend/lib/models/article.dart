class Article {
  final int id;
  final String title;
  final String content;
  final String url;
  final String? imageUrl;
  final String? author;
  final DateTime? publishedDate;
  final String source;
  final bool hasEmbedding;
  final bool? isFake;
  final double? fakeScore;
  final String? sentiment;
  
  Article({
    required this.id,
    required this.title,
    required this.content,
    required this.url,
    this.imageUrl,
    this.author,
    this.publishedDate,
    required this.source,
    required this.hasEmbedding,
    this.isFake,
    this.fakeScore,
    this.sentiment,
  });
  
  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      url: json['url'] ?? '',
      imageUrl: json['image_url'],
      author: json['author'] ?? 'Unknown',
      publishedDate: json['published_date'] != null 
          ? DateTime.parse(json['published_date']) 
          : null,
      source: json['source'] ?? 'Unknown',
      hasEmbedding: json['has_embedding'] ?? false,
      isFake: json['is_fake'],
      fakeScore: json['fake_score']?.toDouble(),
      sentiment: json['sentiment'],
    );
  }
}