import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'backend/firebase_options.dart';

class BootPage extends StatefulWidget {
  const BootPage({super.key});

  @override
  State<BootPage> createState() => _BootPageState();
}

class _BootPageState extends State<BootPage> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final sw = Stopwatch()..start();
    void log(String msg) => debugPrint('⏱️ BOOT ${sw.elapsedMilliseconds}ms | $msg');

    try {
      log('Firebase.initializeApp start');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      log('Firebase.initializeApp done');
    } catch (e, st) {
      log('Firebase.initializeApp ERROR: $e');
      debugPrint('$st');
    }

    if (!mounted) return;

    // ✅ 홈으로 교체(뒤로가기 시 부트로 안 돌아오게)
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 최대한 가벼운 로딩 화면(여기 무거우면 의미 없음)
    return const Scaffold(
      backgroundColor: Color(0xFF2E294E),
      body: Center(
        child: _BootLoading(),
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
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_c),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 44, color: Color(0xFFE6CF7A)),
          SizedBox(height: 14),
          Text(
            '달냥이가 준비 중이야… 🐾',
            style: TextStyle(
              color: Color(0xFFE6CF7A),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 18),
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    );
  }
}
