import 'package:flutter/material.dart';
import '../../model/category.dart';
import '../../model/category_helper.dart';
import '../../model/news.dart';
import '../../model/news_helper.dart';
import '../widgets/search_app_bar.dart';
import '../widgets/news_tile.dart';

// SearchPage with null safety and integration hint
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  SearchPageState createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
  final TextEditingController searchInputController = TextEditingController();

  // Replace these with your actual data sources or API calls
  final List<Category> categories = CategoryHelper.categoryData;
  final List<News> searchData = NewsHelper.searchNews;

  @override
  void dispose() {
    searchInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: SearchAppBar(
          searchInputController: searchInputController,
          searchPressed: () {
            // TODO: Implement search action
          },
        ),
        body: ListView(
          shrinkWrap: true,
          children: [
            Container(
              alignment: Alignment.center,
              height: 60,
              color: Colors.black,
              child: ListView.separated(
                padding: const EdgeInsets.only(left: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  return OutlinedButton(
                    onPressed: () {
                      setState(() {
                        searchInputController.text = categories[index].name;
                        // You might want to trigger filtering here
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFF313131),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      categories[index].name,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: searchData.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder:
                    (context, index) => NewsTile(data: searchData[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}