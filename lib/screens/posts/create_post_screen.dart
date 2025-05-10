import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koylum/main.dart';
import 'package:koylum/utils/constants.dart';
import 'package:koylum/utils/database_helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final List<XFile> _selectedImages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
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
        final filePath = 'posts/$fileName';

        await supabase.storage.from('media').uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(
                cacheControl: '3600',
              ),
            );

        final imageUrl = await supabase.storage
            .from('media')
            .createSignedUrl(filePath, 60 * 60 * 24 * 365 * 10);

        imageUrls.add(imageUrl);
      } catch (e) {
        print('Image upload error: $e');
        // Hata durumunda bu resmi atla ve devam et
      }
    }

    return imageUrls;
  }

  Future<void> _createPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir içerik girin'),
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

      // Önce kullanıcı profilinin var olduğundan emin ol
      final profileExists =
          await DatabaseHelpers.checkProfileBeforePost(userId);
      if (!profileExists) {
        throw Exception(
            'Profil oluşturulamadı. Lütfen önce profilinizi düzenleyin.');
      }

      List<String> imageUrls = [];

      if (_selectedImages.isNotEmpty) {
        imageUrls = await _uploadImages();
      }

      // Etiketleri ayır
      final tags = _tagsController.text.isEmpty
          ? []
          : _tagsController.text
              .split(',')
              .map((tag) => tag.trim().replaceAll('#', ''))
              .where((tag) => tag.isNotEmpty)
              .toList();

      // Gönderiyi oluştur
      await supabase.from('posts').insert({
        'user_id': userId,
        'content': content,
        'media_urls': imageUrls,
        'tags': tags,
        'created_at': DateTime.now().toIso8601String(),
        'likes_count': 0,
        'comments_count': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gönderi başarıyla paylaşıldı'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Navigator.pop(context, true); // Yenileme için true döndür
      }
    } catch (error) {
      print('Create post error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Gönderi paylaşılamadı: ${DatabaseHelpers.formatErrorMessage(error.toString())}'),
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
        title: const Text('Yeni Gönderi'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF4CAF50),
                    ),
                  )
                : const Text('Paylaş'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İçerik
            TextField(
              controller: _contentController,
              decoration: kInputDecoration.copyWith(
                hintText: 'Ne düşünüyorsunuz?',
                border: InputBorder.none,
              ),
              maxLines: 5,
              maxLength: 500,
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

            // Etiketler
            TextField(
              controller: _tagsController,
              decoration: kInputDecoration.copyWith(
                labelText: 'Etiketler (virgülle ayırın)',
                hintText: 'örnek, tarım, organik',
                prefixIcon: const Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 16),

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
