import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../setting.dart';
import '../diary/write_diary_one.dart';
import '../diary/calander_diary.dart';
import '../support/tutorial.dart';

import '../backend/diary_repo.dart';
import '../arcana/arcana_labels.dart';
import '../theme/app_theme.dart';
import '../support/contact_form_page.dart';
import '../ads/rewarded_gate.dart';
import '../error/error_reporter.dart';

Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  static const String _bgBottom = 'asset/main_bottom.webp';
  static const String _topHero = 'asset/main_top.webp';

  static const String _iconWriteDiary = 'asset/icon_write_diary.png';
  static const String _iconListDiary = 'asset/icon_list_diary.png';
  static const String _iconArcana = 'asset/icon_arcana.png';

  static const Color _cardTint = Color(0xFF6C63FF);
  static const Color _glowPurple = Color(0xFF7C5CFF);

  static const double _panelAlpha = 0.09;
  static const double _panelBorderAlpha = 0.10;

  List<String> _todayCardAssets = const [];
  String _todayBeforeText = '';

  @override
  void initState() {
    super.initState();
    _loadTodayDiary();

    // 광고 워밍업
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      _warmUpRewardedAd();
    });

    // 👇 백업 안내 추가
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBackupPrompt();
    });
  }

  void _showUserMessage(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _checkBackupPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('backup_prompt_shown') ?? false;

    if (shown) return;

    await prefs.setBool('backup_prompt_shown', true);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('데이터를 안전하게 보관하시겠어요?'),
          content: const Text(
            'Google 로그인 후 Drive 백업을 켜두면\n'
                '앱을 삭제하거나 기기를 바꿔도\n'
                '기록을 다시 불러올 수 있어요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('나중에'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openSettings(); // 👈 이미 있는 함수 활용
              },
              child: const Text('설정하기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _recordError({
    required String source,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) async {
    await ErrorReporter.I.record(
      source: source,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  Future<void> _warmUpRewardedAd() async {
    try {
      await RewardedGate.warmUp();
    } catch (e, st) {
      await _recordError(
        source: 'main_home.warmUpRewardedAd',
        error: e,
        stackTrace: st,
      );
      // 광고 워밍업 실패는 홈 진입을 막지 않으므로 사용자에게 별도 노출하지 않습니다.
    }
  }

  Future<void> _loadTodayDiary() async {
    final today = DateTime.now();
    final dateOnly = DiaryRepo.I.dateOnly(today);

    try {
      final doc = await DiaryRepo.I.read(date: dateOnly);

      List<String> paths = [];
      String beforeText = '';

      if (doc != null) {
        final cardsDynamic = doc['cards'];
        if (cardsDynamic is List) {
          final ids = cardsDynamic.map((e) => (e as num).toInt()).toList();
          paths = ids
              .where((id) => id >= 0 && id < ArcanaLabels.kTarotFileNames.length)
              .map((id) => 'asset/cards/${ArcanaLabels.kTarotFileNames[id]}')
              .toList();
        }

        final bt = doc['beforeText'];
        if (bt is String) {
          beforeText = bt;
        }
      }

      if (!mounted) return;
      setState(() {
        _todayCardAssets = paths.take(3).toList();
        _todayBeforeText = beforeText;
      });
    } catch (e, st) {
      await _recordError(
        source: 'main_home.loadTodayDiary',
        error: e,
        stackTrace: st,
        extra: {
          'today': dateOnly.toIso8601String(),
        },
      );

      if (!mounted) return;
      setState(() {
        _todayCardAssets = const [];
        _todayBeforeText = '';
      });
      // 홈 진입 시 자동 로딩 실패는 앱 흐름을 막지 않으므로 사용자에게 별도 노출하지 않습니다.
    }
  }

  Future<void> _openTutorial() async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const TutorialPage(),
        ),
      );
    } catch (e, st) {
      await _recordError(
        source: 'main_home.openTutorial',
        error: e,
        stackTrace: st,
      );
      _showUserMessage('안내 화면을 여는 중 문제가 발생했습니다. 다시 시도해주세요.');
    }
  }

  Future<void> _openSettings() async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SettingPage(),
        ),
      );

      if (!mounted) return;
      await _loadTodayDiary();
    } catch (e, st) {
      await _recordError(
        source: 'main_home.openSettings',
        error: e,
        stackTrace: st,
      );
      _showUserMessage('설정 화면을 여는 중 문제가 발생했습니다. 다시 시도해주세요.');
    }
  }

  Future<void> _openContactForm() async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ContactFormPage(),
        ),
      );
    } catch (e, st) {
      await _recordError(
        source: 'main_home.openContactForm',
        error: e,
        stackTrace: st,
      );
      _showUserMessage('문의 화면을 여는 중 문제가 발생했습니다. 다시 시도해주세요.');
    }
  }

  Future<void> _openWriteDiary() async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const WriteDiaryOnePage(),
        ),
      );

      if (!mounted) return;
      await _loadTodayDiary();
    } catch (e, st) {
      await _recordError(
        source: 'main_home.openWriteDiary',
        error: e,
        stackTrace: st,
      );
      _showUserMessage('일기 작성 화면을 여는 중 문제가 발생했습니다. 다시 시도해주세요.');
    }
  }

  Future<void> _openCalendarAndRefresh() async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CalanderDiaryPage()),
      );

      if (!mounted) return;
      await _loadTodayDiary();
    } catch (e, st) {
      await _recordError(
        source: 'main_home.openCalendarAndRefresh',
        error: e,
        stackTrace: st,
      );
      _showUserMessage('일기 보관함을 여는 중 문제가 발생했습니다. 다시 시도해주세요.');
    }
  }

  Future<void> _openArcana() async {
    try {
      await Navigator.of(context).pushNamed('/list_arcana');

      if (!mounted) return;
    } catch (e, st) {
      await _recordError(
        source: 'main_home.openArcana',
        error: e,
        stackTrace: st,
      );
      _showUserMessage('아르카나 도감 화면을 여는 중 문제가 발생했습니다. 다시 시도해주세요.');
    }
  }

  double _topHeroHeight(Size size, EdgeInsets padding) {
    final raw = size.height * 0.42;
    final minH = 250.0 + padding.top;
    final maxH = math.min(size.height * 0.52, 420.0 + padding.top);
    return raw.clamp(minH, maxH);
  }

  double _sidePadding(double width) {
    if (width < 360) return 16;
    if (width < 430) return 20;
    return 24;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final padding = mq.padding;

    final topH = _topHeroHeight(size, padding);
    final sidePad = _sidePadding(size.width);
    final topIconRightInset = size.width < 360 ? 8.0 : 12.0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(_bgBottom, fit: BoxFit.cover),
          ),
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(sidePad, 10, topIconRightInset, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _TopIconButton(
                      icon: Icons.help_outline_rounded,
                      iconSize: 21.5,
                      iconOffset: const Offset(0, 0.6),
                      onTap: _openTutorial,
                    ),
                    const SizedBox(width: 8),
                    _TopIconButton(
                      icon: Icons.settings_rounded,
                      iconSize: 18,
                      iconOffset: const Offset(0, 0.6),
                      onTap: _openSettings,
                    ),
                    const SizedBox(width: 8),
                    _TopIconButton(
                      icon: Icons.mail_outline_rounded,
                      iconSize: 21,
                      iconOffset: const Offset(0, 0.6),
                      onTap: _openContactForm,
                    ),
                  ],
                ),
              ),
            ),
          ),
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
                        padding: EdgeInsets.fromLTRB(
                          0,
                          0,
                          0,
                          math.max(14, padding.bottom + 8),
                        ),
                        child: Container(
                          width: double.infinity,
                          constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                          padding: EdgeInsets.fromLTRB(
                            sidePad,
                            0,
                            sidePad,
                            14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.zero,
                            border: Border.all(
                              color: _a(Colors.white, 0.02),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                              const SizedBox(height: 10),
                              Column(
                                children: [
                                  _MainMenuIconItem(
                                    iconAsset: _iconWriteDiary,
                                    label: ' 내일 타로일기 쓰기',
                                    glowPurple: _glowPurple,
                                    panelAlpha: _panelAlpha,
                                    borderAlpha: _panelBorderAlpha,
                                    level: _MenuLevel.normal,
                                    iconBoxSize: size.width < 360 ? 38 : 42,
                                    iconLeftPad: size.width < 360 ? 2 : 6,
                                    iconGap: size.width < 360 ? 10 : 12,
                                    onTap: _openWriteDiary,
                                  ),
                                  const SizedBox(height: 10),
                                  _MainMenuIconItem(
                                    iconAsset: _iconListDiary,
                                    label: ' 타로일기 보관함',
                                    glowPurple: _glowPurple,
                                    panelAlpha: _panelAlpha,
                                    borderAlpha: _panelBorderAlpha,
                                    level: _MenuLevel.normal,
                                    iconBoxSize: size.width < 360 ? 36 : 40,
                                    iconLeftPad: size.width < 360 ? 2 : 6,
                                    iconGap: size.width < 360 ? 10 : 12,
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
                                    iconBoxSize: size.width < 360 ? 36 : 40,
                                    iconLeftPad: size.width < 360 ? 2 : 6,
                                    iconGap: size.width < 360 ? 10 : 12,
                                    onTap: _openArcana,
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

    final isNarrow = size.width < 360;

    final wHas = (size.width * (isNarrow ? 0.22 : 0.235)).clamp(78.0, 150.0);
    final wNo = (size.width * (isNarrow ? 0.18 : 0.20)).clamp(56.0, 110.0);

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
      padding: EdgeInsets.fromLTRB(
        isNarrow ? 12 : 14,
        12,
        isNarrow ? 12 : 14,
        14,
      ),
      decoration: BoxDecoration(
        color: _a(const Color(0xFFEFE6FF), 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _a(Colors.white, widget.borderAlpha),
          width: 1,
        ),
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
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Icon(Icons.auto_awesome, size: 14, color: labelColor),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: widget.label,
                      style: GoogleFonts.notoSansKr(
                        fontSize: isNarrow ? 12.2 : 12.6,
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
                    TextSpan(
                      text: ' (터치하면 상세로 이동)',
                      style: GoogleFonts.notoSansKr(
                        fontSize: isNarrow ? 10.8 : 11.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.05,
                        color: _a(Colors.white, 0.62),
                      ),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(count, (i) {
                      final showBackOnly = !hasDiary;
                      final path = showBackOnly ? '' : widget.cardAssets[i];

                      return Padding(
                        padding: EdgeInsets.only(
                          left: i == 0 ? 0 : (isNarrow ? 8 : 10),
                        ),
                        child: _AnimatedCardTile(
                          assetPath: path,
                          width: cardW,
                          height: cardH,
                          glow: widget.glowPurple,
                          showBackOnly: showBackOnly,
                          cardTint: widget.cardTint,
                          renderCustomBack: showBackOnly,
                          onTap: widget.onOpenDiary,
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _BeforeTextPreview(
                    text: widget.beforeText,
                    onTapOpen: widget.onOpenDiary,
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
                '오늘은 아직 기록이 없습니다',
                style: GoogleFonts.notoSansKr(
                  fontSize: isNarrow ? 12.0 : 12.4,
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
    final raw = text.trim();
    final hasText = raw.isNotEmpty;
    final isNarrow = MediaQuery.of(context).size.width < 360;

    final style = GoogleFonts.gowunDodum(
      fontSize: isNarrow ? 13.2 : 13.8,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: _a(Colors.white, hasText ? 0.72 : 0.5),
    );
    
    return GestureDetector(
      onTap: onTapOpen,
      child: Container(
        width: double.infinity,
        height: double.infinity, // 👈 중요 (부모 높이 꽉 채움)
        alignment: Alignment.topLeft,
        padding: EdgeInsets.fromLTRB(
          isNarrow ? 12 : 14,
          12,
          isNarrow ? 12 : 14,
          12,
        ),
        decoration: BoxDecoration(
          color: _a(Colors.white, 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _a(Colors.white, 0.10), width: 1),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Text(
            hasText ? raw : '아직 오늘의 예측 텍스트가 없습니다',
            textAlign: TextAlign.left,
            softWrap: true,
            style: style,
          ),
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
  final VoidCallback? onTap;

  const _AnimatedCardTile({
    required this.assetPath,
    required this.width,
    required this.height,
    required this.glow,
    required this.showBackOnly,
    required this.cardTint,
    required this.renderCustomBack,
    this.onTap,
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
      onTap: widget.onTap,
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
                  child: Container(
                    color: widget.cardTint.withAlpha((0.035 * 255).round()),
                  ),
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
    final isNarrow = MediaQuery.of(context).size.width < 360;

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
        padding: EdgeInsets.symmetric(
          vertical: isNarrow ? 11 : 12,
          horizontal: isNarrow ? 14 : 16,
        ),
        decoration: BoxDecoration(
          color: _a(Colors.white, panelAlpha),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _a(Colors.white, borderAlpha),
            width: 1,
          ),
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
                  errorBuilder: (_, __, ___) {
                    return Icon(
                      Icons.apps,
                      size: 34,
                      color: _a(Colors.white, 0.75),
                    );
                  },
                ),
              ),
            ),
            SizedBox(width: iconGap),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.notoSansKr(
                  fontSize: isNarrow ? 13.6 : 14.5,
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
  final double iconSize;
  final Offset iconOffset;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 19,
    this.iconOffset = Offset.zero,
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
    final isNarrow = MediaQuery.of(context).size.width < 360;
    final boxSize = isNarrow ? 32.0 : 34.0;

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
            width: boxSize,
            height: boxSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _a(Colors.white, 0.055),
              border: Border.all(color: _a(Colors.white, 0.10), width: 1),
            ),
            child: Transform.translate(
              offset: widget.iconOffset,
              child: Icon(widget.icon, size: widget.iconSize, color: ink),
            ),
          ),
        ),
      ),
    );
  }
}