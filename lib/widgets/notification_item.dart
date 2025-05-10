import 'package:flutter/material.dart';
import 'package:koylum/models/notification.dart';
import 'package:koylum/screens/profile/profile_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationItem extends StatelessWidget {
  final AppNotification notification;

  const NotificationItem({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(
                userId: notification.actorId,
              ),
            ),
          );
        },
        child: CircleAvatar(
          backgroundImage: notification.actor.avatarUrl != null
              ? NetworkImage(notification.actor.avatarUrl!)
              : null,
          backgroundColor: const Color(0xFF4CAF50),
          child: notification.actor.avatarUrl == null
              ? const Icon(
                  Icons.person,
                  color: Colors.white,
                )
              : null,
        ),
      ),
      title: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: notification.actor.fullName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: _getNotificationText(notification.type),
            ),
          ],
        ),
      ),
      subtitle: Text(
        timeago.format(notification.createdAt, locale: 'tr'),
        style: const TextStyle(
          fontSize: 12,
        ),
      ),
      trailing: notification.isRead
          ? null
          : Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
            ),
      onTap: () {
        // Bildirime tıklandığında ilgili sayfaya git
      },
    );
  }

  String _getNotificationText(String type) {
    switch (type) {
      case 'like':
        return ' gönderini beğendi';
      case 'comment':
        return ' gönderine yorum yaptı';
      case 'follow':
        return ' seni takip etmeye başladı';
      default:
        return '';
    }
  }
}
