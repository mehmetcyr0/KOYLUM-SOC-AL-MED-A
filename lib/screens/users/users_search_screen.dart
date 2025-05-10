import 'package:flutter/material.dart';
import 'package:koylum/main.dart';
import 'package:koylum/models/profile.dart';
import 'package:koylum/screens/profile/profile_screen.dart';
import 'package:koylum/utils/logger.dart';

class UsersSearchScreen extends StatefulWidget {
  const UsersSearchScreen({super.key});

  @override
  State<UsersSearchScreen> createState() => _UsersSearchScreenState();
}

class _UsersSearchScreenState extends State<UsersSearchScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Ara'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'İsim, çiftlik adı veya konum ara...',
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
                            'Kullanıcı aramak için en az 3 karakter girin'),
                      )
                    : _searchResults.isEmpty
                        ? const Center(
                            child: Text('Sonuç bulunamadı'),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final profile = _searchResults[index];
                              return UserListItem(profile: profile);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class UserListItem extends StatefulWidget {
  final Profile profile;

  const UserListItem({super.key, required this.profile});

  @override
  State<UserListItem> createState() => _UserListItemState();
}

class _UserListItemState extends State<UserListItem> {
  bool _isFollowing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('follows')
          .select()
          .eq('follower_id', currentUserId)
          .eq('following_id', widget.profile.id);

      if (mounted) {
        setState(() {
          _isFollowing = response.isNotEmpty;
        });
      }
    } catch (error) {
      Logger.error('Check follow status error:', error);
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUserId = supabase.auth.currentUser!.id;

      if (_isFollowing) {
        // Takibi bırak
        await supabase
            .from('follows')
            .delete()
            .eq('follower_id', currentUserId)
            .eq('following_id', widget.profile.id);

        setState(() {
          _isFollowing = false;
        });
      } else {
        // Takip et
        await supabase.from('follows').insert({
          'follower_id': currentUserId,
          'following_id': widget.profile.id,
          'created_at': DateTime.now().toIso8601String(),
        });

        setState(() {
          _isFollowing = true;
        });
      }
    } catch (error) {
      Logger.error('Toggle follow error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İşlem başarısız: ${error.toString()}'),
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

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: widget.profile.id),
            ),
          );
        },
        child: CircleAvatar(
          backgroundImage: widget.profile.avatarUrl != null
              ? NetworkImage(widget.profile.avatarUrl!)
              : null,
          backgroundColor: const Color(0xFF4CAF50),
          child: widget.profile.avatarUrl == null
              ? const Icon(
                  Icons.person,
                  color: Colors.white,
                )
              : null,
        ),
      ),
      title: Text(
        widget.profile.fullName,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.profile.farmName != null &&
              widget.profile.farmName!.isNotEmpty)
            Text(widget.profile.farmName!),
          if (widget.profile.location != null &&
              widget.profile.location!.isNotEmpty)
            Text(
              widget.profile.location!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
        ],
      ),
      trailing: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF4CAF50),
              ),
            )
          : TextButton(
              onPressed: _toggleFollow,
              style: TextButton.styleFrom(
                backgroundColor: _isFollowing
                    ? const Color(0xFF333333)
                    : const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(_isFollowing ? 'Takip Ediliyor' : 'Takip Et'),
            ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: widget.profile.id),
          ),
        );
      },
    );
  }
}
