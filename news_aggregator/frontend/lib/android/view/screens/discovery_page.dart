import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../model/news.dart';
import '../../model/news_helper.dart';
import '../../route/slide_page_route.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/news_tile.dart';
import 'search_page.dart';

class DiscoverPage extends StatefulWidget {
  final Function? openDrawer;

  const DiscoverPage({super.key, this.openDrawer});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage>
    with TickerProviderStateMixin {
  late TabController _categoryTabController;

  final List<String> _categories = [
    'All categories',
    'Covid19',
    'International',
    'Europe',
    'American',
    'Asian',
    'Sports',
  ];

  final List<News> allCategoriesNews = NewsHelper.allCategoriesNews;

  @override
  void initState() {
    super.initState();
    _categoryTabController = TabController(
      length: _categories.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _categoryTabController.dispose();
    super.dispose();
  }

  void _changeTab(int index) {
    setState(() {
      _categoryTabController.index = index;
    });
  }

  // Filter news by category
  List<News> _filterNewsByCategory(String category) {
    if (category == 'All categories') return allCategoriesNews;
    return allCategoriesNews
        .where(
          (news) => news.title.toLowerCase().contains(category.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        leadingIcon: SvgPicture.asset(
          'assets/icons/Menu.svg',
          color: Colors.white,
        ),
        onPressedLeading: () {
          widget.openDrawer?.call();
        },
        title: const Text(
          'Discover',
          style: TextStyle(fontWeight: FontWeight.w400, fontSize: 16, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                SlidePageRoute(
                  child: const SearchPage(),
                  direction: AxisDirection.up,
                ),
              );
            },
            icon: SvgPicture.asset(
              'assets/icons/Search.svg',
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TabBar(
              isScrollable: true,
              controller: _categoryTabController,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'inter',
              ),
              labelColor: Colors.black,
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontFamily: 'inter',
              ),
              unselectedLabelColor: Colors.black.withOpacity(0.6),
              indicatorColor: Colors.transparent,
              onTap: _changeTab,
              tabs: _categories.map((category) => Tab(text: category)).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _categoryTabController,
              children: _categories.map((category) {
                final filteredNews = _filterNewsByCategory(category);
                if (filteredNews.isEmpty) {
                  return Center(child: Text('No news for $category'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filteredNews.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, index) => NewsTile(data: filteredNews[index]),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
