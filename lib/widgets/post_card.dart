import 'package:flutter/material.dart';
import 'package:koylum/main.dart';
import 'package:koylum/models/post.dart';
import 'package:koylum/screens/posts/comment_screen.dart';
import 'package:koylum/screens/profile/profile_screen.dart';
import 'package:koylum/utils/logger.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostCard extends StatefulWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  int _likesCount = 0;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    _checkLikeStatus();
  }

  Future<void> _checkLikeStatus() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('likes')
          .select()
          .eq('user_id', userId)
          .eq('post_id', widget.post.id);

      if (mounted) {
        setState(() {
          _isLiked = response.isNotEmpty;
        });
      }
    } catch (error) {
      Logger.error('Check like status error:', error);
    }
  }

  Future<void> _toggleLike() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      if (_isLiked) {
        // Beğeniyi kaldır
        await supabase
            .from('likes')
            .delete()
            .eq('user_id', userId)
            .eq('post_id', widget.post.id);

        setState(() {
          _isLiked = false;
          _likesCount--;
        });
      } else {
        // Beğen
        await supabase.from('likes').insert({
          'user_id': userId,
          'post_id': widget.post.id,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Bildirim oluştur (kendi gönderisini beğenmiyorsa)
        if (userId != widget.post.userId) {
          await supabase.from('notifications').insert({
            'user_id': widget.post.userId,
            'actor_id': userId,
            'type': 'like',
            'post_id': widget.post.id,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        setState(() {
          _isLiked = true;
          _likesCount++;
        });
      }
    } catch (error) {
      Logger.error('Toggle like error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İşlem başarısız: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sharePost() async {
    try {
      final content = widget.post.content;
      final author = widget.post.author.fullName;

      String shareText =
          '$author: $content\n\nKöylüm uygulamasından paylaşıldı';

      if (widget.post.tags != null && widget.post.tags!.isNotEmpty) {
        shareText +=
            '\n\nEtiketler: ${widget.post.tags!.map((tag) => '#$tag').join(' ')}';
      }

      await Share.share(shareText);
    } catch (e) {
      Logger.error('Share error:', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paylaşım yapılırken bir hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentScreen(post: widget.post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 0,
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gönderi başlığı
          ListTile(
            leading: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      userId: widget.post.userId,
                    ),
                  ),
                );
              },
              child: CircleAvatar(
                backgroundImage: widget.post.author.avatarUrl != null
                    ? NetworkImage(widget.post.author.avatarUrl!)
                    : null,
                backgroundColor: const Color(0xFF4CAF50),
                child: widget.post.author.avatarUrl == null
                    ? const Icon(
                        Icons.person,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            title: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      userId: widget.post.userId,
                    ),
                  ),
                );
              },
              child: Text(
                widget.post.author.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            subtitle: Text(
              timeago.format(widget.post.createdAt, locale: 'tr'),
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                // Gönderi menüsünü göster
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF1E1E1E),
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.share),
                        title: const Text('Paylaş'),
                        onTap: () {
                          Navigator.pop(context);
                          _sharePost();
                        },
                      ),
                      if (widget.post.userId == supabase.auth.currentUser?.id)
                        ListTile(
                          leading: const Icon(Icons.delete, color: Colors.red),
                          title: const Text('Sil',
                              style: TextStyle(color: Colors.red)),
                          onTap: () {
                            // Gönderiyi silme işlemi
                            Navigator.pop(context);
                            // Silme işlemi burada yapılacak
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Gönderi içeriği
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(widget.post.content),
          ),
          const SizedBox(height: 8),
          // Gönderi medyası
          if (widget.post.mediaUrls != null &&
              widget.post.mediaUrls!.isNotEmpty)
            SizedBox(
              height: 200,
              child: PageView.builder(
                itemCount: widget.post.mediaUrls!.length,
                itemBuilder: (context, index) {
                  return Image.network(
                    widget.post.mediaUrls![index],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.grey,
                          size: 40,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          // Etiketler
          if (widget.post.tags != null && widget.post.tags!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                spacing: 8,
                children: widget.post.tags!.map((tag) {
                  return Chip(
                    label: Text('#$tag'),
                    backgroundColor: const Color(0xFF333333),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4CAF50),
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ),
          // Beğeni ve yorum sayıları
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('$_likesCount beğeni'),
                const SizedBox(width: 16),
                Text('${widget.post.commentsCount} yorum'),
              ],
            ),
          ),
          const Divider(height: 1),
          // Butonlar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _toggleLike,
                icon: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red : null,
                ),
                label: const Text('Beğen'),
                style: TextButton.styleFrom(
                  foregroundColor: _isLiked ? Colors.red : Colors.white,
                ),
              ),
              TextButton.icon(
                onPressed: _navigateToComments,
                icon: const Icon(Icons.comment_outlined),
                label: const Text('Yorum Yap'),
              ),
              TextButton.icon(
                onPressed: _sharePost,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Paylaş'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
