import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend/android/model/news.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  
  final List<String> _fixedCategories = ['All categories', 'News', 'Food', 'Sports', 'Fashion'];
  
  // All categories (fixed + selected optional ones)
  List<String> _displayedCategories = [];
  
  Map<String, bool> _selectedCategories = {};
  
  // Store articles for each category
  Map<String, List<News>> _categoryArticles = {};
  
  Map<String, bool> _loadingStates = {};
  Map<String, bool> _hasMoreArticles = {};
  Map<String, int> _currentPage = {};
  
  String _currentSort = 'newest';

  @override
  void initState() {
    super.initState();
    
    _displayedCategories = List.from(_fixedCategories);
    _categoryTabController = TabController(length: _displayedCategories.length, vsync: this);
    _categoryTabController.addListener(_handleTabChange);
    
    _initializeCategoryMaps(_displayedCategories);
    
    _loadCategoryPreferences().then((_) {
      _fetchCategories().then((_) => _loadArticlesForCurrentCategory());
    });
  }
  
  void _initializeCategoryMaps(List<String> categories) {
    for (var category in categories) {
      _categoryArticles[category] = [];
      _loadingStates[category] = false;
      _hasMoreArticles[category] = true;
      _currentPage[category] = 1;
    }
  }
  
  Future<void> _loadCategoryPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    final Set<String> keys = prefs.getKeys();
    Map<String, bool> selectedCategories = {};
    
    for (var key in keys) {
      if (key.startsWith('category_')) {
        final String category = key.substring(9); // Remove 'category_' prefix
        final bool isSelected = prefs.getBool(key) ?? false;
        
        if (!_fixedCategories.contains(category)) {
          selectedCategories[category] = isSelected;
        }
      }
    }
    
    setState(() {
      _selectedCategories = selectedCategories;
    });
    
    // Update displayed categories based on selected ones
    _updateDisplayedCategories();
  }
  
  void updateSelectedCategories(Map<String, bool> categories) {
    setState(() {
      _selectedCategories = categories;
    });
    
    _updateDisplayedCategories();
  }
  
  void _updateDisplayedCategories() {
    List<String> newDisplayedCategories = List.from(_fixedCategories);
    _selectedCategories.forEach((category, isSelected) {
      if (isSelected && !newDisplayedCategories.contains(category)) {
        // Capitalize first letter of the category
        String formattedCategory = category.isNotEmpty 
            ? category[0].toUpperCase() + category.substring(1) 
            : category;
        newDisplayedCategories.add(formattedCategory);
      }
    });
    
    if (_displayedCategories.length != newDisplayedCategories.length ||
        !_displayedCategories.every((category) => newDisplayedCategories.contains(category))) {
      
      setState(() {
        _displayedCategories = newDisplayedCategories;
      });
      
      _initializeCategoryMaps(newDisplayedCategories);
      
      int currentTabIndex = _categoryTabController.index;
      currentTabIndex = currentTabIndex.clamp(0, newDisplayedCategories.length - 1);
      
      _categoryTabController.dispose();
      _categoryTabController = TabController(
        length: newDisplayedCategories.length, 
        vsync: this,
        initialIndex: currentTabIndex,
      );
      _categoryTabController.addListener(_handleTabChange);
      
      _loadArticlesForCurrentCategory();
    }
  }
  
  Future<void> _fetchCategories() async {
    try {
      final backendCategories = await ArticleService.fetchCategories();
      
      setState(() {
        if (_selectedCategories.isEmpty) {
          for (var category in backendCategories) {
            // Skip fixed categories
            if (!_fixedCategories.contains(category)) {
              _selectedCategories[category] = false;
            }
          }
        }
      });
      
      _updateDisplayedCategories();
    } catch (e) {
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
    if (_categoryTabController.index >= _displayedCategories.length) {
      return;
    }
    
    final currentCategory = _displayedCategories[_categoryTabController.index];
    
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
      
      for (var category in _displayedCategories) {
        _categoryArticles[category] = [];
        _hasMoreArticles[category] = true;
        _currentPage[category] = 1;
      }
    });
    
    _loadArticlesForCurrentCategory();
  }

  @override
  void dispose() {
    _categoryTabController.removeListener(_handleTabChange);
    _categoryTabController.dispose();
    super.dispose();
  }

  void showFilter() async {
    final isAuthenticated = await AuthService.checkAuthenticated();
    
    showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return NewsFilterSheet(
          isAuthenticated: isAuthenticated,
          onSortSelected: (sort) {
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
              case 'Recommendation':
                apiSort = 'recommendation';
                break;
              case 'Random':
                apiSort = 'random';
                break;
              default:
                apiSort = 'newest';
            }
            _onSortChanged(apiSort);
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
            tabs: _displayedCategories.map((category) => Tab(text: category)).toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _categoryTabController,
              children: _displayedCategories.map((category) {
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
                    childAspectRatio: 0.80,
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
