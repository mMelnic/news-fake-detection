import 'package:flutter/material.dart';
import '../models/article.dart';
import 'package:intl/intl.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;

  const ArticleCard({
    Key? key,
    required this.article,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
              SizedBox(
                height: 180,
                width: double.infinity,
                child: Image.network(
                  article.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, error, stackTrace) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.grey.shade400,
                      size: 50,
                    ),
                  ),
                  loadingBuilder: (ctx, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 180,
                      color: Colors.grey.shade100,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              
            // Content section
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  // Content preview
                  Text(
                    _cleanContent(article.content),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  // Article badges
                  Row(
                    children: [
                      // Source badge
                      _buildBadge(
                        context,
                        article.source,
                        color: Colors.blue.shade50,
                        textColor: Colors.blue.shade800,
                        icon: Icons.public,
                      ),
                      const SizedBox(width: 8),
                      
                      // Date badge
                      if (article.publishedDate != null)
                        _buildBadge(
                          context,
                          _formatDate(article.publishedDate!),
                          color: Colors.grey.shade100,
                          textColor: Colors.grey.shade800,
                          icon: Icons.access_time,
                        ),
                      const Spacer(),
                      
                      // Fake/Real badge if available
                      if (article.isFake != null)
                        _buildBadge(
                          context,
                          article.isFake! ? 'Fake' : 'Real',
                          color: article.isFake!
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          textColor: article.isFake!
                              ? Colors.red.shade800
                              : Colors.green.shade800,
                          icon: article.isFake!
                              ? Icons.warning_amber
                              : Icons.check_circle,
                        ),
                      const SizedBox(width: 8),
                      
                      // Sentiment badge if available
                      if (article.sentiment != null)
                        _buildBadge(
                          context,
                          article.sentiment!.capitalize(),
                          color: article.sentiment == 'positive'
                              ? Colors.green.shade50
                              : Colors.amber.shade50,
                          textColor: article.sentiment == 'positive'
                              ? Colors.green.shade800
                              : Colors.amber.shade800,
                          icon: article.sentiment == 'positive'
                              ? Icons.thumb_up
                              : Icons.thumb_down,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(
    BuildContext context,
    String text, {
    required Color color,
    required Color textColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _cleanContent(String content) {
    // Remove HTML tags if present
    return content.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }
}

// Extension to capitalize first letter of strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}