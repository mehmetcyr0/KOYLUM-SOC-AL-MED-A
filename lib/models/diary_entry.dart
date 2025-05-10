import 'package:koylum/models/profile.dart';

class DiaryEntry {
  final String id;
  final String userId;
  final String title;
  final String content;
  final DateTime date;
  final String? activityType;
  final List<String>? mediaUrls;
  final DateTime createdAt;
  final Profile author;

  DiaryEntry({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.date,
    this.activityType,
    this.mediaUrls,
    required this.createdAt,
    required this.author,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      activityType: json['activity_type'],
      mediaUrls: json['media_urls'] != null
          ? List<String>.from(json['media_urls'])
          : null,
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
