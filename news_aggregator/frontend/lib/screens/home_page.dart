import 'package:flutter/material.dart';
import 'news_feed_page.dart';
import 'news_page.dart';
import 'account_page.dart';
import '../theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _pages = [
    const NewsFeedPage(),
    const NewsPage(),
    const AccountPage(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppTheme.dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          height: 60,
          elevation: 0,
          backgroundColor: AppTheme.backgroundColor,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppTheme.primaryColor),
              label: 'Feed',
            ),
            const NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search, color: AppTheme.primaryColor),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.textSecondaryColor,
                    width: 1.5,
                  ),
                ),
                child: const CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.transparent,
                  child: Icon(
                    Icons.person_outline,
                    color: AppTheme.textPrimaryColor,
                    size: 16,
                  ),
                ),
              ),
              selectedIcon: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.storyRingGradient,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: AppTheme.backgroundColor,
                    child: const Icon(
                      Icons.person,
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                  ),
                ),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}