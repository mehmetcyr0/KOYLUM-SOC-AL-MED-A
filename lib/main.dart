import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:koylum/screens/splash_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago/timeago.dart' as timeago;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lgdtxvzghcuhzwzkjqdz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxnZHR4dnpnaGN1aHp3emtqcWR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ3NjE2OTAsImV4cCI6MjA2MDMzNzY5MH0.UuyvHPavskg66tJHp4SNuE0iqn7xnvGRj-QQMEXcPLY',
  );

  // Türkçe tarih formatları için
  await initializeDateFormatting('tr_TR', null);

  // Timeago için Türkçe dil desteği
  timeago.setLocaleMessages('tr', timeago.TrMessages());

  runApp(const KoylumApp());
}

final supabase = Supabase.instance.client;

class KoylumApp extends StatelessWidget {
  const KoylumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Köylüm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF4CAF50),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4CAF50),
          ),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
      locale: const Locale('tr', 'TR'),
      home: const SplashScreen(),
    );
  }
}
