// filepath: c:\Users\moldo\Documents\Semester_6\new_clone\news-fake-detection\news_aggregator\frontend\lib\android\view\screens\collections_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../model/collection.dart';
import '../../model/news.dart';
import '../../services/user_profile_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/news_card.dart';
import '../../route/slide_page_route.dart';
import 'news_detail_page.dart';

class CollectionsPage extends StatefulWidget {
  final int initialCollectionIndex;
  final List<Collection> collections;

  const CollectionsPage({
    super.key,
    required this.collections,
    this.initialCollectionIndex = 0,
  });

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Map<int, List<News>> _collectionArticles = {};
  Map<int, bool> _loadingStates = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.collections.length,
      vsync: this,
      initialIndex: widget.initialCollectionIndex.clamp(
        0,
        widget.collections.length - 1,
      ),
    );
    _tabController.addListener(_handleTabChange);

    // Initialize loading states
    for (var collection in widget.collections) {
      _loadingStates[collection.id] = false;
      _collectionArticles[collection.id] = [];
    }

    // Load initial collection
    _loadArticlesForCurrentCollection();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }
    _loadArticlesForCurrentCollection();
  }

  Future<void> _loadArticlesForCurrentCollection() async {
    if (_tabController.index >= widget.collections.length) {
      return;
    }

    final currentCollection = widget.collections[_tabController.index];

    // Skip if already loaded or loading
    if (_loadingStates[currentCollection.id] == true ||
        (_collectionArticles[currentCollection.id]?.isNotEmpty ?? false)) {
      return;
    }

    setState(() {
      _loadingStates[currentCollection.id] = true;
    });

    try {
      // Fetch collection articles
      final articlesData = await UserProfileService.getCollectionArticles(
        currentCollection.id,
      );

      // Convert to News objects
      final articles =
          articlesData.map((article) {
            return News(
              id: article['id']?.toString() ?? '',
              title: article['title'] ?? '',
              content: article['content'] ?? '',
              image: article['image_url'] ?? '',
              author: article['author'] ?? 'Unknown',
              date:
                  DateTime.tryParse(article['published_date'] ?? '') ??
                  DateTime.now(),
              sourceUrl: article['url'] ?? '',
              sourceName: article['source'] ?? '',
              category: article['categories'] ?? '',
              isFake: article['is_fake'] ?? false,
              sentiment: article['sentiment'] ?? 'neutral',
            );
          }).toList();

      setState(() {
        _collectionArticles[currentCollection.id] = articles;
        _loadingStates[currentCollection.id] = false;
      });
    } catch (e) {
      print('Error loading collection articles: $e');
      setState(() {
        _loadingStates[currentCollection.id] = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load articles: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        leadingIcon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressedLeading: () => Navigator.of(context).pop(),
        title: const Text(
          'My Collections',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Tab bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            labelColor: Colors.black,
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            unselectedLabelColor: Colors.black.withOpacity(0.6),
            indicatorColor: Colors.blue,
            tabs:
                widget.collections.map((collection) {
                  return Tab(text: collection.name);
                }).toList(),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children:
                  widget.collections.map((collection) {
                    return _buildCollectionArticles(collection);
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionArticles(Collection collection) {
    final articles = _collectionArticles[collection.id] ?? [];
    final isLoading = _loadingStates[collection.id] ?? false;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No articles in "${collection.name}"',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Save some articles to see them here',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: NewsCard.itemWidth / NewsCard.itemHeight,
        mainAxisSpacing: 16,
        crossAxisSpacing: 10,
      ),
      itemCount: articles.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final article = articles[index];

        return GestureDetector(
          onTap: () {
            Navigator.of(context)
                .push(SlidePageRoute(child: NewsDetailPage(data: article)))
                .then((_) {
                  // Refresh collection when returning from detail page
                  _loadArticlesForCurrentCollection();
                });
          },
          child: NewsCard(data: article, showCategoryTag: true),
        );
      },
    );
  }
}
