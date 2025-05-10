import 'package:flutter/material.dart';
import 'package:koylum/main.dart';
import 'package:koylum/models/conversation.dart';
import 'package:koylum/models/profile.dart';
import 'package:koylum/screens/messages/chat_screen.dart';
import 'package:koylum/screens/messages/new_message_screen.dart';
import 'package:koylum/utils/database_helpers.dart';
import 'package:koylum/utils/logger.dart';
import 'package:koylum/widgets/conversation_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  RealtimeChannel? _conversationsChannel;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _subscribeToConversations();
  }

  @override
  void dispose() {
    _conversationsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;

      // Önce konuşmaları getir
      final conversationsResponse = await supabase
          .from('conversations')
          .select('*')
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .order('last_message_at', ascending: false);

      final List<Conversation> conversations = [];

      for (final conversation in conversationsResponse) {
        try {
          final isUser1 = conversation['user1_id'] == userId;
          final otherUserId =
              isUser1 ? conversation['user2_id'] : conversation['user1_id'];

          if (otherUserId == null) continue;

          // Diğer kullanıcı profilini getir
          final otherUser = await DatabaseHelpers.getProfileById(otherUserId) ??
              Profile(
                id: otherUserId,
                fullName: 'Bilinmeyen Kullanıcı',
                createdAt: DateTime.now(),
              );

          // Konuşmayı oluştur
          final conv = Conversation(
            id: conversation['id'] ?? '',
            user1Id: conversation['user1_id'] ?? '',
            user2Id: conversation['user2_id'] ?? '',
            lastMessage: conversation['last_message'] ?? '',
            lastMessageAt: conversation['last_message_at'] != null
                ? DateTime.parse(conversation['last_message_at'])
                : DateTime.now(),
            otherUser: otherUser,
            unread: conversation['unread'] ?? false,
          );

          conversations.add(conv);
        } catch (e) {
          Logger.error('Error processing conversation:', e);
          // Bu konuşmayı atla
        }
      }

      setState(() {
        _conversations = conversations;
      });
    } catch (error) {
      Logger.error('Load conversations error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Konuşmalar yüklenemedi: ${DatabaseHelpers.formatErrorMessage(error.toString())}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _conversations = [];
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _subscribeToConversations() {
    final userId = supabase.auth.currentUser!.id;

    // User1 olduğu konuşmalar için abone ol
    final channel1 =
        supabase.channel('conversations-user1-$userId').onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'conversations',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user1_id',
                value: userId,
              ),
              callback: (payload) {
                _loadConversations();
              },
            );

    // User2 olduğu konuşmalar için abone ol
    final channel2 =
        supabase.channel('conversations-user2-$userId').onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'conversations',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user2_id',
                value: userId,
              ),
              callback: (payload) {
                _loadConversations();
              },
            );

    channel1.subscribe();
    channel2.subscribe();

    _conversationsChannel = channel1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesajlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NewMessageScreen(),
                ),
              ).then((_) => _loadConversations());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Henüz mesaj yok'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NewMessageScreen(),
                            ),
                          ).then((_) => _loadConversations());
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Yeni Mesaj'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  color: const Color(0xFF4CAF50),
                  child: ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      return ConversationItem(
                        conversation: _conversations[index],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                conversation: _conversations[index],
                              ),
                            ),
                          ).then((_) => _loadConversations());
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
