// calander_diary.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/app_theme.dart';
import 'list_diary.dart';
import 'write_diary.dart';
import 'ui/tarot_card_preview.dart';

// ✅ 레이아웃 규격 토큰 (TopBox/CenterBox/BottomBox 포함)
import 'ui/layout_tokens.dart';
// ✅ 공용 CTA 버튼 (저장/수정/삭제)
import 'ui/app_buttons.dart';

import 'backend/auth_service.dart';
import 'backend/diary_firestore.dart';
import 'cardpicker.dart' as cp;

enum DiaryViewMode { calendar, list }

// ✅ withOpacity 워닝 방지용
Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class CalanderDiaryPage extends StatefulWidget {
  final DiaryViewMode initialViewMode;

  const CalanderDiaryPage({
    super.key,
    this.initialViewMode = DiaryViewMode.calendar,
  });

  @override
  State<CalanderDiaryPage> createState() => _CalanderDiaryPageState();
}

class _CalanderDiaryPageState extends State<CalanderDiaryPage> {
  // ✅ 1) 여기(필드)에 컨트롤러 선언
  final ScrollController _sc = ScrollController();


  // ✅ 2) initState() 바로 아래에 dispose 추가
  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  // ================== THEME (AppTheme에서 관리) ==================
  static const Color bgSolid = AppTheme.bgSolid;
  static const Color gold = AppTheme.gold;
  static const Color headerInk = AppTheme.headerInk;

  static const Color sundayInk = AppTheme.sundayInk;
  static const Color saturdayInk = AppTheme.saturdayInk;

  // 클릭/하이라이트
  Color get _inkSplash => AppTheme.inkSplash;
  Color get _inkHighlight => AppTheme.inkHighlight;

  // 보더
  Color get _panelBorder => AppTheme.panelBorder;
  Color get _panelBorderSoft => AppTheme.panelBorderSoft;

  // 캘린더 전용(저채도/저대비)
  static const Color calInk = AppTheme.calInk;
  static const Color calMuted = AppTheme.calMuted;
  static const Color calLine = AppTheme.calLine;
  static const Color calSun = AppTheme.calSun;
  static const Color calSat = AppTheme.calSat;

  static const double _radius = AppTheme.radius;
  static const double _innerRadius = AppTheme.innerRadius;

  // ✅ 카드 검은 테두리 트림(원본 기준, 확대 없음)
  static const double _cardTrimWf = 0.945; // 좌/우 더 많이 잘라냄
  static const double _cardTrimHf = 0.972; // 상/하 적당히

  // ✅✅ 요일-보더를 더 바짝 붙이기 위해 보더/그리드를 같이 위로 올리는 값
  static const double _weekdayLift = 6.0;

  // ================== 상태 ==================
  DiaryViewMode _viewMode = DiaryViewMode.calendar;

  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  String? _uid;

  bool _loadingDay = false;
  int _loadDayNonce = 0;

  bool _bootLoading = true; // ✅ 최초 진입 플래시 방지 핵심

  // 월 도트용
  Set<int> _hasEntryKeys = <int>{};

  // ✅✅ 선택 날짜 데이터는 월Set이 아니라 별도 상태로 들고감 (플래시 방지)
  bool _selectedHasEntry = false;
  List<String> _selectedCards = <String>[];
  String _selectedBefore = '';
  String _selectedAfter = '';

  bool _cardsExpanded = true;


  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;
    _bootstrap();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sc.jumpTo(0);
    });
  }

  // ================== 유틸 ==================
  int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  bool _isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _monthLabel(DateTime m) => "${m.year}년 ${m.month}월";

  TextStyle get _tsTitle => AppTheme.title;
  TextStyle get _tsMonth => AppTheme.month;
  TextStyle get _tsBody => AppTheme.body;

  // ================== 삭제 다이얼로그 ==================
  Future<void> _confirmDeleteDialog() async {
    String _formatDateLabel(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';
    const Color danger = Color(0xFFB45A64);

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _a(AppTheme.bgSolid, 0.98),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: _a(AppTheme.gold, 0.18), width: 1),
          ),
          titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 22, color: _a(danger, 0.92)),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14, // ✅ 여기서 박스 높이 확보
                ),
                decoration: BoxDecoration(
                  color: _a(danger, 0.06),
                  borderRadius: BorderRadius.circular(14), // 살짝만 완화
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
                          color: _a(AppTheme.gold, 0.95),
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
                const Spacer(), // ✅ 버튼들을 오른쪽으로 몰기

                // ✅ 취소
                SizedBox(
                  height: 30, // ✅ 높이 통일 (너무 높지 않게)
                  child: FilledButton(
                    autofocus: true,
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: _a(AppTheme.gold, 0.10),
                      foregroundColor: _a(AppTheme.tPrimary, 0.90),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10), // ✅ 12 -> 10 (라운드 덜)
                        side: BorderSide(color: _a(AppTheme.gold, 0.18), width: 1),
                      ),
                      textStyle: GoogleFonts.gowunDodum(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    child: const Text('취소'),
                  ),
                ),

                const SizedBox(width: 8), // ✅ 버튼 간격 줄이기 (기존 8~12보다 더 타이트하게 가능)

                // ✅ 삭제하기 (오른쪽 라인 맞추기)
                SizedBox(
                  height: 30,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _a(const Color(0xFFB45A64), 0.88),
                      foregroundColor: _a(Colors.white, 0.94),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10), // ✅ 동일하게
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
      // TODO: 실제 삭제 연결 (DiaryFirestore.delete 등)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '삭제 실행(연결 전)',
            style: GoogleFonts.gowunDodum(fontWeight: FontWeight.w800),
          ),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    }
  }

  // ================== 데이터 로딩 ==================
  Future<void> _bootstrap() async {
    if (!mounted) return;

    setState(() => _bootLoading = true);

    try {
      final user = await AuthService.ensureSignedIn();
      _uid = user.uid;

      // ✅ 월 도트 + 선택일 데이터 모두 완료된 뒤에만 bootLoading 종료
      await _loadMonthDots();
      await _loadSelectedDay();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('초기화 실패: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _bootLoading = false);
    }
  }

  Future<void> _loadMonthDots() async {
    if (_uid == null) return;

    try {
      final keys = await DiaryFirestore.listMonthEntryKeys(
        uid: _uid!,
        month: _focusedMonth,
      );
      if (!mounted) return;
      setState(() => _hasEntryKeys = keys);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasEntryKeys = <int>{});
    }
  }

  Future<void> _loadSelectedDay() async {
    if (_uid == null) return;
    final nonce = ++_loadDayNonce;

    setState(() => _loadingDay = true);

    try {
      final data = await DiaryFirestore.read(
        uid: _uid!,
        date: _selectedDay,
      );

      if (!mounted || nonce != _loadDayNonce) return;

      final k = _key(_selectedDay);

      if (data == null) {
        setState(() {
          _selectedHasEntry = false;
          _selectedBefore = '';
          _selectedAfter = '';
          _selectedCards = <String>[];

          // 월 도트 Set도 정리(이 날짜가 원래 있던 경우 제거)
          _hasEntryKeys.remove(k);
        });
        return;
      }

      final beforeText = (data['beforeText'] ?? '').toString();
      final afterText = (data['afterText'] ?? '').toString();

      final ids = (data['cards'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
          <int>[];

      String cardAssetPath(int id) {
        final safe = id.clamp(0, 77);
        return 'asset/cards/${cp.kTarotFileNames[safe]}';
      }

      final cards = ids.map(cardAssetPath).toList();

      setState(() {
        _selectedHasEntry = true;
        _selectedBefore = beforeText;
        _selectedAfter = afterText;
        _selectedCards = cards;

        _hasEntryKeys.add(k);
      });
    } finally {
      if (mounted) setState(() => _loadingDay = false);
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
    await Navigator.of(context).push(
      _fadeRoute(
        ListDiaryPage(initialDate: _selectedDay),
      ),
    );
  }

  Future<void> _onWriteOrEdit() async {
    final result = await Navigator.of(context).push(
      _fadeRoute(WriteDiaryPage(selectedDate: _selectedDay)),
    );

    if (!mounted) return;
    if (result == true) {
      await _loadMonthDots();
      await _loadSelectedDay();
    }
  }

  // ✅ 42칸 고정
  List<DateTime> _buildMonthCells(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final firstWeekdaySun0 = first.weekday % 7; // 일=0..토=6
    final gridStart = first.subtract(Duration(days: firstWeekdaySun0));
    return List<DateTime>.generate(42, (i) => gridStart.add(Duration(days: i)));
  }

  Color _dayNumberColor(DateTime day, {required bool isInMonth}) {
    if (!isInMonth) return _a(calMuted, 0.55);
    if (day.weekday == DateTime.sunday) return _a(calSun, 0.90);
    if (day.weekday == DateTime.saturday) return _a(calSat, 0.90);
    return _a(calInk, 0.88);
  }

  Widget _buildDayCell({
    required DateTime day,
    required bool isInMonth,
    required bool isSelected,
    required bool has,
    required Color dayColor,
  }) {
    final bool isToday = _isToday(day) && isInMonth;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: isInMonth ? _a(calLine, 0.18) : Colors.transparent,
        highlightColor: isInMonth ? _a(calLine, 0.10) : Colors.transparent,
        onTap: () {
          setState(() {
            _selectedDay = day;
            if (!isInMonth) {
              _focusedMonth = DateTime(day.year, day.month);
            }
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
                    if (isSelected || isToday)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOut,
                        width: 32,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: isSelected ? _a(gold, 0.14) : Colors.transparent,
                          border: Border.all(
                            color: _a(gold, isSelected ? 0.55 : 0.40),
                            width: isSelected ? 1.4 : 1.0,
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.only(top: isSelected ? 1.0 : 1.5),
                      child: Text(
                        '${day.day}',
                        style: GoogleFonts.gowunDodum(
                          color: isToday ? _a(gold, 0.85) : dayColor,
                          fontSize: isSelected ? 13.2 : 12.9,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
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
                        color: _a(calInk, isSelected ? 0.75 : 0.45),
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

  String _bottomCtaLabel(bool hasSelected) => hasSelected ? '일기 수정' : '일기 쓰기';

  @override
  Widget build(BuildContext context) {
    final monthCells = _buildMonthCells(_focusedMonth);

    // ✅ 이제 선택 날짜 유무는 이 값만 봄(플래시 방지)
    final hasSelected = _selectedHasEntry;

    final cards = _selectedCards;
    final before = _selectedBefore.trim();
    final after = _selectedAfter.trim();

    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;

    // ✅ 키보드가 열릴 때만 bottom padding을 준다 (평소엔 0)
    final double scrollBottomPad = keyboard > 0 ? keyboard + 12.0 : 0.0;


    // ✅ 월 셀 has는 월 도트 Set 기준(가벼움)
    bool hasDot(DateTime day, bool inMonth) => inMonth ? _hasEntryKeys.contains(_key(day)) : false;

    return Scaffold(
      backgroundColor: bgSolid,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _sc,
                primary: false, // ✅ 자동 스크롤 위치 복원 끔
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(0, LayoutTokens.scrollTopPad, 0, scrollBottomPad),
                child: Column(
                  children: [
                    TopBox(
                      left: Transform.translate(
                        offset: const Offset(LayoutTokens.backBtnNudgeX, 0),
                        child: _TightIconButton(
                          icon: Icons.arrow_back_rounded,
                          color: AppTheme.headerInk,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      title: Text('내 타로일기 보관함', style: _tsTitle),
                      right: _ViewModeSwitchButton(onTap: _openListPage),
                    ),
                    const SizedBox(height: 16),

                    CenterBox(
                      child: Column(
                        children: [
                          // 1) 캘린더 카드
                          _GlassCard(
                            bg: _a(Colors.white, 0.035),
                            border: _panelBorder,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(_radius),
                              child: Container(
                                color: _a(Colors.white, 0.035),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ===== 월 이동 =====
                                    Container(
                                      height: 34,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      decoration: const BoxDecoration(color: Colors.transparent),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _MiniIconButton(
                                            icon: Icons.chevron_left_rounded,
                                            onTap: _prevMonth,
                                            color: _a(calInk, 0.88),
                                            splash: _inkSplash,
                                            highlight: _inkHighlight,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(_monthLabel(_focusedMonth), style: _tsMonth),
                                          const SizedBox(width: 8),
                                          _MiniIconButton(
                                            icon: Icons.chevron_right_rounded,
                                            onTap: _nextMonth,
                                            color: _a(calInk, 0.88),
                                            splash: _inkSplash,
                                            highlight: _inkHighlight,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // ===== 요일 =====
                                    Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                        color: _a(Colors.white, 0.02),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Row(
                                          children: [
                                            _Weekday("일", color: _a(sundayInk, 0.90)),
                                            _Weekday("월", color: _a(headerInk, 0.85)),
                                            _Weekday("화", color: _a(headerInk, 0.85)),
                                            _Weekday("수", color: _a(headerInk, 0.85)),
                                            _Weekday("목", color: _a(headerInk, 0.85)),
                                            _Weekday("금", color: _a(headerInk, 0.85)),
                                            _Weekday("토", color: _a(saturdayInk, 0.90)),
                                          ],
                                        ),
                                      ),
                                    ),

                                    Transform.translate(
                                      offset: const Offset(0, -_weekdayLift),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Divider(height: 1, thickness: 1, color: _panelBorderSoft),
                                      ),
                                    ),

                                    Transform.translate(
                                      offset: const Offset(0, -_weekdayLift),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(4, 1, 4, 4),
                                        child: GridView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: 42,
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 7,
                                            mainAxisSpacing: 1.5,
                                            crossAxisSpacing: 1.5,
                                            childAspectRatio: 1.45,
                                          ),
                                          itemBuilder: (context, i) {
                                            final day = monthCells[i];
                                            final isInMonth = _isSameMonth(day, _focusedMonth);
                                            final isSelected = day.year == _selectedDay.year &&
                                                day.month == _selectedDay.month &&
                                                day.day == _selectedDay.day;

                                            final has = hasDot(day, isInMonth);
                                            final dayColor = _dayNumberColor(day, isInMonth: isInMonth);

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
                          ),

                          const SizedBox(height: 10),

                          // 2) 카드 리스트 (있을 때만)
                          if (cards.isNotEmpty) ...[
                            _GlassCard(
                              bg: _a(Colors.white, 0.07),
                              border: _panelBorder,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(_innerRadius),
                                        splashColor: _inkSplash,
                                        highlightColor: _inkHighlight,
                                        onTap: () => setState(() => _cardsExpanded = !_cardsExpanded),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                          child: Row(
                                            children: [
                                              Icon(Icons.style_rounded, size: 16, color: _a(gold, 0.78)),
                                              const SizedBox(width: 6),
                                              Text(_cardsExpanded ? '카드 접기' : '카드 펼치기', style: AppTheme.uiSmallLabel),
                                              const Spacer(),
                                              AnimatedRotation(
                                                turns: _cardsExpanded ? 0.5 : 0,
                                                duration: const Duration(milliseconds: 180),
                                                child: Icon(Icons.keyboard_arrow_down_rounded, color: _a(gold, 0.80)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    AnimatedCrossFade(
                                      duration: const Duration(milliseconds: 220),
                                      crossFadeState: _cardsExpanded
                                          ? CrossFadeState.showSecond
                                          : CrossFadeState.showFirst,
                                      firstChild: const SizedBox.shrink(),
                                      secondChild: Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: SizedBox(
                                          height: 120,
                                          child: Center(
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              clipBehavior: Clip.none,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: List.generate(cards.length, (idx) {
                                                  final path = cards[idx];
                                                  return Padding(
                                                    padding: EdgeInsets.only(
                                                      right: idx == cards.length - 1 ? 0 : 8,
                                                    ),
                                                    child: SizedBox(
                                                      width: 88,
                                                      child: InkWell(
                                                        borderRadius: BorderRadius.circular(10),
                                                        onTap: () {
                                                          TarotCardPreview.open(
                                                            context,
                                                            assetPath: path,
                                                            heroTag: 'cal_card_$idx-$path',
                                                          );
                                                        },
                                                        child: Hero(
                                                          tag: 'cal_card_$idx-$path',
                                                          child: AspectRatio(
                                                            aspectRatio: 2.0 / 3.1,
                                                            child: ClipRRect(
                                                              borderRadius: BorderRadius.circular(10),
                                                              child: Align(
                                                                alignment: Alignment.center,
                                                                child: ClipRect(
                                                                  child: Align(
                                                                    alignment: Alignment.center,
                                                                    widthFactor: _cardTrimWf,
                                                                    heightFactor: _cardTrimHf,
                                                                    child: Image.asset(
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
                                                    ),
                                                  );

                                                }),
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

                          // 3) 텍스트 박스(내용)
                          SizedBox(
                            height: 200,
                            child: Builder(
                              builder: (_) {
                                // ✅✅ 핵심: bootLoading/loadingDay 동안은 무조건 로딩만
                                final bool showLoading = _bootLoading || _loadingDay || _uid == null;

                                if (showLoading) {
                                  return Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: _a(gold, 0.75),
                                      ),
                                    ),
                                  );
                                }

                                // ✅ 여기부터는 "진짜 판단"만
                                if (!hasSelected) {
                                  return _EmptyDayCard(tsBody: _tsBody);
                                }

                                return _FolderTabBody(
                                  selectedDay: _selectedDay,
                                  beforeText: before,
                                  afterText: after,
                                );
                              },
                            ),
                          ),


                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ================== ✅ BOTTOM ==================
            BottomBox(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120, // 👈 여기서 직접 width 조절
                    child: AppDiaryPillButton(
                      label: _bottomCtaLabel(hasSelected),
                      icon: Icons.edit_rounded,
                      onPressed: _onWriteOrEdit,
                      danger: false,
                      height: 40,
                      fontSize: 13.2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 120, // 👈 동일
                    child: AppDiaryPillButton(
                      label: '일기 삭제',
                      icon: Icons.close_rounded,
                      onPressed: hasSelected ? _confirmDeleteDialog : null,
                      danger: true,
                      height: 40,
                      fontSize: 13.2,
                    ),
                  ),
                ],
              ),

            ),

          ],
        ),
      ),
    );
  }
}

/// ✅ WriteDiary와 동일한 타이트 아이콘 버튼 (색 강제)
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

/// 작은 월 이동 버튼
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        splashColor: splash,
        highlightColor: highlight,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: Icon(icon, size: 20, color: color),
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
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.gowunDodum(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

/// ======================= 유리 카드 =======================
class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color bg;
  final Color border;

  const _GlassCard({
    required this.child,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
    );
  }
}

/// ======================= Empty Day =======================
class _EmptyDayCard extends StatelessWidget {
  final TextStyle tsBody;

  const _EmptyDayCard({required this.tsBody});

  @override
  Widget build(BuildContext context) {
    final gold = AppTheme.gold;
    final tPrimary = AppTheme.tPrimary;
    final tSecondary = AppTheme.tSecondary;
    final tMuted = AppTheme.tMuted;

    return _GlassCard(
      bg: _a(Colors.white, 0.04),
      border: _a(gold, 0.18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _a(Colors.white, 0.05),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _a(gold, 0.18), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 14, color: _a(gold, 0.85)),
                  const SizedBox(width: 6),
                  Text(
                    '오늘의 기록',
                    style: GoogleFonts.gowunDodum(
                      color: _a(tSecondary, 0.85),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '아직 기록이 없어요',
              style: GoogleFonts.gowunDodum(
                color: _a(tPrimary, 0.92),
                fontSize: 13.2,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '카드를 뽑고 한 줄만 적어도 충분해요.',
              style: GoogleFonts.gowunDodum(
                color: _a(tMuted, 0.92),
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// ======================= 폴더 탭 (Before/After) =======================
enum _FolderTabKind { before, after }

class _FolderTabBody extends StatefulWidget {

  final DateTime selectedDay;
  final String beforeText;
  final String afterText;

  const _FolderTabBody({
    required this.selectedDay,
    required this.beforeText,
    required this.afterText,
  });

  @override
  State<_FolderTabBody> createState() => _FolderTabBodyState();
}

class _FolderTabBodyState extends State<_FolderTabBody> {
  _FolderTabKind _tab = _FolderTabKind.before;

  // ✅ 스크롤 컨트롤러
  final ScrollController _beforeSc = ScrollController();
  final ScrollController _afterSc = ScrollController();

  // ✅ dispose
  @override
  void dispose() {
    _beforeSc.dispose();
    _afterSc.dispose();
    super.dispose();
  }

  bool get _afterUnlocked {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(widget.selectedDay.year, widget.selectedDay.month, widget.selectedDay.day);
    return !today.isBefore(day);
  }

  void _onTapAfter() {
    if (_afterUnlocked) {
      setState(() => _tab = _FolderTabKind.after);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '실제 하루는 다음날부터 열려요.',
          style: GoogleFonts.gowunDodum(fontWeight: FontWeight.w700),
        ),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gold = AppTheme.gold;

    if (!_afterUnlocked && _tab == _FolderTabKind.after) {
      _tab = _FolderTabKind.before;
    }

    final bool isBefore = _tab == _FolderTabKind.before;
    final bool isAfter = _tab == _FolderTabKind.after;

    final String content = (isBefore ? widget.beforeText : widget.afterText).trim();
    final ScrollController sc = isBefore ? _beforeSc : _afterSc;

    String emptyHint() {
      if (isBefore) return "아직 예상 기록이 없어요.\n(쓰기 화면에서 저장해줘!)";
      if (!_afterUnlocked) return "실제 하루는 내일(다음날)부터 열려요.\n🔒 아직 잠겨 있어요.";
      return "아직 실제 기록이 없어요.\n(다음날부터 작성 가능)";
    }

    final bodyStyle = AppTheme.diaryText;
    final frameBorder = _a(gold, 0.16);

    return _GlassCard(
      bg: _a(Colors.white, 0.045),
      border: frameBorder,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            // ===== 탭 =====
            Container(
              height: 34,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _a(gold, 0.12), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SegTab(
                      label: "나의 예상",
                      selected: isBefore,
                      onTap: () => setState(() => _tab = _FolderTabKind.before),
                      enabled: true,
                      leading: null,
                    ),
                  ),
                  Container(width: 1, color: _a(gold, 0.08)),
                  Expanded(
                    child: _SegTab(
                      label: "실제 하루",
                      selected: isAfter,
                      onTap: _onTapAfter,
                      enabled: _afterUnlocked,
                      leading: _afterUnlocked
                          ? null
                          : Icon(Icons.lock_rounded, size: 14, color: _a(AppTheme.tPrimary, 0.55)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ===== 본문 + 스크롤바 (양쪽 탭 공통) =====
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _a(Colors.white, 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _a(gold, 0.18), width: 1),
                ),
                child: Padding(
                  // ✅ 오른쪽 여백 살짝(스크롤바 공간)
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: ScrollbarTheme(
                    data: ScrollbarThemeData(
                      // ✅ 회색 대신 "안 튀는 골드톤"으로
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        final active = states.contains(WidgetState.dragged) ||
                            states.contains(WidgetState.hovered);
                        return _a(AppTheme.gold, active ? 0.40 : 0.22);
                      }),
                      // ✅ 트랙도 거의 안 보이게
                      trackColor: WidgetStateProperty.all(_a(Colors.white, 0.02)),
                      trackBorderColor: WidgetStateProperty.all(Colors.transparent),
                      radius: const Radius.circular(999),
                      thickness: WidgetStateProperty.all(3.0),
                    ),
                    child: Scrollbar(
                      controller: sc,
                      thumbVisibility: true,
                      interactive: true,
                      child: SingleChildScrollView(
                        controller: sc,
                        physics: const ClampingScrollPhysics(),
                        child: Padding(
                          // ✅ 라운드 박스라 위/아래 살짝 띄워서 “붕 뜸” 방지
                          padding: const EdgeInsets.only(right: 6, top: 2, bottom: 2),
                          child: Text(
                            content.isEmpty ? emptyHint() : content,
                            style: content.isEmpty
                                ? bodyStyle.copyWith(
                              color: _a(AppTheme.tMuted, 0.90),
                              fontSize: 12.4,
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
            ),
          ],
        ),
      ),
    );
  }

}


/// ======================= 세그먼트 탭 =======================
class _SegTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;
  final Widget? leading;

  const _SegTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final gold = AppTheme.gold;
    final tPrimary = AppTheme.tPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: enabled ? _a(gold, 0.12) : Colors.transparent,
        highlightColor: enabled ? _a(gold, 0.06) : Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          height: 26,
          decoration: BoxDecoration(
            color: selected ? _a(gold, 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: selected ? Border.all(color: _a(gold, 0.20), width: 1) : null,
            boxShadow: selected
                ? [
              BoxShadow(
                color: _a(gold, 0.14),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: GoogleFonts.gowunDodum(
                    color: enabled
                        ? (selected ? _a(tPrimary, 0.88) : _a(tPrimary, 0.48))
                        : _a(tPrimary, 0.42),
                    fontSize: 12.6,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: selected ? 0.2 : 0.0,
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

class _ViewModeSwitchButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ViewModeSwitchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gold = AppTheme.gold;
    final tPrimary = AppTheme.tPrimary;

    return Tooltip(
      message: '리스트로 보기',
      waitDuration: const Duration(milliseconds: 400),
      showDuration: const Duration(seconds: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: _a(gold, 0.14),
          highlightColor: _a(gold, 0.08),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _a(Colors.white, 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _a(gold, 0.22), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.view_list_rounded, size: 16, color: _a(tPrimary, 0.86)),
                const SizedBox(width: 6),
                Text(
                  '리스트',
                  style: GoogleFonts.gowunDodum(
                    color: _a(tPrimary, 0.86),
                    fontSize: 12.2,
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

/// ================== 페이드 라우트 ==================
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
