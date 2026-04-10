import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tarot_diary/arcana/arcana_labels.dart';

import '../theme/app_theme.dart';
import 'list_diary.dart';
import 'write_diary_one.dart';
import 'write_diary_two.dart';
import 'edit_diary.dart';
import '../ui/tarot_card_preview.dart';

// ✅ 레이아웃 규격 토큰 (TopBox/CenterBox/BottomBox 포함)
import '../ui/layout_tokens.dart';
// ✅ 공용 CTA 버튼 (저장/수정/삭제 + HomeFloatingButton 포함)
import '../ui/app_buttons.dart';
// ✅ 공용 토스트
import '../ui/app_toast.dart';

import '../backend/diary_repo.dart';
import '../error/error_reporter.dart';

enum DiaryViewMode { calendar, list }

// ✅ withOpacity 워닝 방지용
Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class CalanderDiaryPage extends StatefulWidget {
  final DiaryViewMode initialViewMode;

  /// ✅ 외부에서 캘린더가 “바로 보여줄 날짜”
  final DateTime? selectedDate;

  const CalanderDiaryPage({
    super.key,
    this.initialViewMode = DiaryViewMode.calendar,
    this.selectedDate,
  });

  @override
  State<CalanderDiaryPage> createState() => _CalanderDiaryPageState();
}

class _CalanderDiaryPageState extends State<CalanderDiaryPage> {
  final ScrollController _sc = ScrollController();

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  // ================== THEME ==================
  static const Color bgSolid = AppTheme.bgColor;

  static const Color headerInk = AppTheme.homeInkWarm;
  static const Color sundayInk = AppTheme.sundayInk;
  static const Color saturdayInk = AppTheme.saturdayInk;

  static const Color calInk = AppTheme.calInk;
  static const Color calMuted = AppTheme.calMuted;

  static const double _radius = AppTheme.radius;
  static const double _innerRadius = AppTheme.innerRadius;

  static const double _cardTrimWf = 0.945;
  static const double _cardTrimHf = 0.972;

  static const double _weekdayLift = 6.0;

  Color get _panelFill => AppTheme.panelFill;
  Color get _panelInner => AppTheme.calendarBg;
  Color get _panelInnerStrong => AppTheme.diaryFieldBg;

  Color get _panelBorder => AppTheme.panelBorder;
  Color get _panelBorderSoft => AppTheme.panelBorderSoft;

  Color get _strokeSoft => _a(AppTheme.headerInk, 0.12);
  Color get _stroke => _a(AppTheme.headerInk, 0.18);
  Color get _strokeStrong => _a(AppTheme.accent, 0.34);

  Color get _inkSplash => AppTheme.inkSplash;
  Color get _inkHighlight => AppTheme.inkHighlight;

  // ================== 상태 ==================
  DiaryViewMode _viewMode = DiaryViewMode.calendar;

  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  bool _loadingDay = false;
  int _loadDayNonce = 0;

  bool _bootLoading = true;

  Set<int> _hasEntryKeys = <int>{};

  bool _selectedHasEntry = false;

  List<String> _selectedCards = <String>[];

  String _selectedBefore = '';
  String _selectedAfter = '';

  bool _cardsExpanded = true;

  List<int> _selectedCardIds = <int>[];
  int _selectedCardCount = 1;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;

    final d = widget.selectedDate;
    if (d != null) {
      final normalized = DateTime(d.year, d.month, d.day);
      _selectedDay = normalized;
      _focusedMonth = DateTime(normalized.year, normalized.month, 1);
    } else {
      final now = DateTime.now();
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDay = DateTime(now.year, now.month, now.day);
    }

    _bootstrap();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sc.jumpTo(0);
    });
  }

  // ================== 유틸 ==================
  int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _monthLabel(DateTime m) => "${m.year}년 ${m.month}월";

  TextStyle get _tsTitle => AppTheme.title.copyWith(color: _a(headerInk, 0.96));

  TextStyle get _tsMonth => AppTheme.month.copyWith(
    fontSize: 14.6,
    fontWeight: FontWeight.w700,
    height: 1.0,
    color: _a(AppTheme.tSecondary, 0.85),
  );

  double _thumbW(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 54;
    if (w < 430) return 60;
    return 62;
  }

  double _thumbH(BuildContext context) => _thumbW(context) * 1.74;

  double _thumbGap(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w < 360 ? 8 : 10;
  }

  double _entryPanelHeight(BuildContext context, {required bool hasSelected}) {
    final size = MediaQuery.of(context).size;
    final bool narrow = size.width < 360;
    final bool short = size.height < 760;

    if (!hasSelected) {
      return short ? 340 : 420;
    }

    if (_cardsExpanded) {
      return narrow ? 250 : 260;
    }
    return short ? 320 : 380;
  }

  double _pageSidePadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 12;
    if (w < 430) return 14;
    return 18;
  }

  // ================== 삭제 다이얼로그 ==================
  Future<void> _confirmDeleteDialog() async {
    String _formatDateLabel(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';
    const Color danger = Color(0xFFB45A64);

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _panelFill,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: _stroke, width: 1),
          ),
          titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 22, color: _a(danger, 0.92)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '이 일기를 삭제할까요?',
                  style: GoogleFonts.gowunDodum(
                    fontSize: 14.2,
                    fontWeight: FontWeight.w900,
                    color: _a(AppTheme.tPrimary, 0.92),
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: _a(danger, 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _a(danger, 0.45), width: 1),
                ),
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.gowunDodum(
                      fontSize: 12.6,
                      fontWeight: FontWeight.w800,
                      color: _a(AppTheme.tPrimary, 0.86),
                      height: 1.6,
                    ),
                    children: [
                      TextSpan(
                        text: _formatDateLabel(_selectedDay),
                        style: TextStyle(
                          color: _a(AppTheme.homeInkWarm, 0.96),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const TextSpan(text: ' 의 데이터가 삭제됩니다.\n\n'),
                      const TextSpan(text: '삭제된 일기와 카드는 되돌릴 수 없어요!'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
          actions: [
            Row(
              children: [
                const Spacer(),
                SizedBox(
                  height: 30,
                  child: FilledButton(
                    autofocus: true,
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: _a(AppTheme.accent, 0.10),
                      foregroundColor: _a(AppTheme.tPrimary, 0.90),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity:
                      const VisualDensity(horizontal: -1, vertical: -2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: _stroke, width: 1),
                      ),
                      textStyle: GoogleFonts.gowunDodum(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 30,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _a(danger, 0.90),
                      foregroundColor: _a(Colors.white, 0.96),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity:
                      const VisualDensity(horizontal: -1, vertical: -2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: GoogleFonts.gowunDodum(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    child: const Text('삭제하기'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (ok == true) {
      try {
        await DiaryRepo.I.delete(date: _selectedDay);
        if (!mounted) return;

        final k = _key(_selectedDay);
        setState(() {
          _selectedHasEntry = false;
          _selectedBefore = '';
          _selectedAfter = '';
          _selectedCards = <String>[];
          _selectedCardIds = <int>[];
          _selectedCardCount = 1;
          _hasEntryKeys.remove(k);
        });

        AppToast.show(
          context,
          '삭제가 완료되었습니다.',
        );
      } catch (e, st) {
        await ErrorReporter.I.record(
          source: 'CalanderDiaryPage._confirmDeleteDialog',
          error: e,
          stackTrace: st,
          extra: {
            'selectedDay': _selectedDay.toIso8601String(),
          },
        );

        if (!mounted) return;
        AppToast.show(
          context,
          '일기를 삭제하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
        );
      }
    }
  }

  // ================== 데이터 로딩 ==================
  Future<void> _bootstrap() async {
    if (!mounted) return;
    setState(() => _bootLoading = true);

    try {
      await _loadMonthDots(showErrorToast: false);
      await _loadSelectedDay(showErrorToast: false);
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'CalanderDiaryPage._bootstrap',
        error: e,
        stackTrace: st,
      );

      if (!mounted) return;
      AppToast.show(
        context,
        '일기 화면을 불러오는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    } finally {
      if (!mounted) return;
      setState(() => _bootLoading = false);
    }
  }

  Future<void> _loadMonthDots({bool showErrorToast = true}) async {
    try {
      final keys = await DiaryRepo.I.listMonthEntryKeys(month: _focusedMonth);
      if (!mounted) return;
      setState(() => _hasEntryKeys = keys);
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'CalanderDiaryPage._loadMonthDots',
        error: e,
        stackTrace: st,
        extra: {
          'focusedMonth': _focusedMonth.toIso8601String(),
        },
      );

      if (!mounted) return;
      setState(() => _hasEntryKeys = <int>{});

      if (showErrorToast) {
        AppToast.show(
          context,
          '월별 기록을 불러오는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
        );
      }
    }
  }

  Future<void> _loadSelectedDay({bool showErrorToast = true}) async {
    final nonce = ++_loadDayNonce;
    setState(() => _loadingDay = true);

    try {
      final data = await DiaryRepo.I.read(date: _selectedDay);
      if (!mounted || nonce != _loadDayNonce) return;

      final k = _key(_selectedDay);

      if (data == null) {
        setState(() {
          _selectedHasEntry = false;
          _selectedBefore = '';
          _selectedAfter = '';
          _selectedCards = <String>[];
          _selectedCardIds = <int>[];
          _selectedCardCount = 1;
          _hasEntryKeys.remove(k);
        });
        return;
      }

      final beforeText = (data['beforeText'] ?? '').toString();
      final afterText = (data['afterText'] ?? '').toString();

      final int cc = ((data['cardCount'] as num?)?.toInt() ?? 1).clamp(1, 3);
      final List<int> ids =
          (data['cards'] as List?)?.map((e) => (e as num).toInt()).toList() ??
              <int>[];

      String cardAssetPath(int id) {
        final safe = id.clamp(0, ArcanaLabels.kTarotFileNames.length - 1);
        return 'asset/cards/${ArcanaLabels.kTarotFileNames[safe]}';
      }

      final cards = ids.map(cardAssetPath).toList();

      setState(() {
        _selectedHasEntry = true;
        _selectedBefore = beforeText;
        _selectedAfter = afterText;
        _selectedCards = cards;
        _selectedCardCount = cc;
        _selectedCardIds = ids.take(cc).toList();
        _hasEntryKeys.add(k);
      });
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'CalanderDiaryPage._loadSelectedDay',
        error: e,
        stackTrace: st,
        extra: {
          'selectedDay': _selectedDay.toIso8601String(),
          'nonce': nonce,
        },
      );

      if (!mounted || nonce != _loadDayNonce) return;

      setState(() {
        _selectedHasEntry = false;
        _selectedBefore = '';
        _selectedAfter = '';
        _selectedCards = <String>[];
        _selectedCardIds = <int>[];
        _selectedCardCount = 1;
      });

      if (showErrorToast) {
        AppToast.show(
          context,
          '선택한 날짜의 기록을 불러오는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
        );
      }
    } finally {
      if (mounted && nonce == _loadDayNonce) {
        setState(() => _loadingDay = false);
      }
    }
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
      if (!_isSameMonth(_selectedDay, _focusedMonth)) {
        _selectedDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      }
    });
    _loadMonthDots();
    _loadSelectedDay();
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
      if (!_isSameMonth(_selectedDay, _focusedMonth)) {
        _selectedDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      }
    });
    _loadMonthDots();
    _loadSelectedDay();
  }

  Future<void> _openListPage() async {
    await Navigator.of(context)
        .push(_fadeRoute(ListDiaryPage(initialDate: _selectedDay)));
  }

  Future<void> _openWriteForSelectedDay(
      {bool initialShowBeforeTab = true}) async {
    if (_bootLoading || _loadingDay) return;

    if (_selectedHasEntry) {
      var ids = _selectedCardIds;
      var cc = _selectedCardCount;
      var before = _selectedBefore;
      var after = _selectedAfter;

      if (ids.isEmpty) {
        try {
          final data = await DiaryRepo.I.read(date: _selectedDay);
          if (!mounted) return;

          if (data != null) {
            cc = ((data['cardCount'] as num?)?.toInt() ?? 1).clamp(1, 3);
            ids = (data['cards'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
                <int>[];
            ids = ids.take(cc).toList();

            before = (data['beforeText'] ?? '').toString();
            after = (data['afterText'] ?? '').toString();
          }
        } catch (e, st) {
          await ErrorReporter.I.record(
            source: 'CalanderDiaryPage._openWriteForSelectedDay.readExisting',
            error: e,
            stackTrace: st,
            extra: {
              'selectedDay': _selectedDay.toIso8601String(),
            },
          );

          if (!mounted) return;
          AppToast.show(
            context,
            '기존 일기 정보를 불러오는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
          );
          return;
        }
      }

      final result = await Navigator.of(context).push(
        _fadeRoute(
          EditDiaryPage(
            pickedCardIds: ids.take(cc).toList(),
            cardCount: cc,
            selectedDate: _selectedDay,
            initialBeforeText: before.trim().isEmpty ? null : before,
            initialAfterText: after.trim().isEmpty ? null : after,
            initialShowBeforeTab: initialShowBeforeTab,
          ),
        ),
      );

      if (!mounted) return;
      if (result == true) {
        await _loadMonthDots();
        await _loadSelectedDay();
      }
      return;
    }

    final result = await Navigator.of(context).push(
      _fadeRoute(
        WriteDiaryOnePage(
          selectedDate: _selectedDay,
        ),
      ),
    );

    if (!mounted) return;
    if (result == true) {
      await _loadMonthDots();
      await _loadSelectedDay();
    }
  }

  List<DateTime> _buildMonthCells(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final firstWeekdaySun0 = first.weekday % 7;
    final gridStart = first.subtract(Duration(days: firstWeekdaySun0));
    return List<DateTime>.generate(42, (i) => gridStart.add(Duration(days: i)));
  }

  Color _dayNumberColor(
      DateTime day, {
        required bool isInMonth,
        required Color sundayWeekdayInk,
        required Color saturdayWeekdayInk,
      }) {
    if (!isInMonth) return _a(calMuted, 0.48);

    if (day.weekday == DateTime.sunday) return sundayWeekdayInk;
    if (day.weekday == DateTime.saturday) return saturdayWeekdayInk;

    return _a(calInk, 0.72);
  }

  Widget _buildDayCell({
    required DateTime day,
    required bool isInMonth,
    required bool isSelected,
    required bool has,
    required Color dayColor,
  }) {
    final bool isToday = _isToday(day) && isInMonth;

    final bool showBadge = isSelected || isToday;
    final Color todayBorder = _a(AppTheme.accent, 0.62);
    final Color todayFill = _a(AppTheme.accent, 0.08);
    final Color selectedBorder = _strokeStrong;
    final Color selectedFill = _a(AppTheme.accent, 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: isInMonth ? _a(AppTheme.accent, 0.12) : Colors.transparent,
        highlightColor:
        isInMonth ? _a(AppTheme.accent, 0.06) : Colors.transparent,
        onTap: () {
          setState(() {
            _selectedDay = day;
            if (!isInMonth) _focusedMonth = DateTime(day.year, day.month);

            _selectedHasEntry = false;
            _selectedBefore = '';
            _selectedAfter = '';
            _selectedCards = <String>[];
            _selectedCardIds = <int>[];
            _selectedCardCount = 1;

            _loadingDay = true;
          });

          _loadSelectedDay();
          if (!isInMonth) _loadMonthDots();
        },
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (showBadge)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOut,
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? selectedFill
                              : (isToday ? todayFill : Colors.transparent),
                          border: Border.all(
                            color: isSelected
                                ? selectedBorder
                                : (isToday ? todayBorder : _strokeSoft),
                            width: 1.2,
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.only(top: isSelected ? 1.0 : 1.5),
                      child: Text(
                        '${day.day}',
                        style: GoogleFonts.gowunDodum(
                          color: isSelected
                              ? _a(AppTheme.tPrimary, 0.96)
                              : (isToday
                              ? _a(AppTheme.tPrimary, 0.90)
                              : dayColor),
                          fontSize: 13.0,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (has)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 3.0,
                  child: Center(
                    child: Container(
                      width: 4.2,
                      height: 4.2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _a(
                          AppTheme.accent,
                          isSelected ? 0.75 : (isToday ? 0.60 : 0.45),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthCells = _buildMonthCells(_focusedMonth);

    final hasSelected = _selectedHasEntry;
    final cards = _selectedCards;
    final before = _selectedBefore.trim();
    final after = _selectedAfter.trim();

    final media = MediaQuery.of(context);
    final size = media.size;
    final keyboard = media.viewInsets.bottom;
    final bool isNarrow = size.width < 360;

    final double entryPanelH =
    _entryPanelHeight(context, hasSelected: hasSelected);
    final double scrollBottomPad = keyboard > 0 ? keyboard + 12.0 : 0.0;
    final double sidePad = _pageSidePadding(context);

    bool hasDot(DateTime day, bool inMonth) =>
        inMonth ? _hasEntryKeys.contains(_key(day)) : false;

    final Color weekdayInk = _a(AppTheme.tPrimary, 0.82);
    final Color sundayWeekdayInk = _a(sundayInk, 0.85);
    final Color saturdayWeekdayInk = _a(saturdayInk, 0.85);

    return Scaffold(
      backgroundColor: bgSolid,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _sc,
                    primary: false,
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      sidePad,
                      LayoutTokens.scrollTopPad,
                      sidePad,
                      scrollBottomPad,
                    ),
                    child: Column(
                      children: [
                        TopBox(
                          left: Transform.translate(
                            offset: const Offset(-8, 0),
                            child: AppHeaderBackIconButton(
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ),
                          title: Text(
                            '내 타로일기 보관함',
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.title.copyWith(
                              color: _a(AppTheme.homeInkWarm, 0.96),
                            ),
                          ),
                          right: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ViewModeSwitchButton(
                                onTap: _openListPage,
                                stroke: _panelBorder,
                              ),
                              const SizedBox(width: 8),
                              AppHeaderHomeButton(
                                onTap: () => Navigator.of(context)
                                    .pushNamedAndRemoveUntil('/', (r) => false),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        CenterBox(
                          child: Column(
                            children: [
                              _PanelCard(
                                fill: _panelFill,
                                border: _panelBorder,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(_radius),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Container(
                                          height: isNarrow ? 32 : 34,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            children: [
                                              _MiniIconButton(
                                                icon:
                                                Icons.chevron_left_rounded,
                                                onTap: _prevMonth,
                                                color: _a(
                                                    AppTheme.tSecondary, 0.80),
                                                splash: _inkSplash,
                                                highlight: _inkHighlight,
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  _monthLabel(_focusedMonth),
                                                  style: _tsMonth.copyWith(
                                                    fontSize:
                                                    isNarrow ? 13.8 : 14.6,
                                                  ),
                                                  overflow:
                                                  TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              _MiniIconButton(
                                                icon:
                                                Icons.chevron_right_rounded,
                                                onTap: _nextMonth,
                                                color: _a(
                                                    AppTheme.tSecondary, 0.80),
                                                splash: _inkSplash,
                                                highlight: _inkHighlight,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: isNarrow ? 38 : 40,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          child: Row(
                                            children: [
                                              _Weekday("일",
                                                  color: sundayWeekdayInk),
                                              _Weekday("월", color: weekdayInk),
                                              _Weekday("화", color: weekdayInk),
                                              _Weekday("수", color: weekdayInk),
                                              _Weekday("목", color: weekdayInk),
                                              _Weekday("금", color: weekdayInk),
                                              _Weekday("토",
                                                  color: saturdayWeekdayInk),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Transform.translate(
                                        offset: const Offset(0, -_weekdayLift),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          child: Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: _panelBorderSoft,
                                          ),
                                        ),
                                      ),
                                      Transform.translate(
                                        offset: const Offset(0, -_weekdayLift),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              4, 1, 4, 4),
                                          child: GridView.builder(
                                            shrinkWrap: true,
                                            physics:
                                            const NeverScrollableScrollPhysics(),
                                            itemCount: 42,
                                            gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 7,
                                              mainAxisSpacing: 1.5,
                                              crossAxisSpacing: 1.5,
                                              childAspectRatio:
                                              isNarrow ? 1.32 : 1.45,
                                            ),
                                            itemBuilder: (context, i) {
                                              final day = monthCells[i];
                                              final isInMonth =
                                              _isSameMonth(day, _focusedMonth);
                                              final isSelected = day.year ==
                                                  _selectedDay.year &&
                                                  day.month ==
                                                      _selectedDay.month &&
                                                  day.day ==
                                                      _selectedDay.day;

                                              final has =
                                              hasDot(day, isInMonth);
                                              final dayColor =
                                              _dayNumberColor(
                                                day,
                                                isInMonth: isInMonth,
                                                sundayWeekdayInk:
                                                sundayWeekdayInk,
                                                saturdayWeekdayInk:
                                                saturdayWeekdayInk,
                                              );

                                              return _buildDayCell(
                                                day: day,
                                                isInMonth: isInMonth,
                                                isSelected: isSelected,
                                                has: has,
                                                dayColor: dayColor,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: _weekdayLift),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (!_bootLoading &&
                                  !_loadingDay &&
                                  cards.isNotEmpty) ...[
                                _PanelCard(
                                  fill: _panelFill,
                                  border: _panelBorder,
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      isNarrow ? 10 : 14,
                                      6,
                                      isNarrow ? 10 : 14,
                                      6,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius:
                                            BorderRadius.circular(
                                                _innerRadius),
                                            splashColor: _inkSplash,
                                            highlightColor: _inkHighlight,
                                            onTap: () => setState(() =>
                                            _cardsExpanded =
                                            !_cardsExpanded),
                                            child: Padding(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 2,
                                                vertical: 6,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.style_rounded,
                                                    size: 16,
                                                    color: _a(
                                                        AppTheme
                                                            .homeInkWarmDim,
                                                        0.82),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _cardsExpanded
                                                        ? '카드 접기'
                                                        : '카드 펼치기',
                                                    style: AppTheme
                                                        .uiSmallLabel
                                                        .copyWith(
                                                      color: _a(
                                                          AppTheme.tPrimary,
                                                          0.80),
                                                      fontSize: isNarrow
                                                          ? 11.8
                                                          : 12.2,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  AnimatedRotation(
                                                    turns:
                                                    _cardsExpanded ? 0.5 : 0,
                                                    duration: const Duration(
                                                        milliseconds: 180),
                                                    child: Icon(
                                                      Icons
                                                          .keyboard_arrow_down_rounded,
                                                      color: _a(
                                                          AppTheme
                                                              .homeInkWarmDim,
                                                          0.82),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        ClipRect(
                                          child: AnimatedSize(
                                            duration: const Duration(
                                                milliseconds: 220),
                                            curve: Curves.easeOut,
                                            alignment:
                                            Alignment.topCenter,
                                            child: Align(
                                              alignment:
                                              Alignment.topCenter,
                                              heightFactor:
                                              _cardsExpanded ? 1.0 : 0.0,
                                              child: Padding(
                                                padding:
                                                const EdgeInsets.only(
                                                    top: 6),
                                                child: SizedBox(
                                                  height: _thumbH(context),
                                                  width: double.infinity,
                                                  child:
                                                  SingleChildScrollView(
                                                    scrollDirection:
                                                    Axis.horizontal,
                                                    clipBehavior:
                                                    Clip.none,
                                                    child: ConstrainedBox(
                                                      constraints:
                                                      BoxConstraints(
                                                        minWidth: LayoutTokens
                                                            .contentW(
                                                            context) -
                                                            28,
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                        const EdgeInsets
                                                            .only(
                                                            bottom: 5),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                          mainAxisSize:
                                                          MainAxisSize.min,
                                                          children:
                                                          List.generate(
                                                              cards.length,
                                                                  (idx) {
                                                                final path =
                                                                cards[idx];
                                                                return Padding(
                                                                  padding:
                                                                  EdgeInsets.only(
                                                                    right: idx ==
                                                                        cards.length -
                                                                            1
                                                                        ? 0
                                                                        : _thumbGap(
                                                                        context),
                                                                  ),
                                                                  child: SizedBox(
                                                                    width:
                                                                    _thumbW(
                                                                        context),
                                                                    height:
                                                                    _thumbH(
                                                                        context),
                                                                    child:
                                                                    InkWell(
                                                                      borderRadius:
                                                                      BorderRadius.circular(
                                                                          10),
                                                                      onTap: () =>
                                                                          _openWriteForSelectedDay(),
                                                                      child: Hero(
                                                                        tag:
                                                                        'cal_card_$idx-$path',
                                                                        child:
                                                                        ClipRRect(
                                                                          borderRadius:
                                                                          BorderRadius.circular(10),
                                                                          child:
                                                                          Align(
                                                                            alignment:
                                                                            Alignment.center,
                                                                            child:
                                                                            ClipRect(
                                                                              child:
                                                                              Align(
                                                                                alignment:
                                                                                Alignment.center,
                                                                                widthFactor:
                                                                                _cardTrimWf,
                                                                                heightFactor:
                                                                                _cardTrimHf,
                                                                                child:
                                                                                Image.asset(
                                                                                  path,
                                                                                  fit: BoxFit.cover,
                                                                                  filterQuality: FilterQuality.high,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                );
                                                              }),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              Builder(
                                builder: (_) {
                                  final bool showLoading =
                                      _bootLoading || _loadingDay;
                                  final double panelH = entryPanelH;

                                  return SizedBox(
                                    height: panelH,
                                    width: double.infinity,
                                    child: showLoading
                                        ? Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child:
                                        CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: _strokeStrong,
                                        ),
                                      ),
                                    )
                                        : (!hasSelected
                                        ? _EmptyDayCard(
                                      stroke: _panelBorder,
                                      fill: _panelFill,
                                      inner: _panelInnerStrong,
                                      onWrite:
                                      _openWriteForSelectedDay,
                                    )
                                        : _FolderTabBody(
                                      key: ValueKey(
                                        '${_selectedDay.year}-${_selectedDay.month}-${_selectedDay.day}-${before.hashCode}-${after.hashCode}',
                                      ),
                                      selectedDay: _selectedDay,
                                      beforeText: before,
                                      afterText: after,
                                      stroke: _panelBorder,
                                      strokeSoft:
                                      _panelBorderSoft,
                                      fill: _panelFill,
                                      inner: _panelInnerStrong,
                                      onEdit:
                                          (showBeforeTab) =>
                                          _openWriteForSelectedDay(
                                            initialShowBeforeTab:
                                            showBeforeTab,
                                          ),
                                      onDelete:
                                      _confirmDeleteDialog,
                                    )),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ======================= Panel Card =======================
class _PanelCard extends StatelessWidget {
  final Widget child;
  final Color fill;
  final Color border;

  const _PanelCard({
    required this.child,
    required this.fill,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: glassPanelDecoration(
        radius: 18,
        fill: fill,
        border: border,
        shadow: true,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
    );
  }
}

class _TightIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TightIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: IconTheme(
            data: IconThemeData(color: color),
            child: Icon(icon, size: 24),
          ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color splash;
  final Color highlight;

  const _MiniIconButton({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.splash,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 360;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        splashColor: splash,
        highlightColor: highlight,
        child: SizedBox(
          width: isNarrow ? 28 : 30,
          height: isNarrow ? 28 : 30,
          child: Center(
            child: Icon(icon, size: isNarrow ? 18 : 20, color: color),
          ),
        ),
      ),
    );
  }
}

class _Weekday extends StatelessWidget {
  final String text;
  final Color color;

  const _Weekday(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 360;

    return Expanded(
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.gowunDodum(
            color: color,
            fontSize: isNarrow ? 11.8 : 12.5,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _EmptyDayCard extends StatelessWidget {
  final Color stroke;
  final Color fill;
  final Color inner;
  final VoidCallback onWrite;

  const _EmptyDayCard({
    required this.stroke,
    required this.fill,
    required this.inner,
    required this.onWrite,
  });

  @override
  Widget build(BuildContext context) {
    final tPrimary = AppTheme.tPrimary;
    final tMuted = AppTheme.tMuted;
    final isNarrow = MediaQuery.of(context).size.width < 360;

    return SizedBox.expand(
      child: _PanelCard(
        fill: fill,
        border: stroke,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isNarrow ? 14 : 16,
            14,
            isNarrow ? 14 : 16,
            14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              const SizedBox(height: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: inner,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: _a(AppTheme.headerInk, 0.10), width: 1),
                ),
                child: Text(
                  '오늘의 기록',
                  style: GoogleFonts.gowunDodum(
                    color: _a(AppTheme.tSecondary, 0.82),
                    fontSize: isNarrow ? 11.0 : 11.4,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                '아직 기록이 없어요',
                style: GoogleFonts.gowunDodum(
                  color: _a(tPrimary, 0.80),
                  fontSize: isNarrow ? 12.6 : 13.0,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '카드를 뽑고 한 줄만 적어도 충분해요.',
                style: GoogleFonts.gowunDodum(
                  color: _a(tMuted, 0.70),
                  fontSize: isNarrow ? 11.2 : 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const Spacer(),
              Center(
                child: _MiniActionChip(
                  icon: Icons.edit_rounded,
                  label: '일기 쓰기',
                  onTap: onWrite,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

enum _FolderTabKind { before, after }

class _FolderTabBody extends StatefulWidget {
  final DateTime selectedDay;
  final String beforeText;
  final String afterText;

  final Color stroke;
  final Color strokeSoft;

  final Color fill;
  final Color inner;

  final ValueChanged<bool> onEdit;
  final VoidCallback onDelete;

  const _FolderTabBody({
    super.key,
    required this.selectedDay,
    required this.beforeText,
    required this.afterText,
    required this.stroke,
    required this.strokeSoft,
    required this.fill,
    required this.inner,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_FolderTabBody> createState() => _FolderTabBodyState();
}

class _FolderTabBodyState extends State<_FolderTabBody> {
  _FolderTabKind _tab = _FolderTabKind.before;

  final ScrollController _beforeSc = ScrollController();
  final ScrollController _afterSc = ScrollController();

  @override
  void dispose() {
    _beforeSc.dispose();
    _afterSc.dispose();
    super.dispose();
  }

  bool get _afterUnlocked {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(
      widget.selectedDay.year,
      widget.selectedDay.month,
      widget.selectedDay.day,
    );
    return !today.isBefore(day);
  }

  void _onTapAfter() {
    if (_afterUnlocked) {
      setState(() => _tab = _FolderTabKind.after);
      return;
    }
    AppToast.show(
      context,
      '실제 하루는 다음날부터 열려요.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_afterUnlocked && _tab == _FolderTabKind.after) {
      _tab = _FolderTabKind.before;
    }

    final bool isBefore = _tab == _FolderTabKind.before;
    final bool isAfter = _tab == _FolderTabKind.after;
    final bool isNarrow = MediaQuery.of(context).size.width < 360;

    final String content =
    (isBefore ? widget.beforeText : widget.afterText).trim();
    final ScrollController sc = isBefore ? _beforeSc : _afterSc;

    String emptyHint() {
      if (isBefore) return "아직 예상 기록이 없어요.\n(쓰기 화면에서 저장해줘!)";
      if (!_afterUnlocked) return "실제 하루는 내일(다음날)부터 열려요.\n🔒 아직 잠겨 있어요.";
      return "아직 실제 기록이 없어요.\n(다음날부터 작성 가능)";
    }

    final bodyStyle = AppTheme.diaryText.copyWith(
      fontSize: isNarrow ? 12.6 : AppTheme.diaryText.fontSize,
    );

    return _PanelCard(
      fill: widget.fill,
      border: widget.stroke,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isNarrow ? 10 : 12,
          12,
          isNarrow ? 10 : 12,
          12,
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: widget.inner,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: widget.strokeSoft, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SegTab(
                        label: "나의 예상",
                        selected: isBefore,
                        onTap: () =>
                            setState(() => _tab = _FolderTabKind.before),
                        enabled: true,
                        leading: null,
                        stroke: widget.stroke,
                        strokeSoft: widget.strokeSoft,
                        inner: widget.inner,
                      ),
                    ),
                    Expanded(
                      child: _SegTab(
                        label: "실제 하루",
                        selected: isAfter,
                        onTap: _onTapAfter,
                        enabled: _afterUnlocked,
                        leading: _afterUnlocked
                            ? null
                            : Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: _a(AppTheme.tPrimary, 0.45),
                        ),
                        stroke: widget.stroke,
                        strokeSoft: widget.strokeSoft,
                        inner: widget.inner,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: widget.inner,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: widget.strokeSoft, width: 1),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isNarrow ? 10 : 12,
                    10,
                    10,
                    10,
                  ),
                  child: Scrollbar(
                    controller: sc,
                    thumbVisibility: true,
                    interactive: true,
                    child: SingleChildScrollView(
                      controller: sc,
                      physics: const ClampingScrollPhysics(),
                      child: Padding(
                        padding:
                        const EdgeInsets.only(right: 6, top: 2, bottom: 2),
                        child: Text(
                          content.isEmpty ? emptyHint() : content,
                          style: content.isEmpty
                              ? bodyStyle.copyWith(
                            color: _a(AppTheme.tMuted, 0.92),
                            fontSize: isNarrow ? 12.0 : 12.4,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          )
                              : bodyStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                _MiniActionChip(
                  icon: Icons.edit_rounded,
                  label: '일기 수정',
                  onTap: () => widget.onEdit(isBefore),
                ),
                _MiniActionChip(
                  icon: Icons.delete_outline_rounded,
                  label: '일기 삭제',
                  onTap: widget.onDelete,
                  danger: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _MiniActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _MiniActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color base = danger ? const Color(0xFFB45A64) : AppTheme.accent;
    final bool isNarrow = MediaQuery.of(context).size.width < 360;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        splashColor: _a(base, 0.10),
        highlightColor: _a(base, 0.05),
        child: Ink(
          height: isNarrow ? 34 : 36,
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 12),
          decoration: BoxDecoration(
            color: _a(base, danger ? 0.10 : 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _a(base, 0.22), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: isNarrow ? 15 : 16,
                  color: _a(AppTheme.tPrimary, 0.90)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.gowunDodum(
                  fontSize: isNarrow ? 11.8 : 12.2,
                  fontWeight: FontWeight.w900,
                  color: _a(AppTheme.tPrimary, 0.90),
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;
  final Widget? leading;

  final Color stroke;
  final Color strokeSoft;
  final Color inner;

  const _SegTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.leading,
    required this.stroke,
    required this.strokeSoft,
    required this.inner,
  });

  @override
  Widget build(BuildContext context) {
    final tPrimary = AppTheme.tPrimary;
    final isNarrow = MediaQuery.of(context).size.width < 360;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor:
        enabled ? _a(AppTheme.accent, 0.12) : Colors.transparent,
        highlightColor:
        enabled ? _a(AppTheme.accent, 0.06) : Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color:
            selected ? _a(AppTheme.accent, 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? Border.all(color: strokeSoft, width: 1)
                : null,
          ),
          child: Center(
            child: Padding(
              padding:
              EdgeInsets.symmetric(horizontal: isNarrow ? 6 : 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.gowunDodum(
                        color: enabled
                            ? (selected
                            ? _a(tPrimary, 0.92)
                            : _a(tPrimary, 0.62))
                            : _a(tPrimary, 0.44),
                        fontSize: isNarrow ? 12.0 : 12.6,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: selected ? 0.2 : 0.0,
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

class _ViewModeSwitchButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color stroke;

  const _ViewModeSwitchButton({required this.onTap, required this.stroke});

  @override
  Widget build(BuildContext context) {
    final tPrimary = AppTheme.tPrimary;
    final isNarrow = MediaQuery.of(context).size.width < 360;

    return Tooltip(
      message: '리스트로 보기',
      waitDuration: const Duration(milliseconds: 400),
      showDuration: const Duration(seconds: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: _a(AppTheme.accent, 0.12),
          highlightColor: _a(AppTheme.accent, 0.06),
          child: Ink(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 8 : 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: AppTheme.calendarBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: stroke, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.view_list_rounded,
                  size: isNarrow ? 15 : 16,
                  color: _a(tPrimary, 0.88),
                ),
                const SizedBox(width: 6),
                Text(
                  '리스트',
                  style: GoogleFonts.gowunDodum(
                    color: _a(tPrimary, 0.88),
                    fontSize: isNarrow ? 11.8 : 12.2,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
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