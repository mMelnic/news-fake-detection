import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend/android/model/news.dart';
import '../../model/news_helper.dart';
import '../../route/slide_page_route.dart';
import '../../services/article_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/news_card.dart';
import '../widgets/news_filter_sheet.dart';
import 'news_detail_page.dart';

class NewsPage extends StatefulWidget {
  final Function? openDrawer;
  
  const NewsPage({super.key, this.openDrawer});

  @override
  NewsPageState createState() => NewsPageState();
}

class NewsPageState extends State<NewsPage> with TickerProviderStateMixin {
  late TabController _categoryTabController;
  
  // Default categories
  List<String> _categories = ['All categories', 'News', 'Food', 'Sports', 'Fashion'];
  
  // Store articles for each category
  Map<String, List<News>> _categoryArticles = {};
  
  // Loading state for each category
  Map<String, bool> _loadingStates = {};
  
  // Track if there are more articles to load
  Map<String, bool> _hasMoreArticles = {};
  
  // Current page for each category
  Map<String, int> _currentPage = {};
  
  // Current sort option
  String _currentSort = 'newest';

  @override
  void initState() {
    super.initState();
    _categoryTabController = TabController(length: _categories.length, vsync: this);
    _categoryTabController.addListener(_handleTabChange);
    
    // Initialize for each category
    for (var category in _categories) {
      _categoryArticles[category] = [];
      _loadingStates[category] = false;
      _hasMoreArticles[category] = true;
      _currentPage[category] = 1;
    }
    
    // Fetch categories and then load initial articles
    _fetchCategories().then((_) => _loadArticlesForCurrentCategory());
  }
  
  Future<void> _fetchCategories() async {
    try {
      // We'll keep the default categories but add any from the backend that are missing
      final backendCategories = await ArticleService.fetchCategories();
      
      // Add any categories from backend that aren't in our default list
      for (var category in backendCategories) {
        if (!_categories.contains(category)) {
          _categories.add(category);
          _categoryArticles[category] = [];
          _loadingStates[category] = false;
          _hasMoreArticles[category] = true;
          _currentPage[category] = 1;
        }
      }
      
      // Update tab controller if we added new categories
      if (_categories.length > _categoryTabController.length) {
        setState(() {
          _categoryTabController = TabController(
            length: _categories.length, 
            vsync: this,
            initialIndex: _categoryTabController.index
          );
          _categoryTabController.addListener(_handleTabChange);
        });
      }
    } catch (e) {
      // Keep default categories if there's an error
      print('Error fetching categories: $e');
    }
  }
  
  void _handleTabChange() {
    if (_categoryTabController.indexIsChanging) {
      return;
    }
    _loadArticlesForCurrentCategory();
  }
  
  Future<void> _loadArticlesForCurrentCategory() async {
    final currentCategory = _categories[_categoryTabController.index];
    
    // Don't load if already loading or no more articles
    if (_loadingStates[currentCategory]! || !_hasMoreArticles[currentCategory]!) {
      return;
    }
    
    setState(() {
      _loadingStates[currentCategory] = true;
    });
    
    try {
      final result = await ArticleService.fetchArticlesByCategory(
        category: currentCategory,
        page: _currentPage[currentCategory]!,
        pageSize: 10,
        sort: _currentSort,
      );
      
      setState(() {
        if (_currentPage[currentCategory] == 1) {
          // Replace articles if it's the first page
          _categoryArticles[currentCategory] = result['articles'];
        } else {
          // Append articles if it's not the first page
          _categoryArticles[currentCategory]!.addAll(result['articles']);
        }
        
        _hasMoreArticles[currentCategory] = result['hasMore'];
        _currentPage[currentCategory] = result['page'] + 1;
        _loadingStates[currentCategory] = false;
      });
    } catch (e) {
      print('Error loading articles: $e');
      setState(() {
        _loadingStates[currentCategory] = false;
      });
    }
  }
  
  void _onSortChanged(String sort) {
    setState(() {
      _currentSort = sort;
      
      // Reset pagination for all categories
      for (var category in _categories) {
        _categoryArticles[category] = [];
        _hasMoreArticles[category] = true;
        _currentPage[category] = 1;
      }
    });
    
    // Load articles with new sort
    _loadArticlesForCurrentCategory();
  }

  @override
  void dispose() {
    _categoryTabController.removeListener(_handleTabChange);
    _categoryTabController.dispose();
    super.dispose();
  }

  void showFilter() {
    showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return NewsFilterSheet(
          onSortSelected: (sort) {
            // Skip recommendation as requested
            if (sort != 'Recommendation') {
              String apiSort;
              switch (sort) {
                case 'Newest':
                  apiSort = 'newest';
                  break;
                case 'Oldest':
                  apiSort = 'oldest';
                  break;
                case 'Popular':
                  apiSort = 'popular';
                  break;
                case 'Random':
                  apiSort = 'random';
                  break;
                default:
                  apiSort = 'newest';
              }
              _onSortChanged(apiSort);
            }
          },
        );
      },
    );
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
          'News',
          style: TextStyle(fontWeight: FontWeight.w400, fontSize: 16, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: showFilter,
            icon: const Icon(Icons.sort_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            isScrollable: true,
            controller: _categoryTabController,
            labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            labelColor: Colors.black,
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            unselectedLabelColor: Colors.black.withOpacity(0.6),
            indicatorColor: Colors.transparent,
            tabs: _categories.map((category) => Tab(text: category)).toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _categoryTabController,
              children: _categories.map((category) {
                return _buildCategoryArticles(category);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryArticles(String category) {
    final articles = _categoryArticles[category] ?? [];
    final isLoading = _loadingStates[category] ?? false;
    final hasMore = _hasMoreArticles[category] ?? true;
    
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent &&
            !isLoading &&
            hasMore) {
          _loadArticlesForCurrentCategory();
        }
        return false;
      },
      child: articles.isEmpty && isLoading
          ? const Center(child: CircularProgressIndicator())
          : articles.isEmpty
              ? const Center(child: Text('No articles found'))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: NewsCard.itemWidth / NewsCard.itemHeight,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: articles.length + (isLoading && hasMore ? 1 : 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemBuilder: (context, index) {
                    if (index == articles.length) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final article = articles[index];
                    final showCategoryTag = category == 'All categories';
                    
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          SlidePageRoute(
                            child: NewsDetailPage(data: article),
                          ),
                        );
                      },
                      child: NewsCard(
                        data: article,
                        showCategoryTag: showCategoryTag,
                      ),
                    );
                  },
                ),
    );
  }
}
