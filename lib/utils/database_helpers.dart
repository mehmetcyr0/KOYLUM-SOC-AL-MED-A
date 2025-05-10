import 'package:koylum/main.dart';
import 'package:koylum/models/profile.dart';
import 'package:koylum/utils/logger.dart';

class DatabaseHelpers {
  /// Kullanıcı profilinin veritabanında var olduğundan emin olur
  static Future<Profile?> ensureProfileExists(String userId,
      {String? fullName, String? email}) async {
    try {
      // Önce profili kontrol et
      final profile = await getProfileById(userId);

      // Profil varsa döndür
      if (profile != null) {
        return profile;
      }

      // Profil yoksa oluştur
      final currentUser = supabase.auth.currentUser;
      final defaultProfile = {
        'id': userId,
        'full_name':
            fullName ?? currentUser?.userMetadata?['full_name'] ?? 'Kullanıcı',
        'email': email ?? currentUser?.email,
        'created_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('profiles').insert(defaultProfile);

      // Yeni oluşturulan profili getir
      return await getProfileById(userId);
    } catch (e) {
      Logger.error('Profil oluşturma hatası:', e);

      // Hata durumunda RPC fonksiyonunu dene
      try {
        await supabase.rpc('create_profile_for_user_manual', params: {
          'user_id': userId,
          'user_full_name': fullName ??
              supabase.auth.currentUser?.userMetadata?['full_name'] ??
              'Kullanıcı',
          'user_email': email ?? supabase.auth.currentUser?.email,
        });

        return await getProfileById(userId);
      } catch (rpcError) {
        Logger.error('RPC profil oluşturma hatası:', rpcError);
        return null;
      }
    }
  }

  /// Profil var mı kontrol eder
  static Future<bool> checkProfileExists(String userId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      Logger.error('Profil kontrol hatası:', e);
      return false;
    }
  }

  /// ID'ye göre profil getirir
  static Future<Profile?> getProfileById(String userId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        return Profile.fromJson(response);
      }

      return null;
    } catch (e) {
      Logger.error('Error getting profile', e);
      return null;
    }
  }

  /// Veritabanı işlemleri başarısız olduğunda yedek profil nesnesi oluşturur
  static Profile createFallbackProfile(String userId) {
    final user = supabase.auth.currentUser;
    return Profile(
      id: userId,
      fullName: user?.userMetadata?['full_name'] ?? 'Kullanıcı',
      createdAt: DateTime.now(),
    );
  }

  /// Gönderi oluşturmadan önce profil kontrolü yapar
  static Future<bool> checkProfileBeforePost(String userId) async {
    try {
      final profileExists = await checkProfileExists(userId);

      if (!profileExists) {
        // Profil yoksa oluştur
        await ensureProfileExists(userId);
        return true;
      }

      return true;
    } catch (e) {
      Logger.error('Profile check error:', e);
      return false;
    }
  }

  /// Hata mesajlarını kullanıcı dostu hale getirir
  static String formatErrorMessage(String error) {
    if (error.contains('foreign key constraint')) {
      return 'Veritabanı ilişki hatası. Lütfen profilinizin oluşturulduğundan emin olun.';
    } else if (error.contains('row-level security policy')) {
      return 'Yetkilendirme hatası. Bu işlemi yapmaya yetkiniz yok.';
    } else if (error.contains('Could not embed')) {
      return 'Veri ilişkilendirme hatası. Lütfen daha sonra tekrar deneyin.';
    } else if (error.contains('Could not find a relationship')) {
      return 'Veri ilişkisi bulunamadı. Lütfen daha sonra tekrar deneyin.';
    } else if (error.contains('Null check operator used on a null value')) {
      return 'Bir değer bulunamadı. Lütfen tüm alanları kontrol edin.';
    }
    return error;
  }

  /// Veritabanı ilişkilerini düzeltir
  static Future<void> fixDatabaseRelationships() async {
    try {
      // RPC fonksiyonu ile ilişkileri düzelt
      await supabase.rpc('fix_database_relationships');
      Logger.info('Veritabanı ilişkileri düzeltildi');
    } catch (e) {
      Logger.error('Veritabanı ilişkilerini düzeltme hatası:', e);
    }
  }
}
