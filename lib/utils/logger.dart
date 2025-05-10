// Logger sınıfı oluşturma
class Logger {
  static void debug(String message) {
    // Debug modunda log
    assert(() {
      print('[DEBUG] $message');
      return true;
    }());
  }
  
  static void info(String message) {
    // Bilgi amaçlı log
    assert(() {
      print('[INFO] $message');
      return true;
    }());
  }
  
  static void error(String message, [dynamic error]) {
    // Hata logları
    assert(() {
      print('[ERROR] $message');
      if (error != null) {
        print(error);
      }
      return true;
    }());
  }
}
