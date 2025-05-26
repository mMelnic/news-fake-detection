import 'package:flutter/material.dart';
import 'package:frontend/android/view/screens/news_page.dart';
import 'package:frontend/android/view/screens/user_profile.dart';
import '../widgets/custom_bottom_navigation_bar.dart';
import 'discovery_page.dart';
import 'drawer_controller.dart';

class PageSwitchWithAnimation extends StatefulWidget {
  const PageSwitchWithAnimation({super.key});

  @override
  State<PageSwitchWithAnimation> createState() =>
      _PageSwitchWithAnimationState();
}

class _PageSwitchWithAnimationState extends State<PageSwitchWithAnimation> {
  int _selectedIndex = 0;
  late final PageController _pageSwitchController;
  final GlobalKey<DrawerUserControllerState> _drawerControllerKey = GlobalKey<DrawerUserControllerState>();

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

  void openDrawer() {
    _drawerControllerKey.currentState?.onDrawerClick();
  }

  @override
  Widget build(BuildContext context) {
    return DrawerUserController(
      key: _drawerControllerKey,
      screenView: Scaffold(
        body: PageView(
          controller: _pageSwitchController,
          onPageChanged: (index) => setState(() => _selectedIndex = index),
          children: [
            NewsPage(openDrawer: openDrawer),
            DiscoverPage(openDrawer: openDrawer),
            const CombinedProfilePage()
          ],
        ),
        bottomNavigationBar: CustomBottomNavigationBar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }
}