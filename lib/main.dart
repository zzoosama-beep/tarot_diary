import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'main_home_page.dart';
import 'boot_page.dart';

import 'package:tarot_diary/arcana/list_arcana.dart';
import 'package:tarot_diary/arcana/write_arcana.dart';
import 'package:tarot_diary/backup/drive_backup_service.dart';
import 'package:tarot_diary/ads/coin_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PaintingBinding.instance.imageCache.maximumSize = 80;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 << 20;

  await CoinService.I.init();

  try {
    await DriveBackupService.I.backupIfNeeded(
      interactiveIfNeeded: false,
    );
  } catch (_) {
    // 앱 시작 흐름 방해하지 않도록 무시
  }

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
        '/': (_) => const BootPage(),
        '/home': (_) => const MainHomePage(),
        '/list_arcana': (_) => const ListArcanaPage(),
        '/write_arcana': (_) => const WriteArcanaPage(),
      },
    );
  }
}