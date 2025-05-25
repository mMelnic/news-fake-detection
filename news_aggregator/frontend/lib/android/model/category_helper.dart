import 'category.dart';

class CategoryHelper {
  static final List<Category> categoryData =
      categoryRawData.map((data) => Category.fromMap(data)).toList();
}

final List<Map<String, dynamic>> categoryRawData = [
  {'name': 'International'},
  {'name': 'Covid19'},
  {'name': 'Asia'},
  {'name': 'Europe'},
  {'name': 'Australia'},
  {'name': 'America'},
  {'name': 'Sports'},
  {'name': 'Health'},
  {'name': 'Politics'},
];