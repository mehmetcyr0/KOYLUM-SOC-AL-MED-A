import 'package:flutter/material.dart';
import 'package:koylum/main.dart';
import 'package:koylum/models/comment.dart';
import 'package:koylum/models/post.dart';
import 'package:koylum/models/profile.dart';
import 'package:koylum/screens/profile/profile_screen.dart';
import 'package:koylum/utils/database_helpers.dart';
import 'package:koylum/utils/logger.dart';
import 'package:koylum/widgets/post_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentScreen extends StatefulWidget {
  final Post post;

  const CommentScreen({super.key, required this.post});

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final TextEditingController _commentController = TextEditingController();
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  RealtimeChannel? _commentsChannel;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _subscribeToComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Önce comments_with_profiles görünümünü dene
      try {
        final response = await supabase
            .from('comments_with_profiles')
            .select()
            .eq('post_id', widget.post.id)
            .order('created_at');

        _processComments(response);
      } catch (viewError) {
        Logger.error('View error, falling back to manual join:', viewError);

        // Görünüm yoksa manuel join yap
        final response = await supabase
            .from('comments')
            .select()
            .eq('post_id', widget.post.id)
            .order('created_at');

        _processComments(response);
      }
    } catch (error) {
      Logger.error('Load comments error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yorumlar yüklenemedi: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _comments = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _processComments(List<dynamic> response) async {
    final List<Comment> comments = [];

    for (final commentData in response) {
      try {
        // Yazar profilini getir
        Profile author;

        if (commentData['profile_id'] != null) {
          // Görünümden gelen veriler
          author = Profile(
            id: commentData['user_id'],
            fullName: commentData['full_name'] ?? 'Kullanıcı',
            avatarUrl: commentData['avatar_url'],
            createdAt: DateTime.now(),
          );
        } else {
          // Manuel join için profil bilgilerini getir
          final authorId = commentData['user_id'];
          final authorProfile = await DatabaseHelpers.getProfileById(authorId);

          if (authorProfile != null) {
            author = authorProfile;
          } else {
            author = Profile(
              id: authorId,
              fullName: 'Kullanıcı',
              createdAt: DateTime.now(),
            );
          }
        }

        // Yorumu oluştur
        final comment = Comment(
          id: commentData['id'],
          postId: commentData['post_id'],
          userId: commentData['user_id'],
          content: commentData['content'],
          createdAt: DateTime.parse(commentData['created_at']),
          author: author,
        );

        comments.add(comment);
      } catch (e) {
        Logger.error('Error processing comment:', e);
        // Bu yorumu atla
      }
    }

    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    }
  }

  void _subscribeToComments() {
    final postId = widget.post.id;

    _commentsChannel = supabase.channel('comments-$postId').onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (payload) async {
            if (!mounted) return;

            try {
              final commentData = payload.newRecord;
              final authorId = commentData['user_id'];

              // Yazar profilini getir
              final author = await DatabaseHelpers.getProfileById(authorId) ??
                  Profile(
                    id: authorId,
                    fullName: 'Kullanıcı',
                    createdAt: DateTime.now(),
                  );

              // Yorumu oluştur
              final comment = Comment(
                id: commentData['id'],
                postId: commentData['post_id'],
                userId: commentData['user_id'],
                content: commentData['content'],
                createdAt: DateTime.parse(commentData['created_at']),
                author: author,
              );

              setState(() {
                _comments.add(comment);
              });
            } catch (e) {
              Logger.error('Comment subscription error:', e);
            }
          },
        );

    _commentsChannel?.subscribe();
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Önce profil var mı kontrol et
      final profileExists = await DatabaseHelpers.checkProfileExists(userId);
      if (!profileExists) {
        // Profil yoksa oluştur
        await DatabaseHelpers.ensureProfileExists(userId);
      }

      // Yorumu ekle
      await supabase.from('comments').insert({
        'post_id': widget.post.id,
        'user_id': userId,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Bildirim oluştur (kendi gönderisine yorum yapmıyorsa)
      if (userId != widget.post.userId) {
        await supabase.from('notifications').insert({
          'user_id': widget.post.userId,
          'actor_id': userId,
          'type': 'comment',
          'post_id': widget.post.id,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      _commentController.clear();
    } catch (error) {
      Logger.error('Add comment error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yorum eklenemedi: ${error.toString()}'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yorumlar'),
      ),
      body: Column(
        children: [
          // Gönderi
          PostCard(post: widget.post),

          // Yorumlar
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text('Henüz yorum yok'))
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _buildCommentItem(comment);
                        },
                      ),
          ),

          // Yorum yazma alanı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: const Color(0xFF1E1E1E),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Yorum yazın...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !_isSending,
                  ),
                ),
                _isSending
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
                        onPressed: _addComment,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return ListTile(
      leading: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: comment.userId),
            ),
          );
        },
        child: CircleAvatar(
          backgroundImage: comment.author.avatarUrl != null
              ? NetworkImage(comment.author.avatarUrl!)
              : null,
          backgroundColor: const Color(0xFF4CAF50),
          child: comment.author.avatarUrl == null
              ? const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 16,
                )
              : null,
        ),
      ),
      title: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: comment.userId),
                ),
              );
            },
            child: Text(
              comment.author.fullName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeago.format(comment.createdAt, locale: 'tr'),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      subtitle: Text(comment.content),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
