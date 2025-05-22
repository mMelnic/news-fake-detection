import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/news_service.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import 'article_detail_page.dart';
import 'user_preferences_screen.dart';
import 'dart:async';

class NewsFeedPage extends StatefulWidget {
  const NewsFeedPage({super.key});

  @override
  NewsFeedPageState createState() => NewsFeedPageState();
}

class NewsFeedPageState extends State<NewsFeedPage> {
  final NewsService _newsService = NewsService();
  final ScrollController _scrollController = ScrollController();
  
  Map<String, List<Article>> _topicArticles = {};
  List<String> _selectedTopics = [];
  String _language = 'en';
  String? _country;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }
  
  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final topics = prefs.getStringList('selectedTopics');
      
      // Check if topics are set - if not, navigate to preferences screen
      if (topics == null || topics.isEmpty) {
        _navigateToPreferencesSetup();
        return;
      }
      
      setState(() {
        _selectedTopics = topics;
        _language = prefs.getString('language') ?? 'en';
        _country = prefs.getString('country');
      });
      
      _loadAllTopics();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load preferences: $e';
        _isLoading = false;
      });
    }
  }
  
  void _navigateToPreferencesSetup() {
    // Navigate to preferences screen with isInitialSetup flag
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => const UserPreferencesScreen(isInitialSetup: true),
        ),
      ).then((_) => _loadUserPreferences());
    });
  }
  
  Future<void> _loadAllTopics() async {
    if (_selectedTopics.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    
    try {
      // Create a map to store articles by topic
      final Map<String, List<Article>> topicArticles = {};
      
      // Load articles for each topic in parallel
      final futures = _selectedTopics.map((topic) => _loadTopicArticles(topic));
      final results = await Future.wait(futures);
      
      // Combine results
      for (int i = 0; i < _selectedTopics.length; i++) {
        final topic = _selectedTopics[i];
        final articles = results[i];
        if (articles.isNotEmpty) {
          topicArticles[topic] = articles;
        }
      }
      
      if (mounted) {
        setState(() {
          _topicArticles = topicArticles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load articles: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  Future<List<Article>> _loadTopicArticles(String topic) async {
    try {
      final response = await _newsService.fetchArticles(
        query: topic,
        language: _language,
        country: _country,
        refresh: true,
      );
      
      return response.articles;
    } catch (e) {
      debugPrint('Error loading articles for topic $topic: $e');
      return [];
    }
  }
  
  List<Article> _getMixedArticles() {
    // Create a mixed list of articles from different topics
    final List<Article> mixedArticles = [];
    
    // Calculate how many articles to take from each topic
    final int topicCount = _topicArticles.keys.length;
    if (topicCount == 0) return [];
    
    // Determine max articles per topic to ensure even distribution
    int maxArticlesPerTopic = 100; // Start with a high number
    for (final articles in _topicArticles.values) {
      if (articles.length < maxArticlesPerTopic) {
        maxArticlesPerTopic = articles.length;
      }
    }
    
    // Collect articles in a round-robin fashion
    for (int i = 0; i < maxArticlesPerTopic; i++) {
      for (final topic in _topicArticles.keys) {
        final articles = _topicArticles[topic]!;
        if (i < articles.length) {
          mixedArticles.add(articles[i]);
        }
      }
    }
    
    return mixedArticles;
  }
  
  Future<void> _openPreferences() async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => const UserPreferencesScreen(),
      ),
    );
    
    if (result == true) {
      _loadUserPreferences();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('News Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _openPreferences,
            tooltip: 'Preferences',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllTopics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAllTopics,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAllTopics,
                  child: _buildArticleList(),
                ),
    );
  }
  
  Widget _buildArticleList() {
    final mixedArticles = _getMixedArticles();

    if (mixedArticles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No articles found'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAllTopics,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: mixedArticles.length,
      itemBuilder: (context, index) {
        final article = mixedArticles[index];
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
    );
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}