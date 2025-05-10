import 'dart:typed_data';
import 'package:koylum/main.dart';
import 'package:koylum/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Realtime API kullanımı için yardımcı fonksiyonlar
class SupabaseHelpers {
  /// Bir tablodaki değişiklikleri dinlemek için kanal oluşturur
  static RealtimeChannel createTableChannel(
    SupabaseClient client,
    String tableName,
    String schema, {
    required String column,
    required String value,
  }) {
    return client.channel('public:$tableName').onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: schema,
          table: tableName,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: column,
            value: value,
          ),
          callback: (payload) {
            // Bu callback'i kullanıcı tarafında işlemek için boş bırakıyoruz
          },
        );
  }

  /// Bir tablodaki değişiklikleri dinlemek için kanal oluşturur ve abone olur
  static RealtimeChannel subscribeToTable(
    SupabaseClient client,
    String tableName,
    String schema, {
    required String column,
    required String value,
    required void Function(Map<String, dynamic>) onInsert,
  }) {
    final channel = client.channel('public:$tableName').onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: schema,
          table: tableName,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: column,
            value: value,
          ),
          callback: (payload) {
            try {
              onInsert(payload.newRecord);
            } catch (e) {
              Logger.error('Realtime callback error:', e);
            }
          },
        );
    
    channel.subscribe();
    return channel;
  }
  
  /// Dosya yükleme yardımcısı
  static Future<String?> uploadFile(String bucket, String path, Uint8List bytes, {String? contentType}) async {
    try {
      await supabase.storage.from(bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType ?? 'application/octet-stream',
          cacheControl: '3600',
        ),
      );
      
      return await supabase.storage.from(bucket).createSignedUrl(path, 60 * 60 * 24 * 365);
    } catch (e) {
      Logger.error('Dosya yükleme hatası:', e);
      return null;
    }
  }
}
