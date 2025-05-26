import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/app_theme.dart';

class SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController searchInputController;
  final VoidCallback? searchPressed;
  final ValueChanged<String>? onChanged;

  const SearchAppBar({
    super.key,
    required this.searchInputController,
    this.searchPressed,
    this.onChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.lightBrown,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: TextField(
        controller: searchInputController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search news...',
          hintStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
          suffix: searchInputController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.white70,
                    size: 16,
                  ),
                  onPressed: () {
                    searchInputController.clear();
                    if (onChanged != null) {
                      onChanged!('');
                    }
                  },
                )
              : null,
        ),
        onChanged: onChanged,
        onSubmitted: (_) => searchPressed?.call(),
        textInputAction: TextInputAction.search,
      ),
      actions: [
        IconButton(
          onPressed: searchPressed,
          icon: SvgPicture.asset(
            'assets/icons/Search.svg',
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
