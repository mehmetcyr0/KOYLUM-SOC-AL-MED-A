import 'package:flutter/material.dart';
import 'package:koylum/main.dart';
import 'package:koylum/models/conversation.dart';
import 'package:koylum/models/profile.dart';
import 'package:koylum/screens/messages/chat_screen.dart';
import 'package:koylum/utils/logger.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Profile> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // Kullanıcı adı, çiftlik adı veya konum ile arama yap
      final response = await supabase
          .from('profiles')
          .select()
          .or('full_name.ilike.%$query%,farm_name.ilike.%$query%,location.ilike.%$query%')
          .limit(20);

      final currentUserId = supabase.auth.currentUser!.id;
      final profiles = response
          .where(
              (profile) => profile['id'] != currentUserId) // Kendini hariç tut
          .map((data) => Profile.fromJson(data))
          .toList();

      setState(() {
        _searchResults = profiles;
      });
    } catch (error) {
      Logger.error('User search error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arama yapılırken hata oluştu: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startConversation(Profile profile) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      // Konuşma var mı kontrol et
      final conversationResponse = await supabase
          .from('conversations')
          .select()
          .or('and(user1_id.eq.${currentUserId},user2_id.eq.${profile.id}),and(user1_id.eq.${profile.id},user2_id.eq.${currentUserId})')
          .maybeSingle();

      Conversation conversation;

      if (conversationResponse != null) {
        // Mevcut konuşmayı kullan
        conversation = Conversation(
          id: conversationResponse['id'],
          user1Id: conversationResponse['user1_id'],
          user2Id: conversationResponse['user2_id'],
          lastMessage: conversationResponse['last_message'] ?? '',
          lastMessageAt:
              DateTime.parse(conversationResponse['last_message_at']),
          otherUser: profile,
          unread: conversationResponse['unread'] ?? false,
        );
      } else {
        // Yeni konuşma oluştur
        final newConversationResponse = await supabase
            .from('conversations')
            .insert({
              'user1_id': currentUserId,
              'user2_id': profile.id,
              'created_at': DateTime.now().toIso8601String(),
              'last_message_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        conversation = Conversation(
          id: newConversationResponse['id'],
          user1Id: newConversationResponse['user1_id'],
          user2Id: newConversationResponse['user2_id'],
          lastMessage: '',
          lastMessageAt:
              DateTime.parse(newConversationResponse['last_message_at']),
          otherUser: profile,
          unread: false,
        );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(conversation: conversation),
          ),
        );
      }
    } catch (error) {
      Logger.error('Start conversation error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konuşma başlatılamadı: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Mesaj'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Mesaj göndermek istediğiniz kişiyi arayın...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchUsers('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF333333)),
                ),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
              ),
              onChanged: (value) {
                if (value.length > 2) {
                  _searchUsers(value);
                } else if (value.isEmpty) {
                  _searchUsers('');
                }
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                    ? const Center(
                        child: Text(
                            'Mesaj göndermek istediğiniz kişiyi aramak için en az 3 karakter girin'),
                      )
                    : _searchResults.isEmpty
                        ? const Center(
                            child: Text('Sonuç bulunamadı'),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final profile = _searchResults[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: profile.avatarUrl != null
                                      ? NetworkImage(profile.avatarUrl!)
                                      : null,
                                  backgroundColor: const Color(0xFF4CAF50),
                                  child: profile.avatarUrl == null
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                title: Text(
                                  profile.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: profile.farmName != null &&
                                        profile.farmName!.isNotEmpty
                                    ? Text(profile.farmName!)
                                    : null,
                                onTap: () => _startConversation(profile),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
