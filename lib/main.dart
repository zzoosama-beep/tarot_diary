import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import 'write_diary.dart';
import 'calander_diary.dart';
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

enum _HomeMenu { none, future, guide }

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  static const backgroundColor = Color(0xFF2E294E);
  _HomeMenu _open = _HomeMenu.none;

  void _toggle(_HomeMenu target) {
    setState(() {
      _open = (_open == target) ? _HomeMenu.none : target;
    });
  }

  void _closeMenu() {
    if (_open == _HomeMenu.none) return;
    setState(() => _open = _HomeMenu.none);
  }

  @override
  Widget build(BuildContext context) {
    final bool isAnyOpen = _open != _HomeMenu.none;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // ✅ 1) 딤레이어를 먼저 (뒤에 깔기)
          if (isAnyOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeMenu,
                child: Container(
                  color: _a(Colors.black, 0.12),
                ),
              ),
            ),

          // ✅ 2) 실제 UI는 그 위에
          Column(
            children: [
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
                        const collapsedHalf = 65.0;
                        final topY = (h * 0.5 - collapsedHalf).clamp(0.0, h);

                        return Stack(
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              top: topY,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ExpandableHomeButton(
                                    width: 250,
                                    label: '묘한 미래일기',
                                    isOpen: _open == _HomeMenu.future,
                                    onHeaderTap: () => _toggle(_HomeMenu.future),
                                    actions: [
                                      _HomeAction(
                                        icon: Icons.pets_rounded,
                                        label: '내일의 타로일기 쓰기',
                                        onTap: () {
                                          _closeMenu();
                                          Navigator.of(context).push(
                                            _fadeRoute(const WriteDiaryPage()),
                                          );
                                        },
                                      ),
                                      _HomeAction(
                                        icon: Icons.pets_rounded,
                                        label: '내 타로일기 보관함',
                                        onTap: () {
                                          _closeMenu();
                                          Navigator.of(context).push(
                                            _fadeRoute(const CalanderDiaryPage()),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _ExpandableHomeButton(
                                    width: 250,
                                    label: '비밀의 타로도감',
                                    isOpen: _open == _HomeMenu.guide,
                                    onHeaderTap: () => _toggle(_HomeMenu.guide),
                                    actions: [
                                      _HomeAction(
                                        icon: Icons.pets_rounded,
                                        label: '78장 아르카나 기록하기',
                                        onTap: _closeMenu,
                                      ),
                                      _HomeAction(
                                        icon: Icons.pets_rounded,
                                        label: '타로카드 도감',
                                        onTap: _closeMenu,
                                      ),
                                    ],
                                  ),
                                ],
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
        ],
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

class _HomeAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _HomeAction({required this.icon, required this.label, required this.onTap});
}

class _ExpandableHomeButton extends StatelessWidget {
  final double width;
  final String label;
  final bool isOpen;
  final VoidCallback onHeaderTap;
  final List<_HomeAction> actions;

  const _ExpandableHomeButton({
    required this.width,
    required this.label,
    required this.isOpen,
    required this.onHeaderTap,
    required this.actions,
  });

  static const Color scrollInk = Color(0xFF433422);
  static const Color paperColor = Color(0xFFF2E6CE);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MenuHeaderButton(
          width: width,
          label: label,
          isOpen: isOpen,
          onTap: onHeaderTap,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 500),
          curve: Curves.fastLinearToSlowEaseIn,
          alignment: Alignment.topCenter,
          child: isOpen
              ? Container(
            width: width,
            decoration: BoxDecoration(
              color: paperColor,
              borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(15)),
              boxShadow: [
                BoxShadow(
                  color: _a(Colors.black, 0.20),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 2,
                  width: double.infinity,
                  color: _a(Colors.black, 0.05),
                ),
                ...actions.map((action) {
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: action.onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 15,
                        ),
                        child: Row(
                          children: [
                            Transform.rotate(
                              angle: -0.2,
                              child: Icon(
                                action.icon,
                                color: _a(scrollInk, 0.70),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                action.label,
                                style: GoogleFonts.gowunDodum(
                                  color: scrollInk,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(15)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFD9C5A0),
                        Color(0xFFC7B18A),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _MenuHeaderButton extends StatelessWidget {
  final double width;
  final String label;
  final bool isOpen;
  final VoidCallback onTap;

  const _MenuHeaderButton({
    required this.width,
    required this.label,
    required this.isOpen,
    required this.onTap,
  });

  static const Color gold = Color(0xFFD4AF37);
  static const Color ink = Color(0xFFF3E5AB);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(width, 54),
        backgroundColor: _a(Colors.white, 0.08),
        side: BorderSide(color: _a(gold, 0.90), width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: isOpen
              ? const BorderRadius.vertical(top: Radius.circular(15))
              : BorderRadius.circular(15),
        ),
        padding: EdgeInsets.zero,
      ),
      child: SizedBox(
        width: width,
        height: 54,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: const Offset(-8, 0),
                child: Text(
                  label,
                  style: GoogleFonts.gowunDodum(
                    color: ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedRotation(
                  turns: isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: _a(ink, 0.95),
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

        // ✅ 기존: Color.lerp(a.withOpacity, b, v)
        // -> withOpacity 제거 버전으로 치환
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
