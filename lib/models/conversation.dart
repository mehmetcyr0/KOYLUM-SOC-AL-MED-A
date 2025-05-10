import 'package:koylum/models/profile.dart';

class Conversation {
  final String id;
  final String user1Id;
  final String user2Id;
  final String lastMessage;
  final DateTime lastMessageAt;
  final Profile otherUser;
  final bool unread;

  Conversation({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.otherUser,
    this.unread = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json, String currentUserId) {
    final isUser1 = json['user1_id'] == currentUserId;
    final otherUserId = isUser1 ? json['user2_id'] : json['user1_id'];
    
    // Make sure profiles exists and contains necessary data
    final profileData = json['profiles'] ?? {};
    Profile otherUserProfile;
    
    try {
      otherUserProfile = Profile.fromJson(profileData);
    } catch (e) {
      // Create a minimal profile if data is missing
      otherUserProfile = Profile(
        id: otherUserId ?? '',
        fullName: 'Kullanıcı',
        createdAt: DateTime.now(),
      );
    }
    
    return Conversation(
      id: json['id'] ?? '',
      user1Id: json['user1_id'] ?? '',
      user2Id: json['user2_id'] ?? '',
      lastMessage: json['last_message'] ?? '',
      lastMessageAt: json['last_message_at'] != null 
          ? DateTime.parse(json['last_message_at']) 
          : DateTime.now(),
      otherUser: otherUserProfile,
      unread: json['unread'] ?? false,
    );
  }
}
