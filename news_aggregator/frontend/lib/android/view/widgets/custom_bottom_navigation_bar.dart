import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend/theme/app_theme.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const CustomBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      backgroundColor: Colors.white,
      currentIndex: selectedIndex,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      onTap: onItemTapped,
      items: [
        _buildNavItem(isSelected: selectedIndex == 0, icon: 'Home'),
        _buildNavItem(isSelected: selectedIndex == 1, icon: 'Search'),
        _buildNavItem(isSelected: selectedIndex == 2, icon: 'Profile'),
      ],
    );
  }

  BottomNavigationBarItem _buildNavItem({
    required bool isSelected,
    required String icon,
  }) {
    final String assetName =
        isSelected
            ? 'assets/icons/${icon}-filled.svg'
            : 'assets/icons/${icon}.svg';

    return BottomNavigationBarItem(
      icon: SvgPicture.asset(assetName),
      label: icon,
    );
  }
}