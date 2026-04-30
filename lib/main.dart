import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // 추가

import 'main_home_page.dart';
import 'boot_page.dart';
import 'backend/firebase_options.dart'; // 추가

import 'package:tarot_diary/arcana/list_arcana.dart';
import 'package:tarot_diary/arcana/write_arcana.dart';
import 'package:tarot_diary/ads/coin_service.dart';
import 'package:tarot_diary/error/error_reporter.dart';

Future<void> main() async {
  // 1. 플러터 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 화면 방향 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 3. 파이어베이스 초기화 (이게 FirebaseAuth보다 먼저 실행되어야 합니다)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    // 초기화 실패 시 기록
    debugPrint('Firebase initialization failed: $e');
  }

  // 4. 초기 상태 로그 기록 (Firebase 초기화 이후이므로 에러가 나지 않습니다)
  unawaited(
    ErrorReporter.I.record(
      source: 'auth.debug.app_start',
      error: 'auth_state_snapshot',
      extra: {
        'firebaseEmail': FirebaseAuth.instance.currentUser?.email,
        'firebaseUid': FirebaseAuth.instance.currentUser?.uid,
        'firebaseUserExists': FirebaseAuth.instance.currentUser != null,
      },
    ),
  );

  // 이미지 캐시 설정
  PaintingBinding.instance.imageCache.maximumSize = 80;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 << 20;

  // 5. 코인 서비스 초기화
  // 만약 여기서 앱이 멈춘다면 await를 제거하고 비동기로 실행하세요.
  await CoinService.I.init();

  runApp(const TarotDiaryApp());
}

class TarotDiaryApp extends StatelessWidget {
  const TarotDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // 한국어 설정
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 라우트 설정
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