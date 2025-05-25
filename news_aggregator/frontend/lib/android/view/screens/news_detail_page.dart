import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../model/news.dart';
import '../widgets/custom_app_bar.dart';

class NewsDetailPage extends StatelessWidget {
  final News data;

  const NewsDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        leadingIcon: Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressedLeading: () => Navigator.of(context).pop(),
        title: SvgPicture.asset('assets/icons/appname.svg'),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Implement share logic
            },
            icon: Icon(
              Icons.share_outlined,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: Implement bookmark toggle
            },
            icon: SvgPicture.asset(
              'assets/icons/Bookmark.svg',
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: 240,
            decoration: BoxDecoration(
              color: Colors.grey,
              image: DecorationImage(
                image: AssetImage(data.photo),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.date} | ${data.author}.',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    fontFamily: 'inter',
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  data.description,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.8),
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
