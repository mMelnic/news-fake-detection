import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Adapted SearchAppBar with null safety and cleaner code
class SearchAppBar extends StatefulWidget implements PreferredSizeWidget {
  final TextEditingController searchInputController;
  final VoidCallback? searchPressed;

  const SearchAppBar({
    super.key,
    required this.searchInputController,
    this.searchPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  SearchAppBarState createState() => SearchAppBarState();
}

class SearchAppBarState extends State<SearchAppBar> {
  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.searchInputController.text.isEmpty;

    return AppBar(
      backgroundColor: Colors.black,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Container(
        margin: const EdgeInsets.only(left: 16, right: 10),
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(5),
        ),
        child: TextField(
          controller: widget.searchInputController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1,
          decoration: InputDecoration(
            prefixIcon: Visibility(
              visible: isEmpty,
              child: Container(
                margin: const EdgeInsets.only(left: 10, right: 12),
                child: SvgPicture.asset(
                  'assets/icons/Search.svg',
                  color: Colors.white,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(maxHeight: 20),
            hintText: 'Search...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
            contentPadding: const EdgeInsets.only(left: 16, bottom: 9),
            focusColor: Colors.white,
            border: InputBorder.none,
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed:
              isEmpty ? () => Navigator.pop(context) : widget.searchPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            textStyle: const TextStyle(fontWeight: FontWeight.w400),
          ),
          child: Text(isEmpty ? 'Cancel' : 'Search'),
        ),
      ],
    );
  }
}
