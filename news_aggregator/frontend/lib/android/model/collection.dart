class Collection {
  final int id;
  final String name;
  final int articleCount;
  final DateTime createdAt;
  final String coverImage;
  
  Collection({
    required this.id,
    required this.name,
    required this.articleCount,
    required this.createdAt,
    required this.coverImage,
  });
  
  factory Collection.fromMap(Map<String, dynamic> map) {
    return Collection(
      id: map['id'],
      name: map['name'],
      articleCount: map['article_count'],
      createdAt: DateTime.parse(map['created_at']),
      coverImage: map['cover_image'] ?? '',
    );
  }
}