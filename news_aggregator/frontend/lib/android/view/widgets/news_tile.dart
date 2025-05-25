import 'package:flutter/material.dart';
import '../../model/news.dart';
import '../../route/slide_page_route.dart';
import '../screens/news_detail_page.dart';

class NewsTile extends StatelessWidget {
  final News data;

  const NewsTile({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Connect your NewsDetailPage here:
        Navigator.of(
          context,
        ).push(SlidePageRoute(child: NewsDetailPage(data: data)));
      },
      child: Container(
        height: 84,
        width: MediaQuery.of(context).size.width,
        color: Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 84,
              width: 84,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(5),
                image: DecorationImage(
                  image: AssetImage(data.photo),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(width: 16),
            SizedBox(
              width: MediaQuery.of(context).size.width - 16 - 16 - 84,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      fontFamily: 'inter',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.description,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}