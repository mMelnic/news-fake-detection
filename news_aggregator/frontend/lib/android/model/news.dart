class News {
  final String id;
  final String title;
  final String content;
  final String image;
  final String author;
  final DateTime date;
  final String sourceUrl;
  final String sourceName;
  final String category;
  final bool isFake;
  final String sentiment;

  News({
    required this.id,
    required this.title,
    required this.content,
    required this.image,
    required this.author,
    required this.date,
    required this.sourceUrl,
    required this.sourceName,
    required this.category,
    required this.isFake,
    required this.sentiment,
  });

  factory News.fromMap(Map<String, dynamic> map) {
    return News(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      image: map['image_url']?.toString() ?? '',
      author: map['author']?.toString() ?? 'Unknown',
      date:
          DateTime.tryParse(map['published_date'] ?? '') ?? DateTime.now(),
      sourceUrl: map['url']?.toString() ?? '',
      sourceName: map['source']?.toString() ?? '',
      category: map['categories']?.toString() ?? '',
      isFake: map['is_fake'] ?? false,
      sentiment: map['sentiment']?.toString() ?? 'neutral',
    );
  }
}
