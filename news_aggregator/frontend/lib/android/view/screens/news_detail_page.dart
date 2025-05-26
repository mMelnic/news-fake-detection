import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../model/news.dart';
import '../../services/article_service.dart';
import '../widgets/custom_app_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NewsDetailPage extends StatefulWidget {
  final News data;

  const NewsDetailPage({super.key, required this.data});

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  final String defaultImageUrl = 'https://raw.githubusercontent.com/mMelnic/news-fake-detection/refs/heads/users/news_aggregator/newspaper_beige.jpg';
  
  // Social interaction states
  int likeCount = 0;
  int commentCount = 0;
  bool isLiked = false;
  bool isSaved = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSocialData();
  }
  
  Future<void> _loadSocialData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      // Fetch social data in parallel
      final results = await Future.wait([
        ArticleService.getLikeCount(widget.data.id),
        ArticleService.getArticleComments(widget.data.id),
        ArticleService.isArticleLiked(widget.data.id),
        ArticleService.isArticleSaved(widget.data.id),
      ]);
      
      setState(() {
        likeCount = results[0] as int;
        commentCount = (results[1] as List).length;
        isLiked = results[2] as bool;
        isSaved = results[3] as bool;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading social data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        leadingIcon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressedLeading: () => Navigator.of(context).pop(),
        title: Text(
          widget.data.sourceName,
          style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 16, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // Like functionality (view only)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Like functionality coming soon!')),
              );
            },
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: () {
              // Save functionality (view only)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Save functionality coming soon!')),
              );
            },
            icon: SvgPicture.asset(
              isSaved ? 'assets/icons/Bookmark_filled.svg' : 'assets/icons/Bookmark.svg',
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top image with efficient loading
            SizedBox(
              height: 250,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: widget.data.image.isNotEmpty ? widget.data.image : defaultImageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported, size: 50, color: Colors.white),
                ),
              ),
            ),

            // Article content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Warning banner for potentially fake news
                  if (widget.data.isFake)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This article has been flagged as potentially fake news. Please verify information from other sources.',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Title
                  Text(
                    widget.data.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Meta Info
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(widget.data.date),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        widget.data.author.isNotEmpty ? widget.data.author : 'Unknown',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  
                  // Category
                  if (widget.data.category.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        children: widget.data.category.split(',').map((category) {
                          return Chip(
                            label: Text(
                              category.trim(),
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ),
                  
                  const SizedBox(height: 16),

                  // Interaction stats with loading indicator
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey[300]!),
                              bottom: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              // Likes count
                              Row(
                                children: [
                                  Icon(
                                    isLiked ? Icons.favorite : Icons.favorite_border, 
                                    color: isLiked ? Colors.red : Colors.grey[600]
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$likeCount ${likeCount == 1 ? 'like' : 'likes'}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              // Comments count
                              Row(
                                children: [
                                  Icon(Icons.chat_bubble_outline, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$commentCount ${commentCount == 1 ? 'comment' : 'comments'}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              // Saved/Bookmarked status
                              Row(
                                children: [
                                  Icon(
                                    isSaved ? Icons.bookmark : Icons.bookmark_border, 
                                    color: isSaved ? Colors.blue : Colors.grey[600]
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isSaved ? 'Saved' : 'Save',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                  
                  const SizedBox(height: 20),

                  // Source link
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Original Source',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                              Text(
                                widget.data.sourceUrl,
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // Article content
                  Text(
                    widget.data.content,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Sentiment indicator
                  _buildSentimentIndicator(widget.data.sentiment),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSentimentIndicator(String sentiment) {
    IconData icon;
    String label;
    Color color;
    
    switch (sentiment.toLowerCase()) {
      case 'positive':
        icon = Icons.sentiment_very_satisfied;
        label = 'Positive';
        color = Colors.green;
        break;
      case 'negative':
        icon = Icons.sentiment_very_dissatisfied;
        label = 'Negative';
        color = Colors.red;
        break;
      case 'neutral':
      default:
        icon = Icons.sentiment_neutral;
        label = 'Neutral';
        color = Colors.amber;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 6),
          Text(
            'Article Sentiment: $label',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}