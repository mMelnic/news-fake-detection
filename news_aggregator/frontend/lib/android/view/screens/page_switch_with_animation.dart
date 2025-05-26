import 'package:flutter/material.dart';
import 'package:frontend/android/view/screens/news_page.dart';
import '../widgets/custom_bottom_navigation_bar.dart';
import 'discovery_page.dart';

class PageSwitchWithAnimation extends StatefulWidget {
  const PageSwitchWithAnimation({super.key});

  @override
  State<PageSwitchWithAnimation> createState() =>
      _PageSwitchWithAnimationState();
}

class _PageSwitchWithAnimationState extends State<PageSwitchWithAnimation> {
  int _selectedIndex = 0;
  late final PageController _pageSwitchController;

  @override
  void initState() {
    super.initState();
    _pageSwitchController = PageController();
  }

  void _onItemTapped(int index) {
    _pageSwitchController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pageSwitchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageSwitchController,
        onPageChanged: (index) => setState(() => _selectedIndex = index),
        children: const [NewsPage(), DiscoverPage()],
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}