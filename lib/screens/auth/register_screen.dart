import 'package:flutter/material.dart';
import 'package:koylum/main.dart';
import 'package:koylum/screens/home/home_screen.dart';
import 'package:koylum/utils/constants.dart';
import 'package:koylum/utils/database_helpers.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Fonksiyonu isimlendirilmiş parametrelerle tanımlama
  Future<void> _createProfile({
    required String userId,
    required String fullName,
    required String email,
  }) async {
    await supabase.from('profiles').insert({
      'id': userId,
      'full_name': fullName,
      'email': email,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final fullName = _nameController.text.trim();
      final email = _emailController.text.trim();

      final response = await supabase.auth.signUp(
        email: email,
        password: _passwordController.text,
        data: {
          'full_name': fullName,
        },
      );

      if (response.user != null) {
        // Kullanıcı profili oluştur - çakışmaları önlemek için upsert kullan
        try {
          // Fonksiyonu çağırırken isimlendirilmiş parametreleri kullanma
          await _createProfile(
            userId: response.user!.id,
            fullName: fullName,
            email: email,
          );
        } catch (profileError) {
          print('Profile creation error: $profileError');

          // RPC fonksiyonunu dene
          try {
            await supabase.rpc('create_profile', params: {
              'user_id': response.user!.id,
              'full_name': fullName,
              'user_email': email,
            });
          } catch (rpcError) {
            print('RPC create_profile error: $rpcError');
          }
        }

        // Profil oluşturulduğundan emin ol
        await DatabaseHelpers.ensureProfileExists(response.user!.id);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } catch (error) {
      print('Registration error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Kayıt başarısız: ${DatabaseHelpers.formatErrorMessage(error.toString())}'),
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
        title: const Text('Kayıt Ol'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Köylüm\'e Katılın',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameController,
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
                    controller: _emailController,
                    decoration: kInputDecoration.copyWith(
                      labelText: 'E-posta',
                      prefixIcon: const Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen e-posta adresinizi girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: kInputDecoration.copyWith(
                      labelText: 'Şifre',
                      prefixIcon: const Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen şifrenizi girin';
                      }
                      if (value.length < 6) {
                        return 'Şifre en az 6 karakter olmalıdır';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Kayıt Ol'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
