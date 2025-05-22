import 'package:flutter/material.dart';
import '../models/article.dart';
import '../screens/article_webview_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/social_service.dart';
import '../models/comment.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';
import '../screens/profile_edit_page.dart';

class ArticleDetailPage extends StatefulWidget {
  final Article article;
  
  const ArticleDetailPage({super.key, required this.article});
  
  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  final SocialService _socialService = SocialService();
  final UserService _userService = UserService();
  
  bool _isLiked = false;
  int _likeCount = 0;
  List<Comment> _comments = [];
  bool _isLoadingComments = true;
  bool _isSubmittingComment = false;
  final TextEditingController _commentController = TextEditingController();
  UserProfile? _userProfile;
  
  @override
  void initState() {
    super.initState();
    _loadSocialData();
    _loadUserProfile();
  }
  
  Future<void> _loadSocialData() async {
    try {
      // Convert id to string for API calls
      final articleIdString = widget.article.id.toString();
      
      // Get like status
      _isLiked = await _socialService.isArticleLiked(articleIdString);
      
      // Get like count
      _likeCount = await _socialService.getArticleLikeCount(articleIdString);
      
      // Get comments
      _comments = await _socialService.getArticleComments(articleIdString);
      
      setState(() {
        _isLoadingComments = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingComments = false;
      });
      debugPrint('Error loading social data: $e');
    }
  }
  
  Future<void> _loadUserProfile() async {
    try {
      final profile = await _userService.getCurrentUserProfile();
      setState(() {
        _userProfile = profile;
      });
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }
  
  Future<void> _toggleLike() async {
    try {
      final articleIdString = widget.article.id.toString();
      final success = await _socialService.toggleLike(articleIdString);
      
      if (success) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to like article: $e')),
      );
    }
  }
  
  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    // Check if user has a profile set up
    if (_userProfile?.displayName == null) {
      _showSetupProfileDialog();
      return;
    }
    
    setState(() {
      _isSubmittingComment = true;
    });
    
    try {
      final articleIdString = widget.article.id.toString();
      final comment = await _socialService.addComment(
        articleIdString,
        _commentController.text.trim(),
      );
      
      setState(() {
        _comments.insert(0, comment);
        _commentController.clear();
        _isSubmittingComment = false;
      });
    } catch (e) {
      setState(() {
        _isSubmittingComment = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post comment: $e')),
      );
    }
  }
  
  void _showSetupProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Up Your Profile'),
        content: const Text(
          'You need to set up your profile with a display name before commenting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileEditPage(),
                ),
              ).then((_) => _loadUserProfile());
            },
            child: const Text('SET UP PROFILE'),
          ),
        ],
      ),
    );
  }
  
  void _openWebView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleWebViewPage(article: widget.article),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.article.source, // Use the source directly as it's a string
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Article title
            Text(
              widget.article.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Article metadata
            Row(
              children: [
                Icon(Icons.source, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  widget.article.source, // Use the source directly
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatDate(widget.article.publishedDate), // Use publishedDate
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Article image
            if (widget.article.imageUrl != null) // Use imageUrl instead of urlToImage
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  widget.article.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, size: 48),
                    );
                  },
                ),
              ),
              
            const SizedBox(height: 16),
            
            // For fake news detection - show warning if needed
            if (widget.article.isFake == true)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This article may contain misleading information.',
                        style: TextStyle(color: Colors.red[800]),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Article content directly (no description needed with your model)
            Text(
              widget.article.content,
              style: const TextStyle(fontSize: 16),
            ),
            
            const SizedBox(height: 24),
            
            // Read article buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.web),
                    label: const Text('Read in App'),
                    onPressed: _openWebView,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open in Browser'),
                    onPressed: () => _launchUrl(widget.article.url),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            
            // Likes and Comments section
            const SizedBox(height: 24),
            const Divider(),
            
            // Like button and count
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : null,
                  ),
                  onPressed: _toggleLike,
                ),
                Text('$_likeCount ${_likeCount == 1 ? 'like' : 'likes'}'),
                const Spacer(),
                const Icon(Icons.comment),
                const SizedBox(width: 4),
                Text('${_comments.length} ${_comments.length == 1 ? 'comment' : 'comments'}'),
              ],
            ),
            
            const Divider(),
            
            // Comments section header
            const Text(
              'Comments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 8),
            
            // Add comment field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                _isSubmittingComment
                    ? const CircularProgressIndicator()
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _submitComment,
                      ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Comments list
            _isLoadingComments
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text('No comments yet'))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return CommentWidget(comment: comment);
                        },
                      ),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? "day" : "days"} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? "hour" : "hours"} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? "minute" : "minutes"} ago';
    } else {
      return 'Just now';
    }
  }
  
  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

// Comment widget
class CommentWidget extends StatelessWidget {
  final Comment comment;
  
  const CommentWidget({super.key, required this.comment});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
              const CircleAvatar(
                radius: 14,
                child: Icon(Icons.person, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  comment.author?.displayName ?? comment.author?.username ?? 'Anonymous',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (comment.createdAt != null)
                Text(
                  _formatCommentDate(comment.createdAt!),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.content),
        ],
      ),
    );
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
}