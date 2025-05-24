// import 'package:flutter/material.dart';
// import '../models/article.dart';
// import '../models/comment.dart';
// import '../models/user_profile.dart';
// import '../services/social_service.dart';
// import '../services/user_service.dart';
// import '../theme/app_theme.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'profile_edit_page.dart';

// class ArticleDetailPage extends StatefulWidget {
//   final Article article;
  
//   const ArticleDetailPage({super.key, required this.article});
  
//   @override
//   State<ArticleDetailPage> createState() => _ArticleDetailPageState();
// }

// class _ArticleDetailPageState extends State<ArticleDetailPage> {
//   final SocialService _socialService = SocialService();
//   final UserService _userService = UserService();
  
//   bool _isLiked = false;
//   int _likeCount = 0;
//   List<Comment> _comments = [];
//   bool _isLoadingComments = true;
//   bool _isSubmittingComment = false;
//   final TextEditingController _commentController = TextEditingController();
//   UserProfile? _userProfile;
  
//   @override
//   void initState() {
//     super.initState();
//     _loadSocialData();
//     _loadUserProfile();
//   }
  
//   Future<void> _loadSocialData() async {
//     try {
//       final articleIdString = widget.article.id.toString();
      
//       _isLiked = await _socialService.isArticleLiked(articleIdString);
//       _likeCount = await _socialService.getArticleLikeCount(articleIdString);
//       _comments = await _socialService.getArticleComments(articleIdString);
      
//       setState(() {
//         _isLoadingComments = false;
//       });
//     } catch (e) {
//       setState(() {
//         _isLoadingComments = false;
//       });
//       debugPrint('Error loading social data: $e');
//     }
//   }
  
//   Future<void> _loadUserProfile() async {
//     try {
//       final profile = await _userService.getCurrentUserProfile();
//       setState(() {
//         _userProfile = profile;
//       });
//     } catch (e) {
//       debugPrint('Error loading user profile: $e');
//     }
//   }
  
//   Future<void> _toggleLike() async {
//     try {
//       final articleIdString = widget.article.id.toString();
//       final success = await _socialService.toggleLike(articleIdString);
      
//       if (success) {
//         setState(() {
//           _isLiked = !_isLiked;
//           _likeCount += _isLiked ? 1 : -1;
//         });
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to like article: $e')),
//       );
//     }
//   }
  
//   Future<void> _submitComment() async {
//     if (_commentController.text.trim().isEmpty) return;
    
//     if (_userProfile?.displayName == null) {
//       _showSetupProfileDialog();
//       return;
//     }
    
//     setState(() {
//       _isSubmittingComment = true;
//     });
    
//     try {
//       final articleIdString = widget.article.id.toString();
//       final comment = await _socialService.addComment(
//         articleIdString,
//         _commentController.text.trim(),
//       );
      
//       setState(() {
//         _comments.insert(0, comment);
//         _commentController.clear();
//         _isSubmittingComment = false;
//       });
//     } catch (e) {
//       setState(() {
//         _isSubmittingComment = false;
//       });
      
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to post comment: $e')),
//       );
//     }
//   }
  
//   void _showSetupProfileDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Set Up Your Profile'),
//         content: const Text(
//           'You need to set up your profile with a display name before commenting.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('CANCEL'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => const ProfileEditPage(),
//                 ),
//               ).then((_) => _loadUserProfile());
//             },
//             child: const Text('SET UP PROFILE'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _launchUrl(String url) async {
//     try {
//       final Uri uri = Uri.parse(url);
//       if (await canLaunchUrl(uri)) {
//         await launchUrl(uri, mode: LaunchMode.externalApplication);
//       } else {
//         throw 'Could not launch $url';
//       }
//     } catch (e) {
//       debugPrint('Error launching URL: $e');
//     }
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppTheme.backgroundColor,
//       body: CustomScrollView(
//         slivers: [
//           SliverAppBar(
//             expandedHeight: widget.article.imageUrl != null ? 240.0 : 0.0,
//             pinned: true,
//             backgroundColor: AppTheme.backgroundColor,
//             elevation: 0,
//             leading: IconButton(
//               icon: Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Colors.black.withOpacity(0.4),
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
//               ),
//               onPressed: () => Navigator.pop(context),
//             ),
//             actions: [
//               IconButton(
//                 icon: Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.4),
//                     shape: BoxShape.circle,
//                   ),
//                   child: const Icon(Icons.share, color: Colors.white, size: 20),
//                 ),
//                 onPressed: () {},
//               ),
//               IconButton(
//                 icon: Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.4),
//                     shape: BoxShape.circle,
//                   ),
//                   child: const Icon(Icons.bookmark_border, color: Colors.white, size: 20),
//                 ),
//                 onPressed: () {},
//               ),
//             ],
//             flexibleSpace: FlexibleSpaceBar(
//               background: widget.article.imageUrl != null
//                   ? Image.network(
//                       widget.article.imageUrl!,
//                       fit: BoxFit.cover,
//                       errorBuilder: (context, error, stackTrace) {
//                         return Container(
//                           color: Colors.grey[300],
//                           child: const Icon(Icons.image_not_supported, size: 64),
//                         );
//                       },
//                     )
//                   : null,
//             ),
//           ),
//           SliverToBoxAdapter(
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Source & Date Row
//                   Row(
//                     children: [
//                       CircleAvatar(
//                         radius: 16,
//                         backgroundColor: AppTheme.dividerColor,
//                         foregroundColor: AppTheme.textPrimaryColor,
//                         child: Text(
//                           widget.article.source.substring(0, 1).toUpperCase(),
//                           style: const TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 14,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             widget.article.source,
//                             style: const TextStyle(
//                               fontWeight: FontWeight.w600,
//                               fontSize: 14,
//                             ),
//                           ),
//                           if (widget.article.publishedDate != null)
//                             Text(
//                               _formatDate(widget.article.publishedDate!),
//                               style: const TextStyle(
//                                 color: AppTheme.textSecondaryColor,
//                                 fontSize: 12,
//                               ),
//                             ),
//                         ],
//                       ),
//                     ],
//                   ),
                  
//                   const SizedBox(height: 16),
                  
//                   // Title
//                   Text(
//                     widget.article.title,
//                     style: const TextStyle(
//                       fontSize: 22,
//                       fontWeight: FontWeight.bold,
//                       height: 1.3,
//                     ),
//                   ),
                  
//                   const SizedBox(height: 16),
                  
//                   // Fake news warning
//                   if (widget.article.isFake == true)
//                     Container(
//                       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//                       margin: const EdgeInsets.only(bottom: 16),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFFFEE2E2),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Row(
//                         children: [
//                           const Icon(
//                             Icons.warning_amber_rounded,
//                             color: Color(0xFFDC2626),
//                           ),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 const Text(
//                                   'Potentially Misleading',
//                                   style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     color: Color(0xFFDC2626),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 2),
//                                 Text(
//                                   'This article may contain misleading information. Please verify from multiple sources.',
//                                   style: TextStyle(
//                                     color: Colors.red[800],
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
                  
//                   // Article content
//                   Text(
//                     widget.article.content,
//                     style: const TextStyle(
//                       fontSize: 16,
//                       height: 1.5,
//                     ),
//                   ),
                  
//                   const SizedBox(height: 24),
                  
//                   // Read full article button
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton.icon(
//                       icon: const Icon(Icons.open_in_browser),
//                       label: const Text('Read Full Article'),
//                       onPressed: () => _launchUrl(widget.article.url),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: AppTheme.primaryColor,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         padding: const EdgeInsets.symmetric(vertical: 12),
//                       ),
//                     ),
//                   ),
                  
//                   const SizedBox(height: 24),
                  
//                   // Interaction stats
//                   Container(
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                     decoration: BoxDecoration(
//                       border: Border(
//                         top: BorderSide(color: AppTheme.dividerColor),
//                         bottom: BorderSide(color: AppTheme.dividerColor),
//                       ),
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceAround,
//                       children: [
//                         _buildStatItem(
//                           icon: _isLiked
//                               ? Icons.favorite
//                               : Icons.favorite_border,
//                           color: _isLiked ? AppTheme.likeColor : null,
//                           count: _likeCount,
//                           label: _likeCount == 1 ? 'Like' : 'Likes',
//                           onTap: _toggleLike,
//                         ),
//                         _buildStatItem(
//                           icon: Icons.chat_bubble_outline,
//                           count: _comments.length,
//                           label: _comments.length == 1 ? 'Comment' : 'Comments',
//                           onTap: () {},
//                         ),
//                         _buildStatItem(
//                           icon: Icons.share,
//                           count: null,
//                           label: 'Share',
//                           onTap: () {},
//                         ),
//                       ],
//                     ),
//                   ),
                  
//                   const SizedBox(height: 24),
                  
//                   // Comments section title
//                   const Text(
//                     'Comments',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
                  
//                   const SizedBox(height: 16),
                  
//                   // Add comment field
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       CircleAvatar(
//                         radius: 18,
//                         backgroundColor: AppTheme.dividerColor,
//                         child: const Icon(Icons.person, color: AppTheme.textSecondaryColor),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: TextField(
//                           controller: _commentController,
//                           decoration: InputDecoration(
//                             hintText: 'Add a comment...',
//                             hintStyle: TextStyle(color: Colors.grey[500]),
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(24),
//                               borderSide: BorderSide.none,
//                             ),
//                             filled: true,
//                             fillColor: AppTheme.dividerColor.withOpacity(0.3),
//                             contentPadding: const EdgeInsets.symmetric(
//                               horizontal: 20,
//                               vertical: 10,
//                             ),
//                             suffixIcon: _isSubmittingComment
//                                 ? const Padding(
//                                     padding: EdgeInsets.all(8.0),
//                                     child: SizedBox(
//                                       height: 16,
//                                       width: 16,
//                                       child: CircularProgressIndicator(
//                                         strokeWidth: 2,
//                                         color: AppTheme.primaryColor,
//                                       ),
//                                     ),
//                                   )
//                                 : IconButton(
//                                     icon: const Icon(
//                                       Icons.send_rounded,
//                                       color: AppTheme.primaryColor,
//                                     ),
//                                     onPressed: _submitComment,
//                                   ),
//                           ),
//                           maxLines: null,
//                         ),
//                       ),
//                     ],
//                   ),
                  
//                   const SizedBox(height: 24),
                  
//                   // Comments list
//                   _isLoadingComments
//                       ? const Center(
//                           child: CircularProgressIndicator(
//                             color: AppTheme.primaryColor,
//                           ),
//                         )
//                       : _comments.isEmpty
//                           ? const Center(
//                               child: Text(
//                                 'No comments yet. Be the first!',
//                                 style: TextStyle(
//                                   color: AppTheme.textSecondaryColor,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             )
//                           : ListView.separated(
//                               shrinkWrap: true,
//                               physics: const NeverScrollableScrollPhysics(),
//                               itemCount: _comments.length,
//                               separatorBuilder: (_, __) => const Divider(height: 32),
//                               itemBuilder: (context, index) {
//                                 final comment = _comments[index];
//                                 return CommentWidget(comment: comment);
//                               },
//                             ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
  
//   Widget _buildStatItem({
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//     int? count,
//     Color? color,
//   }) {
//     return InkWell(
//       onTap: onTap,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//         child: Column(
//           children: [
//             Icon(icon, size: 22, color: color),
//             const SizedBox(height: 4),
//             Text(
//               count != null ? '$count $label' : label,
//               style: TextStyle(
//                 fontSize: 12,
//                 color: color ?? AppTheme.textSecondaryColor,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
  
//   String _formatDate(DateTime? date) {
//     if (date == null) return 'Unknown';
    
//     final now = DateTime.now();
//     final difference = now.difference(date);
    
//     if (difference.inDays > 7) {
//       return '${date.day}/${date.month}/${date.year}';
//     } else if (difference.inDays > 0) {
//       return '${difference.inDays}d ago';
//     } else if (difference.inHours > 0) {
//       return '${difference.inHours}h ago';
//     } else if (difference.inMinutes > 0) {
//       return '${difference.inMinutes}m ago';
//     } else {
//       return 'Just now';
//     }
//   }
  
//   @override
//   void dispose() {
//     _commentController.dispose();
//     super.dispose();
//   }
// }

// // Comment widget
// class CommentWidget extends StatelessWidget {
//   final Comment comment;
  
//   const CommentWidget({super.key, required this.comment});
  
//   @override
//   Widget build(BuildContext context) {
//     // Get the author's name, preferring displayName, falling back to username
//     final String authorName = comment.author?.displayName?.isNotEmpty == true 
//         ? comment.author!.displayName!
//         : (comment.author?.username ?? 'Anonymous');
        
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         CircleAvatar(
//           radius: 18,
//           backgroundColor: AppTheme.dividerColor,
//           child: const Icon(Icons.person, color: AppTheme.textSecondaryColor),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   Text(
//                     authorName,
//                     style: const TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   if (comment.createdAt != null)
//                     Text(
//                       _formatCommentDate(comment.createdAt!),
//                       style: const TextStyle(
//                         fontSize: 12,
//                         color: AppTheme.textSecondaryColor,
//                       ),
//                     ),
//                 ],
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 comment.content,
//                 style: const TextStyle(fontSize: 14),
//               ),
//               const SizedBox(height: 8),
//               Row(
//                 children: [
//                   _buildCommentAction('Like'),
//                   const SizedBox(width: 16),
//                   _buildCommentAction('Reply'),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
  
//   Widget _buildCommentAction(String label) {
//     return Text(
//       label,
//       style: const TextStyle(
//         fontWeight: FontWeight.bold,
//         fontSize: 12,
//         color: AppTheme.textSecondaryColor,
//       ),
//     );
//   }
  
//   String _formatCommentDate(DateTime date) {
//     final now = DateTime.now();
//     final difference = now.difference(date);
    
//     if (difference.inDays > 7) {
//       return '${date.day}/${date.month}/${date.year}';
//     } else if (difference.inDays > 0) {
//       return '${difference.inDays}d';
//     } else if (difference.inHours > 0) {
//       return '${difference.inHours}h';
//     } else if (difference.inMinutes > 0) {
//       return '${difference.inMinutes}m';
//     } else {
//       return 'Just now';
//     }
//   }
// }