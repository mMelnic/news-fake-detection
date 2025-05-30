import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../model/news.dart';
import '../../services/search_service.dart';
import '../../services/user_profile_service.dart';
import '../widgets/search_app_bar.dart';
import '../widgets/news_tile.dart';
import 'news_detail_page.dart';
import '../../route/slide_page_route.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  SearchPageState createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
  final TextEditingController searchInputController = TextEditingController();
  
  bool _isLoading = false;
  bool _hasSearched = false;
  List<News> _searchResults = [];
  String _errorMessage = '';
  bool _isSearchingWithAnd = true; // Default to AND search
  
  // Common search categories for quick selection
  final List<String> _searchCategories = [
    'Technology',
    'Politics',
    'Business',
    'Health',
    'Science',
    'Sports',
    'Entertainment',
  ];
  
  String? _userLanguage;
  String? _userCountry;
  
  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }
  
  Future<void> _loadUserPreferences() async {
    try {
      final userProfile = await UserProfileService.getUserProfile();
      setState(() {
        _userLanguage = userProfile['preferred_language'];
        _userCountry = userProfile['country'];
      });
    } catch (e) {
      print('Failed to load user preferences: $e');
      // Continue without preferences
    }
  }

  @override
  void dispose() {
    searchInputController.dispose();
    super.dispose();
  }
  
  Future<void> _performSearch({bool isAndSearch = true}) async {
    final query = searchInputController.text.trim();
    if (query.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _isSearchingWithAnd = isAndSearch;
      _errorMessage = '';
    });
    
    try {
      final results = await SearchService.search(
        query: query, 
        language: _userLanguage, 
        country: _userCountry,
        mode: isAndSearch ? 'and' : 'or'
      );
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: $e';
        _isLoading = false;
      });
    }
  }
  
  void _selectCategory(String category) {
    setState(() {
      searchInputController.text = category;
    });
    _performSearch(isAndSearch: true);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: SearchAppBar(
          searchInputController: searchInputController,
          searchPressed: () => _performSearch(isAndSearch: _isSearchingWithAnd),
          onChanged: (value) {
            // Enable live search after 3 characters
            if (value.length > 2) {
              _performSearch(isAndSearch: _isSearchingWithAnd);
            }
          },
        ),
        body: Column(
          children: [
            // Search options row (AND/OR toggle)
            Container(
              color: AppTheme.lightBrown,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Search Mode:',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('AND'),
                    selected: _isSearchingWithAnd,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _isSearchingWithAnd = true;
                        });
                        if (_hasSearched) {
                          _performSearch(isAndSearch: true);
                        }
                      }
                    },
                    selectedColor: const Color.fromARGB(255, 182, 167, 138),
                    labelStyle: TextStyle(
                      color: _isSearchingWithAnd ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('OR'),
                    selected: !_isSearchingWithAnd,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _isSearchingWithAnd = false;
                        });
                        if (_hasSearched) {
                          _performSearch(isAndSearch: false);
                        }
                      }
                    },
                    selectedColor: const Color.fromARGB(255, 182, 167, 138),
                    labelStyle: TextStyle(
                      color: !_isSearchingWithAnd ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  if (_hasSearched)
                    Chip(
                      label: Text(
                        _searchResults.length.toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.blueGrey,
                    ),
                ],
              ),
            ),
            
            // Category chips
            Container(
              alignment: Alignment.center,
              height: 60,
              color: AppTheme.lightBrown,
              child: ListView.separated(
                padding: const EdgeInsets.only(left: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _searchCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return OutlinedButton(
                    onPressed: () => _selectCategory(_searchCategories[index]),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFF313131),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _searchCategories[index],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Search hint for empty state
            if (!_hasSearched)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Search for news articles',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use quotes for exact phrases: "climate change"',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Loading indicator
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            
            // Error message
            if (_errorMessage.isNotEmpty && !_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _performSearch(isAndSearch: _isSearchingWithAnd),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Search results
            if (_hasSearched && !_isLoading && _errorMessage.isEmpty)
              Expanded(
                child: _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try different keywords or search mode',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) => GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              SlidePageRoute(
                                child: NewsDetailPage(data: _searchResults[index]),
                              ),
                            );
                          },
                          child: NewsTile(data: _searchResults[index]),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}