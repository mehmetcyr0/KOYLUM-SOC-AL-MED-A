import 'package:flutter/material.dart';
import 'package:koylum/main.dart';
import 'package:koylum/models/profile.dart';
import 'package:koylum/screens/profile/profile_screen.dart';
import 'package:koylum/utils/database_helpers.dart';
import 'package:koylum/utils/logger.dart';

class FollowersScreen extends StatefulWidget {
  final String userId;
  final bool isFollowers; // true: takipçiler, false: takip edilenler

  const FollowersScreen({
    super.key,
    required this.userId,
    required this.isFollowers,
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  List<Profile> _profiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = widget.isFollowers
          ? await supabase
              .from('follows')
              .select('follower_id')
              .eq('following_id', widget.userId)
          : await supabase
              .from('follows')
              .select('following_id')
              .eq('follower_id', widget.userId);

      if (response.isNotEmpty) {
        final userIds = widget.isFollowers
            ? response.map((item) => item['follower_id'] as String).toList()
            : response.map((item) => item['following_id'] as String).toList();

        final profiles = <Profile>[];
        for (final userId in userIds) {
          final profile = await DatabaseHelpers.getProfileById(userId);
          if (profile != null) {
            profiles.add(profile);
          }
        }

        setState(() {
          _profiles = profiles;
        });
      }
    } catch (error) {
      Logger.error('Load profiles error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profiller yüklenemedi: ${error.toString()}'),
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
        title: Text(widget.isFollowers ? 'Takipçiler' : 'Takip Edilenler'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
              ? Center(
                  child: Text(
                    widget.isFollowers
                        ? 'Henüz takipçi yok'
                        : 'Henüz takip edilen kullanıcı yok',
                  ),
                )
              : ListView.builder(
                  itemCount: _profiles.length,
                  itemBuilder: (context, index) {
                    final profile = _profiles[index];
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProfileScreen(userId: profile.id),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
