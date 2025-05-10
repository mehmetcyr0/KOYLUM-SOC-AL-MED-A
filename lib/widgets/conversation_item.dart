import 'package:flutter/material.dart';
import 'package:koylum/models/conversation.dart';
import 'package:timeago/timeago.dart' as timeago;

class ConversationItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ConversationItem({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: conversation.otherUser.avatarUrl != null
            ? NetworkImage(conversation.otherUser.avatarUrl!)
            : null,
        backgroundColor: const Color(0xFF4CAF50),
        child: conversation.otherUser.avatarUrl == null
            ? const Icon(
                Icons.person,
                color: Colors.white,
              )
            : null,
      ),
      title: Text(
        conversation.otherUser.fullName,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        conversation.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            timeago.format(conversation.lastMessageAt, locale: 'tr'),
            style: const TextStyle(
              fontSize: 12,
            ),
          ),
          if (conversation.unread)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
