import 'package:flutter/material.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/article_service.dart';

class HomeDrawer extends StatefulWidget {
  const HomeDrawer({super.key, this.iconAnimationController, this.onCategorySelectionChanged});

  final AnimationController? iconAnimationController;
  final Function(Map<String, bool>)? onCategorySelectionChanged;

  @override
  HomeDrawerState createState() => HomeDrawerState();
}

class HomeDrawerState extends State<HomeDrawer> {
  // Fixed categories that cannot be toggled
  final List<String> fixedCategories = ['All categories', 'News', 'Food', 'Sports', 'Fashion'];
  
  // Dynamic categories and their checked state
  Map<String, bool> categories = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    
    try {
      // Fetch all available categories from the API
      final List<String> availableCategories = await ArticleService.fetchCategories();
      final Map<String, bool> newCategories = {};
      
      for (var category in availableCategories) {
        // Skip fixed categories that will always be shown
        if (fixedCategories.contains(category)) { //TODO: match case sensitivity
          continue;
        }
        
        final bool isSelected = prefs.getBool('category_$category') ?? false;
        newCategories[category] = isSelected;
      }
      
      setState(() {
        categories = newCategories;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading categories: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _toggleCategory(String category, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('category_$category', value);
    
    setState(() {
      categories[category] = value;
    });
    
    if (widget.onCategorySelectionChanged != null) {
      widget.onCategorySelectionChanged!(categories);
    }
  }

  @override
  Widget build(BuildContext context) {
    var brightness = MediaQuery.of(context).platformBrightness;
    bool isLightMode = brightness == Brightness.light;

    return Scaffold(
      backgroundColor: AppTheme.notWhite.withOpacity(0.5),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Title "Preferences"
          Container(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Text(
              'Preferences',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: isLightMode ? AppTheme.nearlyBlack : AppTheme.white,
              ),
            ),
          ),

          // Subtitle "Categories"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Categories',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isLightMode ? AppTheme.grey : AppTheme.nearlyWhite,
              ),
            ),
          ),

          // Fixed categories info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Default categories (always visible): ${fixedCategories.join(", ")}',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: isLightMode ? AppTheme.grey : AppTheme.nearlyWhite.withOpacity(0.7),
              ),
            ),
          ),

          // Divider below subtitle
          Divider(
            color: AppTheme.grey.withOpacity(0.6),
            thickness: 1,
            indent: 16,
            endIndent: 16,
          ),

          // Loading indicator if categories are being loaded
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),

          // List of categories with checkbox
          if (!isLoading)
            Expanded(
              child: categories.isEmpty
                  ? Center(
                      child: Text(
                        'No additional categories available',
                        style: TextStyle(
                          color: isLightMode ? AppTheme.grey : AppTheme.nearlyWhite,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: categories.keys.map((category) {
                        return CheckboxListTile(
                          activeColor: Colors.blue,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            category,
                            style: TextStyle(
                              color: isLightMode
                                  ? AppTheme.nearlyBlack
                                  : AppTheme.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          value: categories[category],
                          onChanged: (bool? value) {
                            _toggleCategory(category, value ?? false);
                          },
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      }).toList(),
                    ),
            ),
        ],
      ),
    );
  }
}