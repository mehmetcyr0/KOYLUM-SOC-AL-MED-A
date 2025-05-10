import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koylum/main.dart';
import 'package:koylum/models/conversation.dart';
import 'package:koylum/models/message.dart';
import 'package:koylum/utils/logger.dart';
import 'package:koylum/widgets/message_bubble.dart';
import 'package:koylum/screens/profile/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingImage = false;
  File? _selectedImage;
  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('messages')
          .select()
          .eq('conversation_id', widget.conversation.id)
          .order('created_at');

      final messages = response.map((msg) => Message.fromJson(msg)).toList();

      if (!mounted) return;

      setState(() {
        _messages = List<Message>.from(messages);
      });

      // Mesajları okundu olarak işaretle
      await _markAsRead();

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      Logger.error('Messages loading error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesajlar yüklenemedi: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _messages = [];
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

  void _subscribeToMessages() {
    final conversationId = widget.conversation.id;

    _messagesChannel =
        supabase.channel('messages-$conversationId').onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'conversation_id',
                value: conversationId,
              ),
              callback: (payload) {
                if (!mounted) return;

                try {
                  final message = Message.fromJson(payload.newRecord);
                  setState(() {
                    _messages.add(message);
                  });

                  // Yeni mesaj geldiğinde okundu olarak işaretle
                  _markAsRead();

                  // Scroll to bottom
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                } catch (e) {
                  Logger.error('Message processing error:', e);
                }
              },
            );

    _messagesChannel?.subscribe();
  }

  Future<void> _markAsRead() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', widget.conversation.id)
          .eq('receiver_id', userId)
          .eq('is_read', false);

      // Konuşmayı da okundu olarak işaretle
      await supabase
          .from('conversations')
          .update({'unread': false}).eq('id', widget.conversation.id);
    } catch (error) {
      Logger.error('Mark as read error:', error);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (imageFile != null) {
      setState(() {
        _selectedImage = File(imageFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      setState(() {
        _isUploadingImage = true;
      });

      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'messages/$fileName';

      await supabase.storage.from('media').uploadBinary(
            filePath,
            await imageFile.readAsBytes(),
            fileOptions: FileOptions(
              cacheControl: '3600',
              contentType: 'image/$fileExt',
            ),
          );

      final imageUrl = await supabase.storage
          .from('media')
          .createSignedUrl(filePath, 60 * 60 * 24 * 365 * 10);

      return imageUrl;
    } catch (error) {
      Logger.error('Image upload error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resim yüklenemedi: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      final receiverId = widget.conversation.otherUser.id;
      String? mediaUrl;

      // Eğer resim seçilmişse yükle
      if (_selectedImage != null) {
        mediaUrl = await _uploadImage(_selectedImage!);
      }

      // Mesajı gönder
      await supabase.from('messages').insert({
        'conversation_id': widget.conversation.id,
        'sender_id': userId,
        'receiver_id': receiverId,
        'content': text.isEmpty && mediaUrl != null ? '📷 Fotoğraf' : text,
        'media_url': mediaUrl,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Konuşmayı güncelle
      await supabase.from('conversations').update({
        'last_message': text.isEmpty && mediaUrl != null ? '📷 Fotoğraf' : text,
        'last_message_at': DateTime.now().toIso8601String(),
        'unread': true,
      }).eq('id', widget.conversation.id);

      _messageController.clear();
      setState(() {
        _selectedImage = null;
      });
    } catch (error) {
      Logger.error('Send message error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesaj gönderilemedi: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Oturum açmanız gerekiyor')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(
                  userId: widget.conversation.otherUser.id,
                ),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: widget.conversation.otherUser.avatarUrl != null
                    ? NetworkImage(widget.conversation.otherUser.avatarUrl!)
                    : null,
                backgroundColor: const Color(0xFF4CAF50),
                radius: 16,
                child: widget.conversation.otherUser.avatarUrl == null
                    ? const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(widget.conversation.otherUser.fullName),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Profil sayfasına git
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                    userId: widget.conversation.otherUser.id,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Mesaj listesi
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('Henüz mesaj yok'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message.senderId == currentUserId;

                          return MessageBubble(
                            message: message,
                            isMe: isMe,
                          );
                        },
                      ),
          ),

          // Seçilen resim önizlemesi
          if (_selectedImage != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: const Color(0xFF1E1E1E),
              child: Stack(
                children: [
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Mesaj gönderme alanı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: const Color(0xFF1E1E1E),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo),
                  onPressed:
                      _isUploadingImage || _isSending ? null : _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Mesaj yazın...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !_isSending && !_isUploadingImage,
                  ),
                ),
                _isUploadingImage || _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF4CAF50),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFF4CAF50)),
                        onPressed: _sendMessage,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
