import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/news.dart';
import '../../services/article_service.dart';
import '../../services/user_profile_service.dart';
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
  bool showComments = false;
  List<Map<String, dynamic>> comments = [];
  
  // Text controller for new comments
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSocialData();
  }
  
  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
        comments = List<Map<String, dynamic>>.from(results[1] as List);
        commentCount = comments.length;
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
  
  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) {
      return;
    }
    
    try {
      await ArticleService.addComment(widget.data.id, _commentController.text);
      _commentController.clear();
      // Reload comments
      _loadSocialData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment: $e')),
      );
    }
  }
  
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
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
              // Like functionality
              ArticleService.toggleLike(widget.data.id).then((_) {
                setState(() {
                  isLiked = !isLiked;
                  likeCount += isLiked ? 1 : -1;
                });
              }).catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to toggle like: $e')),
                );
              });
            },
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : Colors.white,
            ),
          ),
          IconButton(
            onPressed: () {
              // Save functionality
              _showSaveDialog();
            },
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: isSaved ? Colors.blue : Colors.white,
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
                              InkWell(
                                onTap: () {
                                  ArticleService.toggleLike(widget.data.id).then((_) {
                                    setState(() {
                                      isLiked = !isLiked;
                                      likeCount += isLiked ? 1 : -1;
                                    });
                                  }).catchError((e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to toggle like: $e')),
                                    );
                                  });
                                },
                                child: Row(
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
                              ),
                              // Comments count
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    showComments = !showComments;
                                  });
                                },
                                child: Row(
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
                              ),
                              // Saved/Bookmarked status
                              InkWell(
                                onTap: () {
                                  _showSaveDialog();
                                },
                                child: Row(
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
                              ),
                            ],
                          ),
                        ),
                  
                  const SizedBox(height: 20),

                  // Source link - Made clickable
                  GestureDetector(
                    onTap: () => _launchURL(widget.data.sourceUrl),
                    child: Container(
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
                                    decoration: TextDecoration.underline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.open_in_new, size: 16, color: Colors.blue[700]),
                        ],
                      ),
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
                  
                  const SizedBox(height: 30),
                  
                  // Comments section
                  if (showComments) ...[
                    const Divider(thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Comments ($commentCount)',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.expand_less),
                          onPressed: () {
                            setState(() {
                              showComments = false;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    // Comment input field
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(
                              hintText: 'Add a comment...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _addComment,
                          color: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Comments list
                    ...comments.map((comment) => _buildCommentItem(comment)).toList(),
                    
                    if (comments.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No comments yet. Be the first to comment!',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                  ] else ...[
                    // Show expand comments button
                    Center(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text('Show $commentCount comments'),
                        onPressed: () {
                          setState(() {
                            showComments = true;
                          });
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final username = comment['username'] ?? 'Anonymous';
    final content = comment['content'] ?? '';
    final timestamp = comment['created_at'] != null 
        ? DateTime.parse(comment['created_at'])
        : DateTime.now();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_circle, size: 20),
              const SizedBox(width: 8),
              Text(
                username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                _formatCommentDate(timestamp),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content),
        ],
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
  
  String _formatCommentDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
  
  void _showSaveDialog() async {
    String suggestedTopic = "";
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Classifying article topic..."),
          ],
        ),
      ),
    );
    
    try {
      // Get topic classification
      suggestedTopic = await ArticleService.classifyArticleTopic(widget.data.id);
      Navigator.pop(context); // Close loading dialog
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to classify article: $e')),
      );
      suggestedTopic = "Other"; // Default if classification fails
    }
    
    // Fetch existing collections
    List<Map<String, dynamic>> collections = [];
    try {
      collections = await UserProfileService.getSavedCollections();
    } catch (e) {
      print('Failed to load collections: $e');
    }
    
    // Show dialog to save article
    final TextEditingController newCollectionController = TextEditingController(text: suggestedTopic);
    bool useNewCollection = true;
    String selectedCollection = collections.isNotEmpty ? collections.first['name'] : "Favorites";
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Save Article'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('We suggest saving this to: "$suggestedTopic"'),
                    const SizedBox(height: 16),
                    
                    // Choose existing or new collection
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Use existing'),
                            value: false,
                            groupValue: useNewCollection,
                            onChanged: (value) {
                              setState(() {
                                useNewCollection = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Create new'),
                            value: true,
                            groupValue: useNewCollection,
                            onChanged: (value) {
                              setState(() {
                                useNewCollection = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    // Show appropriate input based on selection
                    useNewCollection
                        ? TextField(
                            controller: newCollectionController,
                            decoration: const InputDecoration(
                              labelText: 'Collection Name',
                              hintText: 'Enter collection name',
                            ),
                          )
                        : collections.isEmpty
                            ? const Text('No existing collections. Create a new one.')
                            : DropdownButtonFormField<String>(
                                value: selectedCollection,
                                decoration: const InputDecoration(
                                  labelText: 'Choose Collection',
                                ),
                                items: collections
                                    .map((c) => DropdownMenuItem<String>(
                                          value: c['name'],
                                          child: Text(c['name']),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedCollection = value!;
                                  });
                                },
                              ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    
                    final collectionName = useNewCollection
                        ? newCollectionController.text
                        : selectedCollection;
                    
                    if (collectionName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Collection name cannot be empty')),
                      );
                      return;
                    }
                    
                    try {
                      await ArticleService.toggleSaved(widget.data.id, collectionName);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Article saved to $collectionName')),
                      );
                      // Refresh the UI to show saved status
                      _loadSocialData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save article: $e')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}