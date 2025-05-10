import 'package:flutter/material.dart';
import 'package:koylum/main.dart';
import 'package:koylum/models/diary_entry.dart';
import 'package:koylum/screens/diary/create_diary_entry_screen.dart';
import 'package:koylum/utils/logger.dart';
import 'package:koylum/widgets/diary_entry_card.dart';

class FarmDiaryScreen extends StatefulWidget {
  final String? userId;

  const FarmDiaryScreen({super.key, this.userId});

  @override
  State<FarmDiaryScreen> createState() => _FarmDiaryScreenState();
}

class _FarmDiaryScreenState extends State<FarmDiaryScreen> {
  List<DiaryEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDiaryEntries();
  }

  String get _userId => widget.userId ?? supabase.auth.currentUser!.id;

  bool get _isCurrentUser =>
      widget.userId == null || widget.userId == supabase.auth.currentUser!.id;

  Future<void> _loadDiaryEntries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('diary_entries')
          .select('*, profiles(*)')
          .eq('user_id', _userId)
          .order('date', ascending: false);

      // Null-aware assignment ve is! operatörü kullanımı
      // ignore: unnecessary_type_check
      final entries = response is List
          ? response.map((entry) => DiaryEntry.fromJson(entry)).toList()
          : <DiaryEntry>[];

      setState(() {
        _entries = entries;
      });
    } catch (error) {
      Logger.error('Diary entries loading error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Günlük kayıtları yüklenemedi: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _entries = [];
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToCreateDiaryEntry() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateDiaryEntryScreen()),
    );

    // Eğer günlük kaydı oluşturulduysa listeyi yenile
    if (result == true) {
      _loadDiaryEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Henüz çiftlik günlüğü kaydı yok'),
                      if (_isCurrentUser) const SizedBox(height: 16),
                      if (_isCurrentUser)
                        ElevatedButton(
                          onPressed: _navigateToCreateDiaryEntry,
                          child: const Text('Yeni Kayıt Ekle'),
                        ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDiaryEntries,
                  color: const Color(0xFF4CAF50),
                  child: ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      return DiaryEntryCard(entry: _entries[index]);
                    },
                  ),
                ),
      floatingActionButton: _isCurrentUser
          ? FloatingActionButton(
              onPressed: _navigateToCreateDiaryEntry,
              backgroundColor: const Color(0xFF4CAF50),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
