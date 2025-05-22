import 'user_profile.dart';

class Comment {
  final int? id;
  final String content;
  final DateTime? createdAt;
  final UserProfile? author;
  final String? articleId;

  Comment({
    this.id,
    required this.content,
    this.createdAt,
    this.author,
    this.articleId,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      content: json['content'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      author: json['author'] != null 
          ? UserProfile.fromJson(json['author']) 
          : null,
      articleId: json['article_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'article_id': articleId,
    };
  }
}