import 'package:flutter/material.dart';

class NewsFilterSheet extends StatefulWidget {
  final Function(String)? onSortSelected;

  const NewsFilterSheet({super.key, this.onSortSelected});

  @override
  State<NewsFilterSheet> createState() => _NewsFilterSheetState();
}

class _NewsFilterSheetState extends State<NewsFilterSheet> {
  int _selectedIndex = 0;

  final List<String> _options = [
    'Newest',
    'Oldest',
    'Popular',
    'Recommendation',
    'Random',
  ];

  void _selectOption(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Call the callback with the selected option
    widget.onSortSelected?.call(_options[index]);

    Navigator.of(context).pop(); // Close sheet after selection
  }

  void _resetSelection() {
    setState(() {
      _selectedIndex = 0;
    });

    // Call the callback with the default option
    widget.onSortSelected?.call(_options[0]);

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height / 1.9;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView.builder(
              itemCount: _options.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedIndex == index;
                return _buildFilterOptionTile(
                  title: _options[index],
                  selected: isSelected,
                  onTap: () => _selectOption(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _headerButton('Reset', _resetSelection),
          const Text(
            'Sort by',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
          ),
          _headerButton('Cancel', () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _headerButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        height: 50,
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _buildFilterOptionTile({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          if (selected) const Icon(Icons.check, color: Colors.black),
        ],
      ),
      onTap: onTap,
    );
  }
}