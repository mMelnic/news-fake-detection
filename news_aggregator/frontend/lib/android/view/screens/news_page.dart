import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend/android/model/news.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  
  // Fixed categories that always appear
  final List<String> _fixedCategories = ['All categories', 'News', 'Food', 'Sports', 'Fashion'];
  
  // All categories (fixed + selected optional ones)
  List<String> _displayedCategories = [];
  
  // Selected optional categories
  Map<String, bool> _selectedCategories = {};
  
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
    
    // Initialize with fixed categories
    _displayedCategories = List.from(_fixedCategories);
    _categoryTabController = TabController(length: _displayedCategories.length, vsync: this);
    _categoryTabController.addListener(_handleTabChange);
    
    // Initialize maps for each category
    _initializeCategoryMaps(_displayedCategories);
    
    // Load saved category preferences
    _loadCategoryPreferences().then((_) {
      // Fetch all available categories and then load initial articles
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
  
  // Load saved category preferences from SharedPreferences
  Future<void> _loadCategoryPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get all saved preferences
    final Set<String> keys = prefs.getKeys();
    Map<String, bool> selectedCategories = {};
    
    // Filter for category preferences
    for (var key in keys) {
      if (key.startsWith('category_')) {
        final String category = key.substring(9); // Remove 'category_' prefix
        final bool isSelected = prefs.getBool(key) ?? false;
        
        // Skip fixed categories
        if (!_fixedCategories.contains(category)) {
          selectedCategories[category] = isSelected;
        }
      }
    }
    
    // Update selected categories
    setState(() {
      _selectedCategories = selectedCategories;
    });
    
    // Update displayed categories based on selected ones
    _updateDisplayedCategories();
  }
  
  // Update the NewsPage when category selections change in the drawer
  void updateSelectedCategories(Map<String, bool> categories) {
    setState(() {
      _selectedCategories = categories;
    });
    
    // Update displayed categories based on the new selection
    _updateDisplayedCategories();
  }
  
  // Update the displayed categories based on fixed and selected ones
  void _updateDisplayedCategories() {
    // Create a new list with fixed categories
    List<String> newDisplayedCategories = List.from(_fixedCategories);
    
    // Add selected optional categories
    _selectedCategories.forEach((category, isSelected) {
      if (isSelected && !newDisplayedCategories.contains(category)) {
        // Capitalize first letter of the category
        String formattedCategory = category.isNotEmpty 
            ? category[0].toUpperCase() + category.substring(1) 
            : category;
        newDisplayedCategories.add(formattedCategory);
      }
    });
    
    // Check if categories have changed
    if (_displayedCategories.length != newDisplayedCategories.length ||
        !_displayedCategories.every((category) => newDisplayedCategories.contains(category))) {
      
      // Update displayed categories
      setState(() {
        _displayedCategories = newDisplayedCategories;
      });
      
      // Initialize maps for new categories
      _initializeCategoryMaps(newDisplayedCategories);
      
      // Create new tab controller with updated length
      int currentTabIndex = _categoryTabController.index;
      currentTabIndex = currentTabIndex.clamp(0, newDisplayedCategories.length - 1);
      
      _categoryTabController.dispose();
      _categoryTabController = TabController(
        length: newDisplayedCategories.length, 
        vsync: this,
        initialIndex: currentTabIndex,
      );
      _categoryTabController.addListener(_handleTabChange);
      
      // Load articles for the current tab
      _loadArticlesForCurrentCategory();
    }
  }
  
  Future<void> _fetchCategories() async {
    try {
      // Get all available categories from the API
      final backendCategories = await ArticleService.fetchCategories();
      
      // No need to update fixed categories, just store them for potential selection
      setState(() {
        // Initialize empty map if needed
        if (_selectedCategories.isEmpty) {
          for (var category in backendCategories) {
            // Skip fixed categories
            if (!_fixedCategories.contains(category)) {
              _selectedCategories[category] = false;
            }
          }
        }
      });
      
      // Update displayed categories based on selections
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
      
      // Reset pagination for all categories
      for (var category in _displayedCategories) {
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
