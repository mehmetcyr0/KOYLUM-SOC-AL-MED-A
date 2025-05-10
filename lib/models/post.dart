import 'package:koylum/models/profile.dart';

class Post {
  final String id;
  final String userId;
  final String content;
  final List<String>? mediaUrls;
  final List<String>? tags;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final Profile author;
  final bool isLiked;

  Post({
    required this.id,
    required this.userId,
    required this.content,
    this.mediaUrls,
    this.tags,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    required this.author,
    this.isLiked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      content: json['content'] ?? '',
      mediaUrls: json['media_urls'] != null
          ? List<String>.from(json['media_urls'])
          : null,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      author: json['profiles'] != null 
          ? Profile.fromJson(json['profiles']) 
          : Profile(
              id: json['user_id'] ?? '',
              fullName: 'Bilinmeyen Kullanıcı',
              createdAt: DateTime.now(),
            ),
    );
  }
}
