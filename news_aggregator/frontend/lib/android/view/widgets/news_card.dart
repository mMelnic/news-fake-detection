import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../model/news.dart';
import 'tag_card.dart';

class NewsCard extends StatelessWidget {
  static const double itemWidth = 185;
  static const double itemHeight = 260;

  final News data;
  final bool showCategoryTag;
  final String defaultImageUrl =
      'https://raw.githubusercontent.com/mMelnic/news-fake-detection/refs/heads/users/news_aggregator/newspaper_beige.jpg';

  const NewsCard({Key? key, required this.data, this.showCategoryTag = false})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: itemWidth,
      height: itemHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cached image with tag overlay
          Stack(
            children: [
              // Image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
                child: CachedNetworkImage(
                  imageUrl: data.image.isNotEmpty ? data.image : defaultImageUrl,
                  width: itemWidth,
                  height: 140,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => Container(
                        width: itemWidth,
                        height: 140,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        width: itemWidth,
                        height: 140,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.white,
                        ),
                      ),
                ),
              ),
              
              // Category tags positioned at bottom left of image
              if (showCategoryTag && data.category.isNotEmpty)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: data.category
                        .split(',')
                        .take(1) // Only take the first category to avoid overcrowding
                        .map((cat) => TagCard(tagName: cat.trim()))
                        .toList(),
                  ),
                ),
            ],
          ),
          
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 6),

                // Author and date
                Text(
                  '${data.author.isNotEmpty ? data.author : "Unknown"} • ${_formatDate(data.date)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),

                const SizedBox(height: 4),

                // Fake news indicator
                if (data.isFake)
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: Colors.red[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Potentially fake',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }
}