import 'dart:async'; // unawaited 및 Future 처리를 위해 필요
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth 사용을 위해 추가

import 'backend/firebase_options.dart';
import 'error/error_reporter.dart';
import 'backend/auth_service.dart';
import 'ads/coin_service.dart'; // CoinService 호출을 위해 추가


class BootPage extends StatefulWidget {
  const BootPage({super.key});

  @override
  State<BootPage> createState() => _BootPageState();
}

class _BootPageState extends State<BootPage> {
  @override
  void initState() {
    super.initState();
    // 핵심 수정: 화면이 첫 프레임을 그린 직후(애니메이션 시작 후)에 초기화 로직 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boot();
    });
  }

  Future<void> _boot() async {
    final sw = Stopwatch()..start();

    void log(String msg) {
      if (!kDebugMode) return;
      debugPrint('⏱️ BOOT ${sw.elapsedMilliseconds}ms | $msg');
    }

    try {
      log('Firebase.initializeApp start');
      // 1. Firebase 초기화
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      log('Firebase.initializeApp done');

      // 2. 초기 상태 스냅샷 기록
      unawaited(
        ErrorReporter.I.record(
          source: 'auth.debug.app_start',
          error: 'auth_state_snapshot',
          extra: {
            'firebaseUserExists': FirebaseAuth.instance.currentUser != null,
          },
        ),
      );

      // 3. 세션 복구 및 기타 서비스 초기화
      await AuthService.restoreSessionSilently();
      log('AuthService.restoreSessionSilently done');

      await CoinService.I.init();
      log('CoinService.init done');

    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'BootPage._boot',
        error: e,
        stackTrace: st,
      );
    }

    // 4. 로딩이 너무 빨리 끝나면 애니메이션을 볼 수 없으므로 최소 1초 대기 보장
    if (sw.elapsedMilliseconds < 1000) {
      await Future.delayed(Duration(milliseconds: 1000 - sw.elapsedMilliseconds));
    }

    if (!mounted) return;

    // 홈 화면으로 이동
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF2E294E),
      body: SafeArea(
        child: Center(
          child: _BootLoading(),
        ),
      ),
    );
  }
}

class _BootLoading extends StatefulWidget {
  const _BootLoading();

  @override
  State<_BootLoading> createState() => _BootLoadingState();
}

class _BootLoadingState extends State<_BootLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final shortest = size.shortestSide;
    final longest = size.longestSide;
    final textScaler = MediaQuery.textScalerOf(context);

    final bool isTablet = shortest >= 600;
    final bool isSmallPhone = shortest < 360;
    final bool isLandscape = size.width > size.height;

    final double horizontalPadding = isTablet
        ? 40
        : isLandscape
        ? 24
        : 20;

    final double maxContentWidth = isTablet ? 420 : 300;

    double iconSize = isTablet ? 60 : 44;
    double textSize = isTablet ? 18 : 14;
    double gap1 = isTablet ? 18 : 14;
    double gap2 = isTablet ? 22 : 18;
    double loaderSize = isTablet ? 28 : 22;
    double loaderStroke = isTablet ? 2.8 : 2.0;

    if (isSmallPhone) {
      iconSize = 38;
      textSize = 13;
      gap1 = 12;
      gap2 = 16;
      loaderSize = 20;
      loaderStroke = 1.9;
    }

    final scaledText = textScaler.scale(textSize);
    final bool textVeryLarge = scaledText > textSize * 1.25;

    if (textVeryLarge) {
      iconSize *= 0.92;
      gap1 *= 0.9;
      gap2 *= 0.9;
    }

    if (isLandscape && longest > 0 && size.height < 430) {
      iconSize *= 0.9;
      textSize *= 0.95;
      gap1 = math.max(8, gap1 * 0.7);
      gap2 = math.max(12, gap2 * 0.7);
      loaderSize *= 0.9;
    }

    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_c),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxContentWidth,
              minWidth: math.min(220, size.width - horizontalPadding * 2),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: iconSize,
                    color: const Color(0xFFE6CF7A),
                  ),
                  SizedBox(height: gap1),
                  Text(
                    '달냥이가 준비 중이에요… 🐾',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFE6CF7A),
                      fontSize: textSize,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: gap2),
                  SizedBox(
                    width: loaderSize,
                    height: loaderSize,
                    child: CircularProgressIndicator(
                      strokeWidth: loaderStroke,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFE6CF7A),
                      ),
                    ),
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