import 'package:flutter/material.dart';
import 'package:koylum/main.dart';
import 'package:koylum/models/post.dart';
import 'package:koylum/models/profile.dart';
import 'package:koylum/utils/logger.dart';
import 'package:koylum/widgets/post_card.dart';
import 'package:koylum/screens/users/users_search_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  List<Post> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // posts_with_profiles view kullan veya join yap
      final response = await supabase
          .from('posts')
          .select('*, profiles:user_id(*)')
          .order('created_at', ascending: false);

      final List<Post> posts = [];

      for (final postData in response) {
        try {
          // Profil bilgilerini kontrol et
          final profileData = postData['profiles'];
          Profile author;

          if (profileData != null) {
            author = Profile.fromJson(profileData);
          } else {
            // Profil yoksa, kullanıcı ID'sini kullanarak profili getir
            final userId = postData['user_id'];
            final profileResponse = await supabase
                .from('profiles')
                .select()
                .eq('id', userId)
                .maybeSingle();

            if (profileResponse != null) {
              author = Profile.fromJson(profileResponse);
            } else {
              // Profil bulunamazsa varsayılan profil oluştur
              author = Profile(
                id: userId ?? '',
                fullName: 'Bilinmeyen Kullanıcı',
                createdAt: DateTime.now(),
              );
            }
          }

          // Gönderiyi oluştur
          final post = Post(
            id: postData['id'] ?? '',
            userId: postData['user_id'] ?? '',
            content: postData['content'] ?? '',
            mediaUrls: postData['media_urls'] != null
                ? List<String>.from(postData['media_urls'])
                : null,
            tags: postData['tags'] != null
                ? List<String>.from(postData['tags'])
                : null,
            likesCount: postData['likes_count'] ?? 0,
            commentsCount: postData['comments_count'] ?? 0,
            createdAt: postData['created_at'] != null
                ? DateTime.parse(postData['created_at'])
                : DateTime.now(),
            author: author,
            isLiked: false, // Beğeni durumu ayrıca kontrol edilebilir
          );

          posts.add(post);
        } catch (e) {
          Logger.error('Error processing post:', e);
          // Bu gönderiyi atla
        }
      }

      if (mounted) {
        setState(() {
          _posts = posts;
        });
      }
    } catch (error) {
      Logger.error('Posts loading error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gönderiler yüklenemedi: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _posts = [];
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

  // Ana sayfadan çağrılabilecek yenileme fonksiyonu
  void refreshFeed() {
    _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KÖYLÜM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UsersSearchScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        color: const Color(0xFF4CAF50),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _posts.isEmpty
                ? const Center(child: Text('Henüz gönderi yok'))
                : ListView.builder(
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      return PostCard(post: _posts[index]);
                    },
                  ),
      ),
    );
  }
}
