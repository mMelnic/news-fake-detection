import 'package:flutter/material.dart';
import '../models/article.dart';
import '../theme/app_theme.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;

  const ArticleCard({
    super.key, 
    required this.article, 
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with source and timestamp
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.dividerColor,
                    foregroundColor: AppTheme.textPrimaryColor,
                    child: Text(
                      article.source.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.source,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (article.publishedDate != null)
                          Text(
                            _formatDate(article.publishedDate!),
                            style: const TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {},
                    iconSize: 20,
                  ),
                ],
              ),
            ),
            
            // Image
            if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor.withOpacity(0.3),
                  ),
                  child: Image.network(
                    article.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, error, stackTrace) => Container(
                      color: AppTheme.dividerColor.withOpacity(0.3),
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: AppTheme.textSecondaryColor,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Title and preview
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 6),
                  Text(
                    _cleanContent(article.content),
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Badges and interaction row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  // Badges row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (article.isFake != null)
                        _buildTrustBadge(article.isFake!),
                      if (article.sentiment != null)
                        _buildSentimentBadge(article.sentiment!),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Interaction row
                  Row(
                    children: [
                      _buildIconButton(Icons.favorite_border, Colors.black, ''),
                      const SizedBox(width: 16),
                      _buildIconButton(Icons.chat_bubble_outline, Colors.black, ''),
                      const SizedBox(width: 16),
                      _buildIconButton(Icons.share_outlined, Colors.black, ''),
                      const Spacer(),
                      _buildIconButton(Icons.bookmark_border, Colors.black, ''),
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

  Widget _buildTrustBadge(bool isFake) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isFake
            ? const Color(0xFFFEE2E2) // Light red
            : const Color(0xFFDCFCE7), // Light green
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFake ? Icons.warning_amber_rounded : Icons.check_circle,
            size: 14,
            color: isFake ? const Color(0xFFDC2626) : const Color(0xFF059669),
          ),
          const SizedBox(width: 4),
          Text(
            isFake ? 'Potentially Misleading' : 'Verified',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isFake ? const Color(0xFFDC2626) : const Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentBadge(String sentiment) {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String label;

    switch (sentiment.toLowerCase()) {
      case 'positive':
        backgroundColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF059669);
        icon = Icons.sentiment_satisfied;
        label = 'Positive';
        break;
      case 'negative':
        backgroundColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        icon = Icons.sentiment_dissatisfied;
        label = 'Negative';
        break;
      default:
        backgroundColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        icon = Icons.sentiment_neutral;
        label = 'Neutral';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, String count) {
    return Row(
      children: [
        Icon(icon, size: 22, color: color),
        if (count.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              count,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
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
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}