import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koylum/main.dart';
import 'package:koylum/utils/logger.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Const constructor kullanımı
final kInputDecoration = const InputDecoration(
  filled: true,
  fillColor: Color(0xFF1E1E1E),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: Color(0xFF333333)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: Color(0xFF4CAF50), width: 2),
  ),
  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
);

class CreateDiaryEntryScreen extends StatefulWidget {
  const CreateDiaryEntryScreen({super.key});

  @override
  State<CreateDiaryEntryScreen> createState() => _CreateDiaryEntryScreenState();
}

class _CreateDiaryEntryScreenState extends State<CreateDiaryEntryScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _activityTypeController = TextEditingController();
  final List<XFile> _selectedImages = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _activityTypeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4CAF50),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  Future<List<String>> _uploadImages() async {
    final List<String> imageUrls = [];

    for (final image in _selectedImages) {
      try {
        final bytes = await image.readAsBytes();
        final fileExt = image.name.split('.').last;
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${imageUrls.length}.$fileExt';
        final filePath = 'diary/$fileName';

        // FileOptions sınıfını doğru şekilde kullanma
        await supabase.storage.from('media').uploadBinary(
              filePath,
              bytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
              ),
            );

        final imageUrl = await supabase.storage
            .from('media')
            .createSignedUrl(filePath, 60 * 60 * 24 * 365 * 10);

        imageUrls.add(imageUrl);
      } catch (e) {
        Logger.error('Image upload error:', e);
      }
    }

    return imageUrls;
  }

  Future<void> _createDiaryEntry() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen başlık ve içerik girin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      List<String> imageUrls = [];

      if (_selectedImages.isNotEmpty) {
        imageUrls = await _uploadImages();
      }

      // Günlük kaydını oluştur
      await supabase.from('diary_entries').insert({
        'user_id': userId,
        'title': title,
        'content': content,
        'date': _selectedDate.toIso8601String().split('T')[0],
        'activity_type': _activityTypeController.text.trim(),
        'media_urls': imageUrls,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Günlük kaydı başarıyla oluşturuldu'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Navigator.pop(context, true); // Yenileme için true döndür
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Günlük kaydı oluşturulamadı: ${error.toString()}'),
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

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Günlük Kaydı'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createDiaryEntry,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF4CAF50),
                    ),
                  )
                : const Text('Kaydet'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarih seçici
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tarih: ${DateFormat('dd MMMM yyyy', 'tr').format(_selectedDate)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Başlık
            TextField(
              controller: _titleController,
              decoration: kInputDecoration.copyWith(
                labelText: 'Başlık',
                prefixIcon: const Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),

            // Aktivite türü
            TextField(
              controller: _activityTypeController,
              decoration: kInputDecoration.copyWith(
                labelText: 'Aktivite Türü',
                hintText: 'Ekim, Hasat, Sulama, vb.',
                prefixIcon: const Icon(Icons.category),
              ),
            ),
            const SizedBox(height: 16),

            // İçerik
            TextField(
              controller: _contentController,
              decoration: kInputDecoration.copyWith(
                labelText: 'İçerik',
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),

            // Seçilen resimler
            if (_selectedImages.isNotEmpty) ...[
              const Text(
                'Seçilen Resimler',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image:
                                  FileImage(File(_selectedImages[index].path)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
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
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Resim ekleme butonu
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.photo),
              label: const Text('Resim Ekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
