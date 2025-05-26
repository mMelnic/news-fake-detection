import 'package:flutter/material.dart';
import 'package:frontend/theme/app_theme.dart';

class HomeDrawer extends StatefulWidget {
  const HomeDrawer({super.key, this.iconAnimationController});

  final AnimationController? iconAnimationController;

  @override
  HomeDrawerState createState() => HomeDrawerState();
}

class HomeDrawerState extends State<HomeDrawer> {
  // Temporary category names and their checked state
  final Map<String, bool> categories = {
    'Category One': false,
    'Category Two': true,
    'Category Three': false,
    'Category Four': true,
    'Category Five': false,
  };

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

          // Divider below subtitle
          Divider(
            color: AppTheme.grey.withOpacity(0.6),
            thickness: 1,
            indent: 16,
            endIndent: 16,
          ),

          // List of categories with checkbox
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children:
                  categories.keys.map((category) {
                    return CheckboxListTile(
                      activeColor: Colors.blue,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        category,
                        style: TextStyle(
                          color:
                              isLightMode
                                  ? AppTheme.nearlyBlack
                                  : AppTheme.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      value: categories[category],
                      onChanged: (bool? value) {
                        setState(() {
                          categories[category] = value ?? false;
                        });
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