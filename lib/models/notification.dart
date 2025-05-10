import 'package:koylum/models/profile.dart';

class AppNotification {
  final String id;
  final String userId;
  final String actorId;
  final String type;
  final String? postId;
  final String? commentId;
  final bool isRead;
  final DateTime createdAt;
  final Profile actor;

  AppNotification({
    required this.id,
    required this.userId,
    required this.actorId,
    required this.type,
    this.postId,
    this.commentId,
    required this.isRead,
    required this.createdAt,
    required this.actor,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      actorId: json['actor_id'] ?? '',
      type: json['type'] ?? 'unknown',
      postId: json['post_id'],
      commentId: json['comment_id'],
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      actor: json['profiles'] != null 
          ? Profile.fromJson(json['profiles']) 
          : Profile(
              id: json['actor_id'] ?? '',
              fullName: 'Bilinmeyen Kullanıcı',
              createdAt: DateTime.now(),
            ),
    );
  }
}
