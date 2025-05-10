import 'package:flutter/material.dart';
import 'package:koylum/screens/home/feed_screen.dart';
import 'package:koylum/screens/home/messages_screen.dart';
import 'package:koylum/screens/home/notifications_screen.dart';
import 'package:koylum/screens/posts/create_post_screen.dart';
import 'package:koylum/screens/profile/profile_screen.dart';

// FeedScreenState tipini tanımlama
enum HomeScreenState {
  feed,
  notifications,
  messages,
  profile
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _pages;
  final _feedKey = GlobalKey<FeedScreenState>();

  @override
  void initState() {
    super.initState();
    try {
      _pages = [
        FeedScreen(key: _feedKey),
        const NotificationsScreen(),
        const MessagesScreen(),
        const ProfileScreen(),
      ];
    } catch (e) {
      // Fallback in case of initialization errors
      _pages = [
        const Center(child: Text('Ana sayfa yüklenemedi')),
        const Center(child: Text('Bildirimler yüklenemedi')),
        const Center(child: Text('Mesajlar yüklenemedi')),
        const Center(child: Text('Profil yüklenemedi')),
      ];
    }
  }

  Future<void> _navigateToCreatePost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatePostScreen()),
    );

    // Eğer gönderi oluşturulduysa feed'i yenile
    if (result == true && _feedKey.currentState != null) {
      _feedKey.currentState!.refreshFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: const Color(0xFF4CAF50),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Bildirimler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Mesajlar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreatePost,
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add),
      ),
    );
  }
}
