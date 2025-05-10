import 'package:supabase_flutter/supabase_flutter.dart';

/// Veritabanı sorgularını güvenli bir şekilde yönetmek için yardımcı fonksiyonlar
class DbUtils {
  /// Tek bir satır döndürmesi beklenen sorguları güvenli bir şekilde çalıştırır
  static Future<Map<String, dynamic>?> getSingleRow(
      SupabaseClient client, String table, String column, dynamic value,
      {String select = '*'}) async {
    try {
      final response = await client
          .from(table)
          .select(select)
          .eq(column, value)
          .maybeSingle();

      return response;
    } catch (e) {
      // Hata durumunda null döndür
      return null;
    }
  }

  /// Bir tabloya veri ekler ve hata durumunda güvenli bir şekilde işler
  static Future<bool> insertRow(
    SupabaseClient client,
    String table,
    Map<String, dynamic> data,
  ) async {
    try {
      await client.from(table).insert(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Bir tablodaki veriyi günceller ve hata durumunda güvenli bir şekilde işler
  static Future<bool> updateRow(
    SupabaseClient client,
    String table,
    String column,
    dynamic value,
    Map<String, dynamic> data,
  ) async {
    try {
      await client.from(table).update(data).eq(column, value);
      return true;
    } catch (e) {
      return false;
    }
  }
}
