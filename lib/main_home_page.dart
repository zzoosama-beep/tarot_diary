import 'dart:ui'; // ✅ ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../diary/write_diary.dart';
import '../diary/calander_diary.dart';
import '../arcana/write_arcana.dart';
import '../arcana/list_arcana.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../login.dart'; // ✅ 메뉴 진입 시 로그인 요구 (그대로 유지)
import '../backend/auth_service.dart'; // ✅ (방금 만든 파일)

// ✅ withOpacity 대체: 알파 정밀도/워닝 회피용
Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  static const backgroundColor = Color(0xFF2E294E);

  static const String _topPath = 'asset/tarot_diary_maintop.webp';
  static const String _bottomPath = 'asset/tarot_diary_mainbottom.webp';

  @override
  void initState() {
    super.initState();

    // ✅ 첫 프레임 이후에만 미리 디코딩/캐시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final mq = MediaQuery.of(context);
      final dpr = mq.devicePixelRatio;
      final wPx = (mq.size.width * dpr).round();
      final hPx = (mq.size.height * dpr).round();

      final topProvider = ResizeImage(
        const AssetImage(_topPath),
        width: wPx,
      );
      final bottomProvider = ResizeImage(
        const AssetImage(_bottomPath),
        width: wPx,
        height: hPx,
      );

      precacheImage(topProvider, context);
      precacheImage(bottomProvider, context);
    });
  }

  /// ✅ B안: 홈은 구경 OK, 기능 진입(액션) 시 login.dart로 로그인 요구
  Future<void> _openWithLogin(
      BuildContext context,
      Widget page, {
        String? reason,
      }) async {
    final ok = await requireGoogleLogin(
      context,
      title: '로그인이 필요해',
      message: reason ??
          '구글 로그인하면 기기 변경/재설치 후에도 데이터를 안전하게 사용할 수 있어.',
    );
    if (!ok) return;

    if (!context.mounted) return;
    Navigator.of(context).push(_fadeRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final dpr = mq.devicePixelRatio;
    final wPx = (mq.size.width * dpr).round();
    final hPx = (mq.size.height * dpr).round();

    final topProvider = ResizeImage(
      const AssetImage(_topPath),
      width: wPx,
    );

    final bottomProvider = ResizeImage(
      const AssetImage(_bottomPath),
      width: wPx,
      height: hPx,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // =====================================================
          // TOP
          // =====================================================
          RepaintBoundary(
            child: Stack(
              children: [
                Image(
                  image: topProvider,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                ),
                const Positioned(
                  left: 100,
                  top: 70,
                  child: MagicNeonBox(
                    child: NeonMessageText(
                      text: '아직 기록이 없네.\n한 장만 남겨볼까?',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // =====================================================
          // BOTTOM
          // =====================================================
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: Image(
                      image: bottomProvider,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),

                // ✅ 상단 그라데이션 마스크(원본 유지)
                Align(
                  alignment: Alignment.topCenter,
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _a(backgroundColor, 0.80),
                              _a(backgroundColor, 0.00),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                LayoutBuilder(
                  builder: (context, c) {
                    final h = c.maxHeight;

                    const double ratio = 0.42;
                    const double lift = 82.0;
                    final topY = (h * ratio - lift).clamp(0.0, h);

                    final panelW = (c.maxWidth - 44).clamp(0.0, 360.0);

                    final authTopY = (topY - 92).clamp(0.0, h);

                    return Stack(
                      children: [
                        // ✅ 로그인 상태 패널
                        Positioned(
                          left: 0,
                          right: 0,
                          top: authTopY,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                              child: RepaintBoundary(
                                child: _AuthStatusPanel(width: panelW),
                              ),
                            ),
                          ),
                        ),

                        // ✅ 메뉴 패널
                        Positioned(
                          left: 0,
                          right: 0,
                          top: topY,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                              child: RepaintBoundary(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _HomeBigPanel(
                                      width: panelW,
                                      title: '묘한 미래일기',
                                      subtitle: '내일은 어떤 하루가 될지 카드를 뽑고 기록해봐요',
                                      leftAction: _HomeActionCardData(
                                        icon: Icons.edit_note_rounded,
                                        label: '내일의\n타로일기 쓰기',
                                        onTap: () {
                                          _openWithLogin(
                                            context,
                                            const WriteDiaryPage(),
                                            reason:
                                            '일기를 저장/불러오려면 구글 로그인이 필요해.\n(기기 변경/재설치 대비)',
                                          );
                                        },
                                      ),
                                      rightAction: _HomeActionCardData(
                                        icon: Icons.calendar_month_rounded,
                                        label: '내 타로일기\n보관함',
                                        onTap: () {
                                          _openWithLogin(
                                            context,
                                            const CalanderDiaryPage(),
                                            reason: '보관함에서 일기 기록을 관리하려면 구글 로그인이 필요해.',
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _HomeBigPanel(
                                      width: panelW,
                                      title: '비밀의 타로도감',
                                      subtitle: '78장 아르카나의 의미를 차곡차곡 모아봐요',
                                      leftAction: _HomeActionCardData(
                                        icon: Icons.bookmark_add_rounded,
                                        label: '78장 아르카나\n기록하기',
                                        onTap: () {
                                          _openWithLogin(
                                            context,
                                            const WriteArcanaPage(),
                                            reason: '도감 기록은 저장이 들어가서 구글 로그인이 필요해.',
                                          );
                                        },
                                      ),
                                      rightAction: _HomeActionCardData(
                                        icon: Icons.style_rounded,
                                        label: '타로카드\n도감 보기',
                                        onTap: () {
                                          _openWithLogin(
                                            context,
                                            const ListArcanaPage(),
                                            reason: '도감 데이터를 불러오려면 구글 로그인이 필요해.',
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================
/// ✅ 로그인 상태 패널
/// ===============================
class _AuthStatusPanel extends StatelessWidget {
  final double width;
  const _AuthStatusPanel({required this.width});

  static const Color panelBg = Color(0xFF3B3562);
  static const Color panelBg2 = Color(0xFF322D58);

  static const Color goldLine = Color(0xFFE6CF7A);
  static const Color titleGold = Color(0xFFE6CF7A);
  static const Color subText = Color(0xFFC9C2D9);

  @override
  Widget build(BuildContext context) {
    const r = 18.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _a(panelBg, 0.42),
                _a(panelBg2, 0.36),
              ],
            ),
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: _a(goldLine, 0.40), width: 1.1),
          ),
          child: StreamBuilder<User?>(
            stream: AuthService.authStateChanges(),
            builder: (context, snap) {
              final u = snap.data;
              final signedIn = (u != null && !u.isAnonymous);

              final statusTitle = signedIn ? '구글 계정 연결됨 ✅' : '구글 계정 연결 안됨 ❌';
              final sub = signedIn
                  ? 'EMAIL: ${u.email ?? '-'}'
                  : '지금 로그인하면 기기 변경/재설치에도 기록을 안전하게 쓸 수 있어.';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusTitle,
                    style: GoogleFonts.gowunDodum(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: titleGold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.gowunDodum(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w700,
                      color: _a(subText, 0.92),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _AuthMiniButton(
                          label: '구글 로그인',
                          enabled: !signedIn,
                          onTap: () async {
                            try {
                              await AuthService.ensureSignedIn(
                                forceAccountChooser: true,
                                hardDisconnect: false,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('구글 로그인 완료')),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('로그인 실패: $e')),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _AuthMiniButton(
                          label: '로그아웃',
                          enabled: signedIn,
                          onTap: () async {
                            await AuthService.signOut(hardDisconnect: false);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('로그아웃 완료')),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthMiniButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _AuthMiniButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  static const Color tileBg = Color(0xFFD6D2E6);
  static const Color tileBg2 = Color(0xFFCFCADD);
  static const Color ink = Color(0xFF2E294E);
  static const Color goldLine = Color(0xFFE6CF7A);

  @override
  Widget build(BuildContext context) {
    const r = 14.0;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(r),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _a(tileBg, 0.78),
                  _a(tileBg2, 0.70),
                ],
              ),
              borderRadius: BorderRadius.circular(r),
              border: Border.all(color: _a(goldLine, 0.22), width: 1),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.gowunDodum(
                  fontSize: 12.6,
                  fontWeight: FontWeight.w900,
                  color: _a(ink, 0.95),
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================
// ✅ 큰 박스(섹션) + 내부 2컬럼 액션
// =========================================================

class _HomeActionCardData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _HomeActionCardData({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _HomeBigPanel extends StatelessWidget {
  final double width;
  final String title;
  final String subtitle;
  final _HomeActionCardData leftAction;
  final _HomeActionCardData rightAction;

  const _HomeBigPanel({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.leftAction,
    required this.rightAction,
  });

  static const Color panelBg = Color(0xFF3B3562);
  static const Color panelBg2 = Color(0xFF322D58);

  static const Color goldLine = Color(0xFFE6CF7A);
  static const Color goldGlow = Color(0xFFFFE6A3);

  static const Color titleGold = Color(0xFFE6CF7A);
  static const Color subText = Color(0xFFC9C2D9);

  @override
  Widget build(BuildContext context) {
    const r = 22.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _a(panelBg, 0.48),
                _a(panelBg2, 0.40),
              ],
            ),
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: _a(goldLine, 0.58), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: _a(Colors.black, 0.18),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: _a(goldGlow, 0.10),
                blurRadius: 18,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 1.0,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        _a(Colors.white, 0.18),
                        _a(Colors.white, 0.00),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.gowunDodum(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: titleGold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.gowunDodum(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _a(subText, 0.92),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(height: 1, color: _a(Colors.white, 0.06)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _HomeActionTile(data: leftAction)),
                        const SizedBox(width: 12),
                        Expanded(child: _HomeActionTile(data: rightAction)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeActionTile extends StatelessWidget {
  final _HomeActionCardData data;
  const _HomeActionTile({required this.data});

  static const Color tileBg = Color(0xFFD6D2E6);
  static const Color tileBg2 = Color(0xFFCFCADD);
  static const Color ink = Color(0xFF2E294E);
  static const Color goldLine = Color(0xFFE6CF7A);

  @override
  Widget build(BuildContext context) {
    const r = 16.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(r),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _a(tileBg, 0.82),
                    _a(tileBg2, 0.74),
                  ],
                ),
                borderRadius: BorderRadius.circular(r),
                border: Border.all(color: _a(goldLine, 0.28), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: _a(Colors.black, 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(data.icon, size: 18, color: _a(ink, 0.90)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.gowunDodum(
                        fontSize: 13.4,
                        fontWeight: FontWeight.w900,
                        color: ink,
                        height: 1.15,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _a(ink, 0.55),
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

// ---------------------------------------------------------
// ✨ 별 장식 테두리 위젯 (MagicNeonBox) - 원본 유지
// ---------------------------------------------------------
class MagicNeonBox extends StatelessWidget {
  final Widget child;
  const MagicNeonBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: _a(const Color(0xFFF3E5AB), 0.30),
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _a(const Color(0xFF7A5CFF), 0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          const Positioned(
            top: -16,
            left: -10,
            child: Icon(Icons.star, size: 10, color: Color(0xFFF3E5AB)),
          ),
          const Positioned(
            bottom: -16,
            right: -10,
            child: Icon(Icons.star_outline, size: 10, color: Color(0xFFF3E5AB)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// ✅ 페이드 라우트 (유지)
// ---------------------------------------------------------
PageRouteBuilder _fadeRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

class NeonMessageText extends StatefulWidget {
  final String text;
  const NeonMessageText({super.key, required this.text});

  @override
  State<NeonMessageText> createState() => _NeonMessageTextState();
}

class _NeonMessageTextState extends State<NeonMessageText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 6000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final double v = _animation.value;

        final c1 = _a(const Color(0xFFF8F6FF), 0.85);
        final c2 = const Color(0xFFF8F6FF);
        final textColor = Color.lerp(c1, c2, v) ?? c2;

        return Text(
          widget.text,
          style: GoogleFonts.jua(
            fontSize: 15,
            height: 1.4,
            color: textColor,
            shadows: [
              Shadow(
                color: _a(const Color(0xFFBFA8FF), 0.4 + (v * 0.4)),
                blurRadius: 5 + (v * 5),
                offset: const Offset(0, 0),
              ),
              Shadow(
                color: _a(const Color(0xFF7A5CFF), 0.2 + (v * 0.5)),
                blurRadius: 10 + (v * 15),
                offset: const Offset(0, 0),
              ),
            ],
          ),
        );
      },
    );
  }
}
