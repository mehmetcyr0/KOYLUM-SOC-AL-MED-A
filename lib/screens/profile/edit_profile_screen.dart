import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koylum/main.dart';
import 'package:koylum/models/profile.dart';
import 'package:koylum/utils/constants.dart';
import 'package:koylum/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _farmNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _farmTypeController = TextEditingController();
  final _productsController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _avatarUrl;
  String? _coverImageUrl;
  XFile? _avatarFile;
  XFile? _coverFile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    _farmNameController.dispose();
    _locationController.dispose();
    _farmTypeController.dispose();
    _productsController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        final profile = Profile.fromJson(response);

        if (!mounted) return;

        setState(() {
          _avatarUrl = profile.avatarUrl;
          _coverImageUrl = profile.coverImageUrl;
          _fullNameController.text = profile.fullName;
          _bioController.text = profile.bio ?? '';
          _farmNameController.text = profile.farmName ?? '';
          _locationController.text = profile.location ?? '';
          _farmTypeController.text = profile.farmType ?? '';
          _productsController.text = profile.products?.join(', ') ?? '';
        });
      } else {
        // Profil yoksa varsayılan değerlerle doldur
        final currentUser = supabase.auth.currentUser;
        if (currentUser != null) {
          final defaultName =
              currentUser.userMetadata?['full_name'] as String? ?? 'Kullanıcı';

          setState(() {
            _fullNameController.text = defaultName;
          });

          // Profil oluştur
          await supabase.from('profiles').insert({
            'id': userId,
            'full_name': defaultName,
            'email': currentUser.email,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (error) {
      Logger.error('Profile load error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profil yüklenemedi: ${error.toString()}'),
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

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 300,
      maxHeight: 300,
    );

    if (imageFile != null) {
      setState(() {
        _avatarFile = imageFile;
      });
    }
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 400,
    );

    if (imageFile != null) {
      setState(() {
        _coverFile = imageFile;
      });
    }
  }

  Future<String?> _uploadImage(XFile file, String folder) async {
    try {
      final bytes = await file.readAsBytes();
      final fileExt = file.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final filePath = '$folder/$fileName';

      await supabase.storage.from('media').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              contentType: 'image/$fileExt',
            ),
          );

      final imageUrlResponse = await supabase.storage
          .from('media')
          .createSignedUrl(filePath, 60 * 60 * 24 * 365 * 10);

      return imageUrlResponse;
    } catch (error) {
      Logger.error('Image upload error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resim yüklenemedi: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      String? newAvatarUrl = _avatarUrl;
      String? newCoverImageUrl = _coverImageUrl;

      // Profil fotoğrafını yükle
      if (_avatarFile != null) {
        newAvatarUrl = await _uploadImage(_avatarFile!, 'avatars');
      }

      // Kapak fotoğrafını yükle
      if (_coverFile != null) {
        newCoverImageUrl = await _uploadImage(_coverFile!, 'covers');
      }

      // Ürünleri diziye dönüştür
      final productsText = _productsController.text.trim();
      final List<String> products = productsText.isEmpty
          ? []
          : productsText.split(',').map((e) => e.trim()).toList();

      // Profili güncelle
      await supabase.from('profiles').update({
        'full_name': _fullNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'farm_name': _farmNameController.text.trim(),
        'location': _locationController.text.trim(),
        'farm_type': _farmTypeController.text.trim(),
        'products': products,
        'avatar_url': newAvatarUrl,
        'cover_image_url': newCoverImageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil başarıyla güncellendi'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (error) {
      Logger.error('Profile update error:', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profil güncellenemedi: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kapak fotoğrafı
                    GestureDetector(
                      onTap: _pickCoverImage,
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF333333),
                          image: _coverFile != null
                              ? DecorationImage(
                                  image: FileImage(
                                    File(_coverFile!.path),
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : _coverImageUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_coverImageUrl!),
                                      fit: BoxFit.cover,
                                      onError: (exception, stackTrace) {
                                        // Hata durumunda sessizce işle
                                      },
                                    )
                                  : null,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white.withOpacity(0.7),
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    // Profil fotoğrafı
                    Center(
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: Container(
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
                            image: _avatarFile != null
                                ? DecorationImage(
                                    image: FileImage(
                                      File(_avatarFile!.path),
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : _avatarUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_avatarUrl!),
                                        fit: BoxFit.cover,
                                        onError: (exception, stackTrace) {
                                          // Hata durumunda sessizce işle
                                        },
                                      )
                                    : null,
                          ),
                          child: (_avatarFile == null && _avatarUrl == null)
                              ? const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Form alanları
                    const Text(
                      'Kişisel Bilgiler',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: kInputDecoration.copyWith(
                        labelText: 'Ad Soyad',
                        prefixIcon: const Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen adınızı ve soyadınızı girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      decoration: kInputDecoration.copyWith(
                        labelText: 'Biyografi',
                        prefixIcon: const Icon(Icons.info),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Çiftlik Bilgileri',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _farmNameController,
                      decoration: kInputDecoration.copyWith(
                        labelText: 'Çiftlik Adı',
                        prefixIcon: const Icon(Icons.agriculture),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: kInputDecoration.copyWith(
                        labelText: 'Konum',
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _farmTypeController,
                      decoration: kInputDecoration.copyWith(
                        labelText: 'Çiftlik Türü (Organik, Sera, vb.)',
                        prefixIcon: const Icon(Icons.category),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _productsController,
                      decoration: kInputDecoration.copyWith(
                        labelText: 'Ürünler (virgülle ayırın)',
                        prefixIcon: const Icon(Icons.eco),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
