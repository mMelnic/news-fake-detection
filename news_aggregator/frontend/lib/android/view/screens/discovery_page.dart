import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../model/news.dart';
import '../../services/article_service.dart';
import '../../route/slide_page_route.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/news_card.dart';
import 'search_page.dart';
import 'news_detail_page.dart';

class DiscoverPage extends StatefulWidget {
  final Function? openDrawer;

  const DiscoverPage({super.key, this.openDrawer});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  List<News> _articles = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final ScrollController _scrollController = ScrollController();
  
  int _page = 1;
  final int _pageSize = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadArticles();
    
    // Add scroll listener for pagination
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollListener() {
    // Check if we're near the bottom of the list
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // Load more articles if we're not already loading and there are more to load
      if (!_isLoading && _hasMore) {
        _loadMoreArticles();
      }
    }
  }

  Future<void> _loadArticles() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      // Get articles with null categories from API
      final articlesData = await ArticleService.getArticlesWithNullCategory(
        page: _page,
        pageSize: _pageSize,
      );
      
      setState(() {
        _articles = articlesData.articles;
        _hasMore = articlesData.hasMore;
        _isLoading = false;
        _page = 2; // Next page to load
      });
      
      // Debug info
      print('Loaded ${articlesData.articles.length} articles with null category');
      print('Has more: ${articlesData.hasMore}');
      print('Total count: ${articlesData.totalCount}');
      
    } catch (e) {
      print('Error loading null category articles: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load articles: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadMoreArticles() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final articlesData = await ArticleService.getArticlesWithNullCategory(
        page: _page,
        pageSize: _pageSize,
      );
      
      setState(() {
        _articles.addAll(articlesData.articles);
        _hasMore = articlesData.hasMore;
        _isLoading = false;
        _page++; // Increment page for next load
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load more articles: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshArticles() async {
    setState(() {
      _page = 1;
      _hasMore = true;
    });
    
    await _loadArticles();
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
      body: RefreshIndicator(
        onRefresh: _refreshArticles,
        child: _buildBody(),
      ),
    );
  }
  
  Widget _buildBody() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshArticles,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_isLoading && _articles.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No articles found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshArticles,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      controller: _scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        mainAxisSpacing: 16,
        crossAxisSpacing: 10,
      ),
      itemCount: _articles.length + (_hasMore ? 1 : 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        // Show loading indicator at the end if there are more items
        if (index == _articles.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        final article = _articles[index];
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
            showCategoryTag: false, // No need to show category since it's null
          ),
        );
      },
    );
  }
}
