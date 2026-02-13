import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../diary/write_diary.dart';
import '../diary/calander_diary.dart';

import '../backend/diary_repo.dart';
import '../arcana/arcana_labels.dart';

Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> with SingleTickerProviderStateMixin {
  // assets
  static const String _bgBottom = 'asset/main_bottom.webp';
  static const String _topHero = 'asset/main_top.webp';
  static const String _cardBack = 'asset/cards/back.png';

  static const String _iconWriteDiary = 'asset/icon_write_diary.png';
  static const String _iconListDiary = 'asset/icon_list_diary.png';
  static const String _iconArcana = 'asset/icon_arcana.png';

  // tone
  static const Color _cardTint = Color(0xFF6C63FF);
  static const Color _glowPurple = Color(0xFF7C5CFF);

  // ✅ “너무 밝음” 해결: 박스 기본 톤(일관 규격)
  static const double _panelAlpha = 0.09;
  static const double _panelBorderAlpha = 0.10;
  static const double _rootAlpha = 0.05;

  // layout
  static const double _topRatio = 0.44;

  List<String> _todayCardAssets = const [];

  // ✅ Hot-reload 안전: nullable controller + fallback anim
  AnimationController? _sparkleCtrl;

  @override
  void initState() {
    super.initState();
    _sparkleCtrl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _loadTodayDiaryCards();
  }

  @override
  void dispose() {
    _sparkleCtrl?.dispose();
    _sparkleCtrl = null;
    super.dispose();
  }

  void _updateSparkleState() {
    final c = _sparkleCtrl;
    if (c == null) return;

    final shouldSparkle = _todayCardAssets.isEmpty;
    if (shouldSparkle) {
      if (!c.isAnimating) c.repeat();
    } else {
      if (c.isAnimating) c.stop();
      c.value = 0;
    }
  }

  Future<void> _loadTodayDiaryCards() async {
    final today = DateTime.now();
    final dateOnly = DiaryRepo.I.dateOnly(today);

    try {
      final doc = await DiaryRepo.I.read(date: dateOnly);

      List<String> paths = [];
      if (doc != null) {
        final cardsDynamic = doc['cards'];
        if (cardsDynamic is List) {
          final ids = cardsDynamic.map((e) => (e as num).toInt()).toList();
          paths = ids
              .where((id) => id >= 0 && id < ArcanaLabels.kTarotFileNames.length)
              .map((id) => 'asset/cards/${ArcanaLabels.kTarotFileNames[id]}')
              .toList();
        }
      }

      if (!mounted) return;
      setState(() => _todayCardAssets = paths.take(3).toList());
      _updateSparkleState();
    } catch (_) {
      if (!mounted) return;
      setState(() => _todayCardAssets = const []);
      _updateSparkleState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topH = size.height * _topRatio;

    final sparkleAnim = _sparkleCtrl ?? const AlwaysStoppedAnimation<double>(0.0);

    return Scaffold(
      body: Stack(
        children: [
          // 🌌 배경
          Positioned.fill(
            child: Image.asset(_bgBottom, fit: BoxFit.cover),
          ),

          // ✅ TOP
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topH,
            child: Image.asset(
              _topHero,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.high,
            ),
          ),

          // ✅ BOTTOM
          Positioned(
            top: topH,
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
                        child: Container(
                          width: double.infinity,
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),

                          // ✅ 바닥 레이어
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.zero,
                            border: Border.all(
                              color: _a(Colors.white, 0.02),
                              width: 1,
                            ),
                          ),

                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // ✅ 오늘의 카드 박스 위로
                              Transform.translate(
                                offset: const Offset(0, -22),
                                child: _PredictionSection(
                                  label: '오늘의 카드',
                                  glowPurple: _glowPurple,
                                  cardBackAsset: _cardBack,
                                  cardAssets: _todayCardAssets,
                                  cardTint: _cardTint,
                                  panelAlpha: _panelAlpha,
                                  borderAlpha: _panelBorderAlpha,
                                  sparkle: _todayCardAssets.isEmpty,
                                  sparkleAnim: sparkleAnim,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const CalanderDiaryPage()),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 4),

                              // ✅ 메뉴 전체를 같이 위로 살짝 올려 균형 맞춤
                              Transform.translate(
                                offset: const Offset(0, -12),
                                child: Column(
                                  children: [
                                    _MainMenuIconItem(
                                      iconAsset: _iconWriteDiary,
                                      label: ' 내일 타로일기 쓰기',
                                      glowPurple: _glowPurple,
                                      panelAlpha: _panelAlpha,
                                      borderAlpha: _panelBorderAlpha,
                                      level: _MenuLevel.normal,
                                      // ✅ 아이콘별 개별 조절
                                      iconBoxSize: 44,     // 펜/일기장은 체감이 커서 조금 작게
                                      iconLeftPad: 6,      // 왼쪽 붙는 느낌 완화
                                      onTap: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const WriteDiaryPage()),
                                        );
                                        if (!mounted) return;
                                        _loadTodayDiaryCards();
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _MainMenuIconItem(
                                      iconAsset: _iconListDiary,
                                      label: ' 타로일기 보관함',
                                      glowPurple: _glowPurple,
                                      panelAlpha: _panelAlpha,
                                      borderAlpha: _panelBorderAlpha,
                                      level: _MenuLevel.normal,
                                      // ✅ 아이콘별 개별 조절
                                      iconBoxSize: 40,     // 캘린더는 정사각이라 기본
                                      iconLeftPad: 6,
                                      onTap: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const CalanderDiaryPage()),
                                        );
                                        if (!mounted) return;
                                        _loadTodayDiaryCards();
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _MainMenuIconItem(
                                      iconAsset: _iconArcana,
                                      label: ' 아르카나 도감',
                                      glowPurple: _glowPurple,
                                      panelAlpha: _panelAlpha,
                                      borderAlpha: _panelBorderAlpha,
                                      level: _MenuLevel.last,
                                      // ✅ 아이콘별 개별 조절
                                      iconBoxSize: 40,     // 카드는 퍼져서 작아 보이니 살짝 키움
                                      iconLeftPad: 6,
                                      onTap: () => Navigator.of(context).pushNamed('/list_arcana'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionSection extends StatelessWidget {
  final String label;
  final Color glowPurple;
  final String cardBackAsset;
  final List<String> cardAssets;
  final Color cardTint;
  final VoidCallback onTap;

  final double panelAlpha;
  final double borderAlpha;

  // ✅ 오늘 카드 없을 때 샤인 효과
  final bool sparkle;
  final Animation<double> sparkleAnim;

  const _PredictionSection({
    required this.label,
    required this.glowPurple,
    required this.cardBackAsset,
    required this.cardAssets,
    required this.cardTint,
    required this.onTap,
    required this.panelAlpha,
    required this.borderAlpha,
    required this.sparkle,
    required this.sparkleAnim,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final cardW = size.width * 0.18;
    final cardH = cardW * 1.55;

    final showBackOnly = cardAssets.isEmpty;
    final items = showBackOnly ? [cardBackAsset] : cardAssets.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _a(const Color(0xFFEFE6FF), 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _a(Colors.white, borderAlpha), width: 1),
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: _a(const Color(0xFFB58CFF), 0.18),
            blurRadius: 44,
            spreadRadius: -16,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ 라벨
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 14,
                color: _a(Colors.white, 0.82),
                shadows: [
                  Shadow(
                    color: _a(glowPurple, 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.notoSansKr(
                  fontSize: 12.6,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.15,
                  color: const Color(0xFFF6EEFF),
                  shadows: [
                    Shadow(
                      color: _a(Colors.black, 0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
              if (sparkle) ...[
                const SizedBox(width: 8),
                _TinySparkleDot(anim: sparkleAnim, glow: glowPurple),
              ],
            ],
          ),
          const SizedBox(height: 12),

          GestureDetector(
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) {
                final path = items[i];
                return Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
                  child: _AnimatedCardTile(
                    assetPath: path,
                    width: cardW,
                    height: cardH,
                    glow: glowPurple,
                    showBackOnly: showBackOnly,
                    cardTint: cardTint,
                    enableSparkle: sparkle && showBackOnly,
                    sparkleAnim: sparkleAnim,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ 카드 탭 시 살짝 확대 + (프레스/호버) 글로우
class _AnimatedCardTile extends StatefulWidget {
  final String assetPath;
  final double width;
  final double height;
  final Color glow;
  final bool showBackOnly;
  final Color cardTint;

  final bool enableSparkle;
  final Animation<double> sparkleAnim;

  const _AnimatedCardTile({
    required this.assetPath,
    required this.width,
    required this.height,
    required this.glow,
    required this.showBackOnly,
    required this.cardTint,
    required this.enableSparkle,
    required this.sparkleAnim,
  });

  @override
  State<_AnimatedCardTile> createState() => _AnimatedCardTileState();
}

class _AnimatedCardTileState extends State<_AnimatedCardTile> {
  bool _pressed = false;
  bool _hover = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final double scale = _pressed ? 1.06 : 1.0;
    final double glowBoost = (_pressed || _hover) ? 1.0 : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _a(Colors.black, 0.22),
                  blurRadius: 20 + (glowBoost * 6),
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: _a(widget.glow, 0.10 + (glowBoost * 0.12)),
                  blurRadius: 22 + (glowBoost * 18),
                  spreadRadius: -14,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Image.asset(
                    widget.assetPath,
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        width: widget.width,
                        height: widget.height,
                        color: _a(Colors.white, 0.08),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.image_not_supported,
                          color: _a(Colors.white, 0.55),
                        ),
                      );
                    },
                  ),

                  Positioned.fill(
                    child: Container(color: widget.cardTint.withOpacity(0.07)),
                  ),

                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _a(Colors.black, 0.03),
                            _a(Colors.black, 0.10),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _a(Colors.white, 0.08),
                            _a(Colors.white, 0.00),
                            _a(Colors.white, 0.00),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (widget.enableSparkle)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: widget.sparkleAnim,
                          builder: (_, __) {
                            final t = widget.sparkleAnim.value;
                            final x = (-0.6 + 1.2 * t) * widget.width;
                            return Transform.translate(
                              offset: Offset(x, 0),
                              child: Transform.rotate(
                                angle: -0.25,
                                child: Container(
                                  width: widget.width * 0.45,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        _a(Colors.white, 0.00),
                                        _a(const Color(0xFFF7F0FF), 0.24),
                                        _a(Colors.white, 0.00),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  if (glowBoost > 0.0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _a(const Color(0xFFEFE6FF), 0.28),
                              width: 1,
                            ),
                          ),
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

class _TinySparkleDot extends StatelessWidget {
  final Animation<double> anim;
  final Color glow;

  const _TinySparkleDot({required this.anim, required this.glow});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = anim.value;
        final pulse = 0.55 + 0.45 * math.sin(t * math.pi * 2);
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _a(const Color(0xFFF7F0FF), 0.32 + 0.18 * pulse),
            boxShadow: [
              BoxShadow(
                color: _a(glow, 0.14 + 0.14 * pulse),
                blurRadius: 10 + 10 * pulse,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _MenuLevel { normal, last }

class _MainMenuIconItem extends StatelessWidget {
  final String iconAsset;
  final String label;
  final Color glowPurple;
  final VoidCallback onTap;
  final _MenuLevel level;

  final double panelAlpha;
  final double borderAlpha;

  // ✅ 아이콘마다 개별 조절
  final double iconBoxSize; // 컨테이너 사이즈
  final double iconLeftPad; // 왼쪽 여백(붙는 느낌 완화)
  final double iconGap; // 아이콘-텍스트 간격

  const _MainMenuIconItem({
    required this.iconAsset,
    required this.label,
    required this.glowPurple,
    required this.onTap,
    required this.panelAlpha,
    required this.borderAlpha,
    this.level = _MenuLevel.normal,
    this.iconBoxSize = 46,
    this.iconLeftPad = 6,
    this.iconGap = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = level == _MenuLevel.last;

    final shadows = isLast
        ? [
      BoxShadow(
        color: _a(Colors.black, 0.10),
        blurRadius: 14,
        offset: const Offset(0, 7),
      ),
      BoxShadow(
        color: _a(glowPurple, 0.09),
        blurRadius: 20,
        spreadRadius: -14,
        offset: const Offset(0, 7),
      ),
    ]
        : [
      BoxShadow(
        color: _a(Colors.black, 0.12),
        blurRadius: 16,
        offset: const Offset(0, 9),
      ),
      BoxShadow(
        color: _a(glowPurple, 0.11),
        blurRadius: 24,
        spreadRadius: -14,
        offset: const Offset(0, 8),
      ),
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: _a(Colors.white, panelAlpha),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _a(Colors.white, borderAlpha), width: 1),
          boxShadow: shadows,
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: iconLeftPad),
              child: SizedBox(
                width: iconBoxSize,
                height: iconBoxSize,
                child: Image.asset(
                  iconAsset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.apps, size: 34, color: _a(Colors.white, 0.75)),
                ),
              ),
            ),
            SizedBox(width: iconGap),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.notoSansKr(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE9DCFF),
                  shadows: [
                    Shadow(
                      color: _a(Colors.black, 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: _a(Colors.white, 0.55)),
          ],
        ),
      ),
    );
  }
}
