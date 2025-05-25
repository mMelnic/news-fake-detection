class News {
  final String title;
  final String photo;
  final String description;
  final String date;
  final String author;

  News({
    required this.title,
    required this.photo,
    required this.description,
    required this.date,
    required this.author,
  });

  factory News.fromMap(Map<String, dynamic> map) {
    return News(
      title: map['title']?.toString() ?? '',
      photo: map['photo']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      author: map['author']?.toString() ?? '',
    );
  }
}