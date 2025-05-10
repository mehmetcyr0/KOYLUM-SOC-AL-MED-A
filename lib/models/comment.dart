import 'package:koylum/models/profile.dart';

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final Profile author;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.author,
  });

  factory Comment.fromJson(Map<String, dynamic> json, {Profile? author}) {
    return Comment(
      id: json['id'] ?? '',
      postId: json['post_id'] ?? '',
      userId: json['user_id'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      author: author ??
          (json['profiles'] != null
              ? Profile.fromJson(json['profiles'])
              : Profile(
                  id: json['user_id'] ?? '',
                  fullName: 'Bilinmeyen Kullanıcı',
                  createdAt: DateTime.now(),
                )),
    );
  }
}
