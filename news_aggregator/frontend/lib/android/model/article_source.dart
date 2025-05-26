
class Source {
  final int id;
  final String name;
  final String url;
  final String? country;
  final String? language;

  Source({
    required this.id,
    required this.name,
    required this.url,
    this.country,
    this.language,
  });

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      id: json['id'],
      name: json['name'],
      url: json['url'],
      country: json['country'],
      language: json['language'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'country': country,
    'language': language,
  };
}

class Article {
  final int id;
  final String title;
  final String? author;
  final String content;
  final String url;
  final String imageUrl;
  final String sourceName; // simplified: source name string from backend
  final DateTime publishedDate;
  final String? country;
  final String? language;
  final String? categories;
  final bool? isFake;
  final String? sentiment;

  Article({
    required this.id,
    required this.title,
    this.author,
    required this.content,
    required this.url,
    required this.imageUrl,
    required this.sourceName,
    required this.publishedDate,
    this.country,
    this.language,
    this.categories,
    this.isFake,
    this.sentiment,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      content: json['content'],
      url: json['url'],
      imageUrl: json['image_url'] ?? 'default_image_url_here',
      sourceName: json['source'] ?? 'Unknown',
      publishedDate: DateTime.parse(json['published_date']),
      country: json['country'],
      language: json['language'],
      categories: json['categories'],
      isFake: json['is_fake'],
      sentiment: json['sentiment'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'content': content,
    'url': url,
    'image_url': imageUrl,
    'source': sourceName,
    'published_date': publishedDate.toIso8601String(),
    'country': country,
    'language': language,
    'categories': categories,
    'is_fake': isFake,
    'sentiment': sentiment,
  };
}