import 'dart:ui'; // ✅ ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import 'diary/write_diary.dart';
import 'diary/calander_diary.dart';
import 'arcana/write_arcana.dart';
import 'arcana/list_arcana.dart';

import 'firebase_options.dart';

// ✅ withOpacity 대체: 알파 정밀도/워닝 회피용
Color _a(Color c, double o) => c.withAlpha((o * 255).round());

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TarotDiaryApp());
}

class TarotDiaryApp extends StatelessWidget {
  const TarotDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale('ko', 'KR'),
      supportedLocales: [Locale('ko', 'KR')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MainHomePage(),
    );
  }
}

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  static const backgroundColor = Color(0xFF2E294E);



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              // ✅ TOP (고양이 그림 유지)
              Stack(
                children: [
                  Image.asset(
                    'asset/tarot_diary_maintop.png',
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

              // ✅ BOTTOM (배경 + 메뉴박스)
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'asset/tarot_diary_mainbottom.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),

                    // ✅ 상단 그라데이션 마스크
                    Align(
                      alignment: Alignment.topCenter,
                      child: IgnorePointer(
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

                    LayoutBuilder(
                      builder: (context, c) {
                        final h = c.maxHeight;

                        const double ratio = 0.42;
                        const double lift = 82.0;
                        final topY = (h * ratio - lift).clamp(0.0, h);

                        return Positioned(
                          left: 0,
                          right: 0,
                          top: topY,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                              child: Builder(
                                builder: (context) {
                                  final panelW =
                                  (c.maxWidth - 44).clamp(0.0, 360.0);
                                  const double topGap = 16.0;

                                  return Padding(
                                    padding: const EdgeInsets.only(top: topGap),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _HomeBigPanel(
                                          width: panelW,
                                          titleIcon: Icons.pets_rounded,
                                          title: '묘한 미래일기',
                                          subtitle: '내일은 어떤 하루가 될지 카드를 뽑고 기록해봐요',
                                          leftAction: _HomeActionCardData(
                                            icon: Icons.edit_note_rounded,
                                            label: '내일의\n타로일기 쓰기',
                                            onTap: () {
                                              Navigator.of(context).push(
                                                _fadeRoute(
                                                  const WriteDiaryPage(),
                                                ),
                                              );
                                            },
                                          ),
                                          rightAction: _HomeActionCardData(
                                            icon: Icons.calendar_month_rounded,
                                            label: '내 타로일기\n보관함',
                                            onTap: () {
                                              Navigator.of(context).push(
                                                _fadeRoute(
                                                  const CalanderDiaryPage(),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _HomeBigPanel(
                                          width: panelW,
                                          titleIcon: Icons.auto_stories_rounded,
                                          title: '비밀의 타로도감',
                                          subtitle: '78장 아르카나의 의미를 차곡차곡 모아봐요',
                                          leftAction: _HomeActionCardData(
                                            icon: Icons.bookmark_add_rounded,
                                            label: '78장 아르카나\n기록하기',
                                            onTap: () {
                                              Navigator.of(context).push(
                                                _fadeRoute(
                                                  const WriteArcanaPage(),
                                                ),
                                              );
                                            },
                                          ),
                                          rightAction: _HomeActionCardData(
                                            icon: Icons.style_rounded,
                                            label: '타로카드\n도감 보기',
                                            onTap: () {
                                              Navigator.of(context).push(
                                                _fadeRoute(
                                                  const ListArcanaPage(),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================================
// ✅ 큰 박스(섹션) + 내부 2컬럼 액션 (Gemini + Soft Glass)
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
  final IconData titleIcon; // (현재는 안 씀) 호출부 호환용으로 남김
  final String title;
  final String subtitle;
  final _HomeActionCardData leftAction;
  final _HomeActionCardData rightAction;

  const _HomeBigPanel({
    required this.width,
    required this.titleIcon,
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
              // ✅ 패널 하이라이트 라인
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

              // ✅ 내용
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
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

                    // ✅ 아래 서브메뉴 2개는 그대로
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

  static const Color tileBg  = Color(0xFFD6D2E6);
  static const Color tileBg2 = Color(0xFFCFCADD);
  static const Color ink     = Color(0xFF2E294E);
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
            // ✅ 버튼도 약하게
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
                      style: GoogleFonts.gowunDodum(
                        fontSize: 13.6,
                        fontWeight: FontWeight.w900,
                        color: ink,
                        height: 1.15,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: _a(ink, 0.55)),
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
// ✨ 별 장식 테두리 위젯 (MagicNeonBox)
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
          )
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
// ✅ 페이드 라우트
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
        final textColor = Color.lerp(c1, c2, v)!;

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
