// lib/main_home_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../diary/write_diary_one.dart';
import '../diary/calander_diary.dart';

import '../backend/diary_repo.dart';
import '../arcana/arcana_labels.dart';
import '../theme/app_theme.dart';

Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  // assets
  static const String _bgBottom = 'asset/main_bottom.webp';
  static const String _topHero = 'asset/main_top.webp';

  static const String _iconWriteDiary = 'asset/icon_write_diary.png';
  static const String _iconListDiary = 'asset/icon_list_diary.png';
  static const String _iconArcana = 'asset/icon_arcana.png';

  // tone
  static const Color _cardTint = Color(0xFF6C63FF);
  static const Color _glowPurple = Color(0xFF7C5CFF);

  // ✅ “너무 밝음” 해결: 박스 기본 톤(일관 규격)
  static const double _panelAlpha = 0.09;
  static const double _panelBorderAlpha = 0.10;

  // layout
  static const double _topRatio = 0.44;

  List<String> _todayCardAssets = const [];
  String _todayBeforeText = '';

  @override
  void initState() {
    super.initState();
    _loadTodayDiary();
  }

  Future<void> _loadTodayDiary() async {
    final today = DateTime.now();
    final dateOnly = DiaryRepo.I.dateOnly(today);

    try {
      final doc = await DiaryRepo.I.read(date: dateOnly);

      List<String> paths = [];
      String beforeText = '';

      if (doc != null) {
        // cards
        final cardsDynamic = doc['cards'];
        if (cardsDynamic is List) {
          final ids = cardsDynamic.map((e) => (e as num).toInt()).toList();
          paths = ids
              .where(
                  (id) => id >= 0 && id < ArcanaLabels.kTarotFileNames.length)
              .map((id) => 'asset/cards/${ArcanaLabels.kTarotFileNames[id]}')
              .toList();
        }

        // before text (today prediction)
        final bt = doc['beforeText'];
        if (bt is String) beforeText = bt;
      }

      if (!mounted) return;
      setState(() {
        _todayCardAssets = paths.take(3).toList();
        _todayBeforeText = beforeText;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _todayCardAssets = const [];
        _todayBeforeText = '';
      });
    }
  }

  void _openTutorial() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _a(AppTheme.panelFill, 0.96),
        title: Text(
          '튜토리얼',
          style: TextStyle(color: _a(AppTheme.homeInkWarm, 0.95)),
        ),
        content: Text(
          '여기에 튜토리얼 내용을 붙일 거야 ✨',
          style: TextStyle(color: _a(AppTheme.homeInkWarm, 0.82)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '닫기',
              style: TextStyle(color: _a(AppTheme.homeInkWarm, 0.92)),
            ),
          ),
        ],
      ),
    );
  }

  void _contactEmail() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _a(AppTheme.panelFill, 0.96),
        title: Text(
          '문의하기',
          style: TextStyle(color: _a(AppTheme.homeInkWarm, 0.95)),
        ),
        content: Text(
          '문의 메일 연결은 다음 단계에서 붙이자.\n(예: url_launcher로 mailto:)',
          style: TextStyle(color: _a(AppTheme.homeInkWarm, 0.82)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '확인',
              style: TextStyle(color: _a(AppTheme.homeInkWarm, 0.92)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCalendarAndRefresh() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CalanderDiaryPage()),
    );
    if (!mounted) return;
    _loadTodayDiary();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topH = size.height * _topRatio;

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

          // ✅ TOP 아이콘
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _TopIconButton(
                      icon: Icons.help_outline_rounded,
                      onTap: _openTutorial,
                    ),
                    const SizedBox(width: 10),
                    _TopIconButton(
                      icon: Icons.mail_outline_rounded,
                      onTap: _contactEmail,
                    ),
                  ],
                ),
              ),
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
                      constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
                        child: Container(
                          width: double.infinity,
                          constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.zero,
                            border: Border.all(
                              color: _a(Colors.white, 0.02),
                              width: 1,
                            ),
                          ),
                          // ✅ 핵심: 아래로 “훅” 밀리는 원인 제거
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ✅ 오늘의 카드 박스 (살짝만 위로)
                              _PredictionSection(
                                label: '오늘의 카드',
                                glowPurple: _glowPurple,
                                cardAssets: _todayCardAssets,
                                beforeText: _todayBeforeText,
                                cardTint: _cardTint,
                                panelAlpha: _panelAlpha,
                                borderAlpha: _panelBorderAlpha,
                                onOpenDiary: _openCalendarAndRefresh,
                              ),

                              // ✅ 메뉴와의 간격을 메뉴 간격(10)과 통일
                              const SizedBox(height: 10),

                              // ✅ 메뉴 박스
                              Column(
                                children: [
                                  _MainMenuIconItem(
                                    iconAsset: _iconWriteDiary,
                                    label: ' 내일 타로일기 쓰기',
                                    glowPurple: _glowPurple,
                                    panelAlpha: _panelAlpha,
                                    borderAlpha: _panelBorderAlpha,
                                    level: _MenuLevel.normal,
                                    iconBoxSize: 42,
                                    iconLeftPad: 6,
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                          const WriteDiaryOnePage(),
                                        ),
                                      );
                                      if (!mounted) return;
                                      _loadTodayDiary();
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  _MainMenuIconItem(
                                    iconAsset: _iconListDiary,
                                    label: ' 타로일기 보관함',
                                    glowPurple: _glowPurple,
                                    panelAlpha: _panelAlpha,
                                    borderAlpha: _panelBorderAlpha,
                                    level: _MenuLevel.normal,
                                    iconBoxSize: 40,
                                    iconLeftPad: 6,
                                    onTap: _openCalendarAndRefresh,
                                  ),
                                  const SizedBox(height: 10),
                                  _MainMenuIconItem(
                                    iconAsset: _iconArcana,
                                    label: ' 아르카나 도감',
                                    glowPurple: _glowPurple,
                                    panelAlpha: _panelAlpha,
                                    borderAlpha: _panelBorderAlpha,
                                    level: _MenuLevel.last,
                                    iconBoxSize: 40,
                                    iconLeftPad: 6,
                                    onTap: () => Navigator.of(context)
                                        .pushNamed('/list_arcana'),
                                  ),
                                ],
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

class _PredictionSection extends StatefulWidget {
  final String label;
  final Color glowPurple;
  final List<String> cardAssets;
  final String beforeText;
  final Color cardTint;
  final VoidCallback onOpenDiary;

  final double panelAlpha;
  final double borderAlpha;

  const _PredictionSection({
    required this.label,
    required this.glowPurple,
    required this.cardAssets,
    required this.beforeText,
    required this.cardTint,
    required this.onOpenDiary,
    required this.panelAlpha,
    required this.borderAlpha,
  });

  @override
  State<_PredictionSection> createState() => _PredictionSectionState();
}

class _PredictionSectionState extends State<_PredictionSection> {
  final PageController _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final hasDiary = widget.cardAssets.isNotEmpty;
    final count = hasDiary ? widget.cardAssets.take(3).length : 1;

    final wHas = (size.width * 0.235).clamp(84.0, 150.0);
    final wNo = (size.width * 0.20).clamp(58.0, 110.0);

    final cardW = hasDiary ? wHas : wNo;
    final cardH = cardW * 1.55;

    final fixedCardSlotH = math.max(wHas * 1.55, wNo * 1.55);
    const fixedFooterH = 26.0;

    final labelColor = _a(Colors.white, 0.82);
    final subText = _a(Colors.white, 0.60);

    final enableSwipe = hasDiary;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: 12 + 10 + fixedCardSlotH + fixedFooterH + 14,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _a(const Color(0xFFEFE6FF), 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _a(Colors.white, widget.borderAlpha), width: 1),
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: _a(const Color(0xFFB58CFF), 0.16),
            blurRadius: 44,
            spreadRadius: -16,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 14, color: labelColor),
              const SizedBox(width: 6),
              Text(
                widget.label,
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
            ],
          ),
          const SizedBox(height: 10),

          SizedBox(
            height: fixedCardSlotH,
            child: PageView(
              controller: _pc,
              onPageChanged: (i) => setState(() => _page = i),
              physics: enableSwipe
                  ? const BouncingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: widget.onOpenDiary,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(count, (i) {
                        final showBackOnly = !hasDiary;
                        final path = showBackOnly ? '' : widget.cardAssets[i];

                        return Padding(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
                          child: _AnimatedCardTile(
                            assetPath: path,
                            width: cardW,
                            height: cardH,
                            glow: widget.glowPurple,
                            showBackOnly: showBackOnly,
                            cardTint: widget.cardTint,
                            renderCustomBack: showBackOnly,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _BeforeTextPreview(
                      text: widget.beforeText,
                      onTapOpen: widget.onOpenDiary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            height: fixedFooterH,
            child: Center(
              child: hasDiary
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(active: _page == 0),
                  const SizedBox(width: 6),
                  _Dot(active: _page == 1),
                ],
              )
                  : Text(
                '오늘은 아직 기록이 없어요',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12.4,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                  color: subText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BeforeTextPreview extends StatelessWidget {
  final String text;
  final VoidCallback onTapOpen;

  const _BeforeTextPreview({
    required this.text,
    required this.onTapOpen,
  });

  @override
  Widget build(BuildContext context) {
    final t = text.trim();
    final hasText = t.isNotEmpty;

    return GestureDetector(
      onTap: onTapOpen,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: _a(Colors.white, 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _a(Colors.white, 0.10), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hasText ? t : '아직 오늘의 예측 텍스트가 없어요',
              textAlign: TextAlign.center,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSansKr(
                fontSize: 13.2,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: _a(Colors.white, hasText ? 0.84 : 0.62),
                shadows: [
                  Shadow(
                    color: _a(Colors.black, 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '탭하면 상세로 이동',
              style: GoogleFonts.notoSansKr(
                fontSize: 11.6,
                fontWeight: FontWeight.w700,
                color: _a(Colors.white, 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: active ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: _a(Colors.white, active ? 0.70 : 0.30),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _AnimatedCardTile extends StatefulWidget {
  final String assetPath;
  final double width;
  final double height;
  final Color glow;
  final bool showBackOnly;
  final Color cardTint;
  final bool renderCustomBack;

  const _AnimatedCardTile({
    required this.assetPath,
    required this.width,
    required this.height,
    required this.glow,
    required this.showBackOnly,
    required this.cardTint,
    required this.renderCustomBack,
  });

  @override
  State<_AnimatedCardTile> createState() => _AnimatedCardTileState();
}

class _AnimatedCardTileState extends State<_AnimatedCardTile> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final double scale = _pressed ? 1.035 : 1.0;

    Widget base;
    if (widget.renderCustomBack && widget.showBackOnly) {
      base = _TarotBackCardHome(width: widget.width, height: widget.height);
    } else {
      base = Container(
        width: widget.width,
        height: widget.height,
        color: Colors.transparent,
        padding: const EdgeInsets.all(3),
        child: Image.asset(
          widget.assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) {
            return Container(
              color: _a(Colors.white, 0.06),
              alignment: Alignment.center,
              child: Icon(
                Icons.image_not_supported,
                color: _a(Colors.white, 0.55),
              ),
            );
          },
        ),
      );
    }

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _a(Colors.black, 0.16),
                blurRadius: 18,
                offset: const Offset(0, 12),
                spreadRadius: -6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                base,
                Positioned.fill(
                  child: Container(color: widget.cardTint.withOpacity(0.035)),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _a(Colors.black, 0.00),
                          _a(Colors.black, 0.06),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TarotBackCardHome extends StatelessWidget {
  final double width;
  final double height;

  const _TarotBackCardHome({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    const outerR = 9.0;
    const innerR = 7.0;

    const ivoryWarm = Color(0xFFF1E9DE);
    const top = Color(0xFF60407E);
    const bottom = Color(0xFF3F2A5B);

    final seamLine = _a(const Color(0xFF2A1636), 0.22);
    final star = _a(AppTheme.headerInk, 0.82);

    const framePad = 6.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outerR),
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.18),
            blurRadius: 18,
            offset: const Offset(0, 14),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(outerR),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ivoryWarm,
                  borderRadius: BorderRadius.circular(outerR),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.25, -0.35),
                      radius: 1.2,
                      colors: [
                        _a(Colors.white, 0.22),
                        _a(Colors.white, 0.0),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(framePad),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(innerR),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [top, bottom],
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Icon(Icons.auto_awesome, size: 20, color: star),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(framePad - 0.9),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(innerR + 1.2),
                      border: Border.all(color: seamLine, width: 0.9),
                    ),
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

enum _MenuLevel { normal, last }

class _MainMenuIconItem extends StatelessWidget {
  final String iconAsset;
  final String label;
  final Color glowPurple;
  final VoidCallback onTap;
  final _MenuLevel level;

  final double panelAlpha;
  final double borderAlpha;

  final double iconBoxSize;
  final double iconLeftPad;
  final double iconGap;

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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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

class _TopIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  State<_TopIconButton> createState() => _TopIconButtonState();
}

class _TopIconButtonState extends State<_TopIconButton> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final ink = _a(AppTheme.homeInkWarm, 0.92);

    return AnimatedScale(
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      scale: _down ? 0.92 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: widget.onTap,
          onTapDown: (_) => _setDown(true),
          onTapCancel: () => _setDown(false),
          onTapUp: (_) => _setDown(false),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _a(Colors.white, 0.06),
              border: Border.all(color: _a(Colors.white, 0.10), width: 1),
            ),
            child: Icon(widget.icon, size: 22, color: ink),
          ),
        ),
      ),
    );
  }
}