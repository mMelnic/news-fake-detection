class Category {
  final String name;

  Category({required this.name});

  factory Category.fromMap(Map<String, dynamic> map) {
    final name = map['name'];
    if (name == null) {
      throw ArgumentError('Category name is null');
    }
    return Category(name: name.toString());
  }
}
