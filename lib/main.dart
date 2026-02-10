import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'main_home_page.dart';
import 'boot_page.dart';

import 'package:tarot_diary/arcana/list_arcana.dart';
import 'package:tarot_diary/arcana/write_arcana.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TarotDiaryApp());
}

class TarotDiaryApp extends StatelessWidget {
  const TarotDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/',
      routes: {
        '/': (_) => const BootPage(), // ✅ 여기서 준비 끝나면 MainHomePage로 교체
        '/home': (_) => const MainHomePage(),
        '/list_arcana': (_) => const ListArcanaPage(),
        '/write_arcana': (_) => const WriteArcanaPage(),
      },
    );
  }
}
