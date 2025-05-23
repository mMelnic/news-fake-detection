import 'package:flutter/material.dart';
import '../services/news_service.dart';
import '../services/websocket_service.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import 'article_detail_page.dart';
import 'dart:async';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  NewsPageState createState() => NewsPageState();
}

class NewsPageState extends State<NewsPage> {
  final NewsService _newsService = NewsService();
  final WebSocketService _webSocketService = WebSocketService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Article> _articles = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = "technology";
  String _language = "en";
  String? _country;
  Timer? _debounceTimer;
  
  // Connection status indicator
  bool _wsConnected = false;
  int _newArticlesCount = 0;
  
  @override
  void initState() {
    super.initState();
    _searchController.text = _searchQuery;
    _loadArticles();
    
    // Listen for WebSocket updates
    _webSocketService.articlesStream.listen((newArticles) {
      if (mounted) {
        int addedCount = 0;
        setState(() {
          // Check for duplicates before adding
          for (var articleData in newArticles) {
            if (!_articles.any((a) => a.id == articleData['id'])) {
              _articles.insert(0, Article.fromJson(articleData));
              addedCount++;
            }
          }
          
          // Update counter for notification banner
          if (addedCount > 0) {
            _newArticlesCount += addedCount;
          }
        });
      }
    });
    
    // Listen for connection status changes
    _webSocketService.connectionStream.listen((connected) {
      if (mounted) {
        setState(() {
          _wsConnected = connected;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    _webSocketService.dispose();
    super.dispose();
  }
  
  Future<void> _loadArticles({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      if (refresh) {
        _articles = [];
      }
    });
    
    try {
      final response = await _newsService.fetchArticles(
        query: _searchQuery,
        language: _language,
        country: _country,
        refresh: refresh,
      );
      
      setState(() {
        _articles = response.articles;
        _isLoading = false;
        _newArticlesCount = 0; // Reset counter when explicitly loading articles
      });
      
      // Connect to WebSocket if provided in the response
      if (response.websocketInfo?.useWebsocket == true) {
        _webSocketService.connect(response.websocketInfo!.websocketUrl);
      }
    } catch (e) {
      debugPrint('Error loading articles: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load articles: $e'))
      );
    }
  }
  
  void _handleSearch(String query) {
    // Debounce search to avoid too many requests
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != query && query.isNotEmpty) {
        setState(() {
          _searchQuery = query;
          _webSocketService.disconnect(); // Disconnect from previous WebSocket
        });
        _loadArticles(refresh: true);
      }
    });
  }
  
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchQuery = "technology"; // Default query
      _webSocketService.disconnect();
    });
    _loadArticles(refresh: true);
  }
  
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
    setState(() {
      _newArticlesCount = 0; // Reset counter
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search news...',
                  hintStyle: const TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: _clearSearch,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                autofocus: true,
                onSubmitted: _handleSearch,
                onChanged: (value) {
                  // ToDo: Live search as user types
                },
              )
            : const Text('News Feed'),
        actions: [
          // WebSocket connection indicator
          if (_wsConnected)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(Icons.wifi, color: Colors.green),
            ),
          if (!_wsConnected && !_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(Icons.wifi_off, color: Colors.red),
            ),
          // Search/close button
          IconButton(
            icon: Icon(_isSearching ? Icons.search_off : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.text = _searchQuery;
                }
              });
            },
          ),
          // Filter button
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadArticles(refresh: true),
        child: Column(
          children: [
            // New articles notification banner
            if (_newArticlesCount > 0)
              GestureDetector(
                onTap: _scrollToTop,
                child: Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      '$_newArticlesCount new article${_newArticlesCount > 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            
            // Search query display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Results for: "$_searchQuery"',
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_articles.length} articles',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            
            // Articles list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _articles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'No articles found for "$_searchQuery"',
                                style: const TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () => _loadArticles(refresh: true),
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _articles.length,
                          itemBuilder: (context, index) {
                            final article = _articles[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              child: ArticleCard(
                                article: article,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ArticleDetailPage(article: article),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    final formKey = GlobalKey<FormState>();
    String tempLanguage = _language;
    String? tempCountry = _country;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter News'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Language dropdown
              DropdownButtonFormField<String>(
                value: tempLanguage,
                decoration: const InputDecoration(
                  labelText: 'Language',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'es', child: Text('Spanish')),
                  DropdownMenuItem(value: 'fr', child: Text('French')),
                  DropdownMenuItem(value: 'de', child: Text('German')),
                  DropdownMenuItem(value: 'it', child: Text('Italian')),
                  DropdownMenuItem(value: 'ru', child: Text('Russian')),
                  // Add more languages as needed
                ],
                onChanged: (value) {
                  tempLanguage = value!;
                },
              ),
              const SizedBox(height: 16),
              
              // Country dropdown
              DropdownButtonFormField<String?>(
                value: tempCountry,
                decoration: const InputDecoration(
                  labelText: 'Country (Optional)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Countries')),
                  DropdownMenuItem(value: 'us', child: Text('United States')),
                  DropdownMenuItem(value: 'gb', child: Text('United Kingdom')),
                  DropdownMenuItem(value: 'ca', child: Text('Canada')),
                  DropdownMenuItem(value: 'au', child: Text('Australia')),
                  DropdownMenuItem(value: 'in', child: Text('India')),
                  // Add more countries as needed
                ],
                onChanged: (value) {
                  tempCountry = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (_language != tempLanguage || _country != tempCountry) {
                setState(() {
                  _language = tempLanguage;
                  _country = tempCountry;
                  _webSocketService.disconnect();
                });
                _loadArticles(refresh: true);
              }
            },
            child: const Text('APPLY'),
          ),
        ],
      ),
    );
  }
}