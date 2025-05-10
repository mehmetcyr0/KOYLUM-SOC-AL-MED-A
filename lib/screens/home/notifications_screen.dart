import 'package:flutter/material.dart';
import 'package:koylum/main.dart';
import 'package:koylum/models/notification.dart';
import 'package:koylum/models/profile.dart';
import 'package:koylum/utils/database_helpers.dart';
import 'package:koylum/utils/logger.dart';
import 'package:koylum/widgets/notification_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  RealtimeChannel? _notificationsChannel;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _notificationsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;

      // Önce bildirimleri getir
      final notificationsResponse = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // Sonra aktör profillerini ayrı ayrı getir
      final List<AppNotification> notifications = [];

      for (final notification in notificationsResponse) {
        try {
          final actorId = notification['actor_id'];
          if (actorId == null) continue;

          // Aktör profilini getir
          final actor = await DatabaseHelpers.getProfileById(actorId) ??
              Profile(
                id: actorId,
                fullName: 'Bilinmeyen Kullanıcı',
                createdAt: DateTime.now(),
              );

          // Bildirimi oluştur
          final appNotification = AppNotification(
            id: notification['id'] ?? '',
            userId: notification['user_id'] ?? '',
            actorId: actorId,
            type: notification['type'] ?? 'unknown',
            postId: notification['post_id'],
            commentId: notification['comment_id'],
            isRead: notification['is_read'] ?? false,
            createdAt: notification['created_at'] != null
                ? DateTime.parse(notification['created_at'])
                : DateTime.now(),
            actor: actor,
          );

          notifications.add(appNotification);
        } catch (e) {
          Logger.error('Error processing notification: $e');
          // Bu bildirimi atla
        }
      }

      if (!mounted) return;

      setState(() {
        _notifications = notifications;
      });
    } catch (error) {
      Logger.error('Load notifications error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Bildirimler yüklenemedi: ${DatabaseHelpers.formatErrorMessage(error.toString())}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _notifications = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // PostgresChangeFilter tip uyumsuzluğunu düzeltme
  void _subscribeToNotifications() {
    final userId = supabase.auth.currentUser!.id;

    // Filtre olarak Map kullanımı
    _notificationsChannel =
        supabase.channel('notifications-$userId').onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (payload) async {
                if (!mounted) return;

                try {
                  final notificationData = payload.newRecord;
                  final actorId = notificationData['actor_id'];
                  final currentUserId = supabase.auth.currentUser!.id;

                  if (actorId == null) return;

                  if (currentUserId != actorId) {
                    // Aktör profilini getir
                    final actor =
                        await DatabaseHelpers.getProfileById(actorId) ??
                            Profile(
                              id: actorId,
                              fullName: 'Bilinmeyen Kullanıcı',
                              createdAt: DateTime.now(),
                            );

                    // Bildirimi oluştur
                    final notification = AppNotification(
                      id: notificationData['id'] ?? '',
                      userId: notificationData['user_id'] ?? '',
                      actorId: actorId,
                      type: notificationData['type'] ?? 'unknown',
                      postId: notificationData['post_id'],
                      commentId: notificationData['comment_id'],
                      isRead: notificationData['is_read'] ?? false,
                      createdAt: notificationData['created_at'] != null
                          ? DateTime.parse(notificationData['created_at'])
                          : DateTime.now(),
                      actor: actor,
                    );

                    setState(() {
                      _notifications.insert(0, notification);
                    });
                  }
                } catch (error) {
                  Logger.error('Notification subscription error: $error');
                }
              },
            );

    _notificationsChannel?.subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('Henüz bildirim yok'))
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: const Color(0xFF4CAF50),
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      return NotificationItem(
                          notification: _notifications[index]);
                    },
                  ),
                ),
    );
  }
}
