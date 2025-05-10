import 'package:flutter/material.dart';
import 'package:koylum/main.dart';
import 'package:koylum/models/conversation.dart';
import 'package:koylum/models/profile.dart';
import 'package:koylum/screens/auth/login_screen.dart';
import 'package:koylum/screens/messages/chat_screen.dart';
import 'package:koylum/screens/profile/edit_profile_screen.dart';
import 'package:koylum/screens/profile/farm_diary_screen.dart';
import 'package:koylum/screens/profile/followers_screen.dart';
import 'package:koylum/utils/database_helpers.dart';
import 'package:koylum/utils/logger.dart';
import 'package:koylum/widgets/post_card.dart';
import 'package:koylum/models/post.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  Profile? _profile;
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
    _loadPosts();
    _checkFollowStatus();
    _getFollowCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _userId => widget.userId ?? supabase.auth.currentUser!.id;

  bool get _isCurrentUser =>
      widget.userId == null || widget.userId == supabase.auth.currentUser!.id;

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Profil var mı kontrol et
      final profileExists = await DatabaseHelpers.checkProfileExists(_userId);

      // Profil varsa getir, yoksa null
      final profile =
          profileExists ? await DatabaseHelpers.getProfileById(_userId) : null;

      // Profil null değilse state'i güncelle
      if (mounted && profile != null) {
        setState(() {
          _profile = profile;
        });
      }
    } catch (error) {
      Logger.error('Profile load error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Profil yüklenemedi: ${DatabaseHelpers.formatErrorMessage(error.toString())}'),
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

  Future<void> _loadPosts() async {
    try {
      final response = await supabase
          .from('posts')
          .select('*, profiles:user_id(*)')
          .eq('user_id', _userId)
          .order('created_at', ascending: false);

      final List<Post> posts = [];

      for (final postData in response) {
        try {
          // Yazar profilini getir
          final authorId = postData['user_id'];
          Profile? author;

          if (postData['profiles'] != null) {
            author = Profile.fromJson(postData['profiles']);
          } else {
            author = await DatabaseHelpers.getProfileById(authorId);
          }

          if (author == null) {
            author = Profile(
              id: authorId,
              fullName: 'Bilinmeyen Kullanıcı',
              createdAt: DateTime.now(),
            );
          }

          // Gönderiyi oluştur
          final post = Post(
            id: postData['id'] ?? '',
            userId: authorId ?? '',
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
      Logger.error('Load posts error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Gönderiler yüklenemedi: ${DatabaseHelpers.formatErrorMessage(error.toString())}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _posts = [];
        });
      }
    }
  }

  Future<void> _checkFollowStatus() async {
    if (_isCurrentUser) return;

    try {
      final currentUserId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('follows')
          .select()
          .eq('follower_id', currentUserId)
          .eq('following_id', _userId);

      if (mounted) {
        setState(() {
          _isFollowing = response.isNotEmpty;
        });
      }
    } catch (error) {
      Logger.error('Check follow status error:', error);
    }
  }

  Future<void> _getFollowCounts() async {
    try {
      // Takipçi sayısını getir
      final followersResponse = await supabase
          .from('follows')
          .select('count')
          .eq('following_id', _userId)
          .single();

      final followersCount = followersResponse['count'] ?? 0;

      // Takip edilen sayısını getir
      final followingResponse = await supabase
          .from('follows')
          .select('count')
          .eq('follower_id', _userId)
          .single();

      final followingCount = followingResponse['count'] ?? 0;

      if (mounted) {
        setState(() {
          _followersCount = followersCount;
          _followingCount = followingCount;
        });
      }
    } catch (error) {
      Logger.error('Get follow counts error:', error);
      // Hata durumunda varsayılan değerleri kullan
      if (mounted) {
        setState(() {
          _followersCount = 0;
          _followingCount = 0;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_isCurrentUser) return;

    final currentUserId = supabase.auth.currentUser!.id;

    try {
      if (_isFollowing) {
        // Takibi bırak
        await supabase
            .from('follows')
            .delete()
            .eq('follower_id', currentUserId)
            .eq('following_id', _userId);

        setState(() {
          _isFollowing = false;
          _followersCount = _followersCount > 0 ? _followersCount - 1 : 0;
        });
      } else {
        // Takip et
        await supabase.from('follows').insert({
          'follower_id': currentUserId,
          'following_id': _userId,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Bildirim oluştur
        await supabase.from('notifications').insert({
          'user_id': _userId,
          'actor_id': currentUserId,
          'type': 'follow',
          'created_at': DateTime.now().toIso8601String(),
          'is_read': false,
        });

        setState(() {
          _isFollowing = true;
          _followersCount++;
        });
      }
    } catch (error) {
      Logger.error('Toggle follow error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'İşlem başarısız: ${DatabaseHelpers.formatErrorMessage(error.toString())}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _startConversation() async {
    if (_isCurrentUser || _profile == null) return;

    try {
      final currentUserId = supabase.auth.currentUser!.id;

      // Konuşma var mı kontrol et
      final conversationResponse = await supabase
          .from('conversations')
          .select()
          .or('and(user1_id.eq.${currentUserId},user2_id.eq.${_userId}),and(user1_id.eq.${_userId},user2_id.eq.${currentUserId})')
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
          otherUser: _profile!,
          unread: conversationResponse['unread'] ?? false,
        );
      } else {
        // Yeni konuşma oluştur
        final newConversationResponse = await supabase
            .from('conversations')
            .insert({
              'user1_id': currentUserId,
              'user2_id': _userId,
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
          otherUser: _profile!,
          unread: false,
        );
      }

      if (mounted) {
        Navigator.push(
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
        title: Text(_isCurrentUser ? 'Profilim' : 'Profil'),
        actions: [
          if (_isCurrentUser)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfileScreen(),
                    ),
                  ).then((_) => _loadProfile());
                } else if (value == 'logout') {
                  _signOut();
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Profili Düzenle'),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Text('Çıkış Yap'),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Profil bulunamadı'))
              : NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: _buildProfileHeader(),
                      ),
                      SliverPersistentHeader(
                        delegate: _SliverAppBarDelegate(
                          TabBar(
                            controller: _tabController,
                            labelColor: const Color(0xFF4CAF50),
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: const Color(0xFF4CAF50),
                            tabs: const [
                              Tab(text: 'Gönderiler'),
                              Tab(text: 'Çiftlik Günlüğü'),
                            ],
                          ),
                        ),
                        pinned: true,
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _posts.isEmpty
                          ? const Center(child: Text('Henüz gönderi yok'))
                          : ListView.builder(
                              itemCount: _posts.length,
                              itemBuilder: (context, index) {
                                return PostCard(post: _posts[index]);
                              },
                            ),
                      FarmDiaryScreen(userId: _userId),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kapak fotoğrafı
        Container(
          height: 150,
          width: double.infinity,
          color: const Color(0xFF333333),
          child: _profile?.coverImageUrl != null
              ? Image.network(
                  _profile!.coverImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                        child: Icon(Icons.image_not_supported,
                            size: 40, color: Colors.grey));
                  },
                )
              : null,
        ),
        // Profil fotoğrafı ve bilgiler
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Profil fotoğrafı
                  Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(top: 0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 4,
                      ),
                      image: _profile?.avatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_profile!.avatarUrl!),
                              fit: BoxFit.cover,
                              onError: (exception, stackTrace) {
                                // Resim yüklenemezse sessizce hata işle
                              },
                            )
                          : null,
                    ),
                    child: _profile?.avatarUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  // Takip bilgileri
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn('Gönderi', _posts.length),
                        _buildStatColumn('Takipçi', _followersCount),
                        _buildStatColumn('Takip', _followingCount),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // İsim ve çiftlik adı
              Text(
                _profile?.fullName ?? '',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_profile?.farmName != null && _profile!.farmName!.isNotEmpty)
                Text(
                  _profile!.farmName!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              const SizedBox(height: 8),
              // Biyografi
              if (_profile?.bio != null && _profile!.bio!.isNotEmpty)
                Text(_profile!.bio!),
              const SizedBox(height: 16),
              // Çiftlik bilgileri
              if (_profile?.farmType != null || _profile?.location != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_profile?.farmType != null &&
                        _profile!.farmType!.isNotEmpty)
                      Chip(
                        backgroundColor: const Color(0xFF1E1E1E),
                        label: Text(_profile!.farmType!),
                        avatar: const Icon(Icons.agriculture, size: 16),
                      ),
                    if (_profile?.location != null &&
                        _profile!.location!.isNotEmpty)
                      Chip(
                        backgroundColor: const Color(0xFF1E1E1E),
                        label: Text(_profile!.location!),
                        avatar: const Icon(Icons.location_on, size: 16),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              // Butonlar
              if (_isCurrentUser)
                // Profili düzenle butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      ).then((_) => _loadProfile());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF333333),
                    ),
                    child: const Text('Profili Düzenle'),
                  ),
                )
              else
                // Takip et ve mesaj at butonları
                Row(
                  children: [
                    // Takip et / Takibi bırak butonu
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing
                              ? const Color(0xFF333333)
                              : const Color(0xFF4CAF50),
                        ),
                        child: Text(
                          _isFollowing ? 'Takibi Bırak' : 'Takip Et',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Mesaj at butonu
                    ElevatedButton(
                      onPressed: _startConversation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF333333),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.message, size: 16),
                          SizedBox(width: 4),
                          Text('Mesaj'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return GestureDetector(
      onTap: () {
        if (label == 'Takipçi' || label == 'Takip') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FollowersScreen(
                userId: _userId,
                isFollowers: label == 'Takipçi',
              ),
            ),
          );
        }
      },
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
