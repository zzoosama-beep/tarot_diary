// calander_diary.dart
// libray
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// page
import 'theme/app_theme.dart';
import 'list_diary.dart';
import 'write_diary.dart';

// ✅ 레이아웃 규격 토큰 (TopBox/CenterBox/BottomBox 포함)
import 'ui/layout_tokens.dart';

import 'backend/auth_service.dart';
import 'backend/diary_firestore.dart';
import 'cardpicker.dart' as cp;

enum DiaryViewMode { calendar, list }

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
  // ================== THEME (AppTheme에서 관리) ==================
  static const Color bgSolid = AppTheme.bgSolid;
  static const Color panelFill = AppTheme.panelFill;

  static const Color gold = AppTheme.gold;

  static const Color tPrimary = AppTheme.tPrimary;
  static const Color tSecondary = AppTheme.tSecondary;
  static const Color tMuted = AppTheme.tMuted;

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

  Set<int> _hasEntryKeys = <int>{};
  Map<int, List<String>> _cardAssetsByKey = <int, List<String>>{};
  Map<int, String> _beforeByKey = <int, String>{};
  Map<int, String> _afterByKey = <int, String>{};

  bool _cardsExpanded = true;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;
    _bootstrap();
  }

  // ================== 유틸 ==================
  int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  bool _isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  bool _hasEntry(DateTime day) => _hasEntryKeys.contains(_key(day));

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _monthLabel(DateTime m) => "${m.year}년 ${m.month}월";

  TextStyle get _tsTitle => AppTheme.title;
  TextStyle get _tsMonth => AppTheme.month;
  TextStyle get _tsBody => AppTheme.body;


  Future<void> _confirmDeleteDialog() async {
    final gold = AppTheme.gold;
    const Color danger = Color(0xFFB45A64);

    String _formatDateLabel(DateTime d) {
      return '${d.year}년 ${d.month}월 ${d.day}일';
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // ✅ 실수로 바깥 눌러 닫기 방지
      builder: (ctx) {
        const Color danger = Color(0xFFB45A64);
        final gold = AppTheme.gold;

        return AlertDialog(
          backgroundColor: AppTheme.bgSolid.withOpacity(0.98),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: gold.withOpacity(0.18), width: 1),
          ),
          titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          actionsPadding: const EdgeInsets.fromLTRB(14, 10, 14, 14),

          // ✅ 1) X 아이콘 -> 주의(삼각형+느낌표) 아이콘으로 교체
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded, // ⚠️ 삼각형 느낌표
                size: 22,
                color: danger.withOpacity(0.92),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '이 일기를 삭제할까요?',
                  style: GoogleFonts.gowunDodum(
                    fontSize: 14.2,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.tPrimary.withOpacity(0.92),
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

              // ✅ 3) "삭제하면 기록과 카드가~" 문구를 빨간 테두리 박스 안으로
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: danger.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: danger.withOpacity(0.55),
                    width: 1.2,
                  ),
                ),
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.gowunDodum(
                      fontSize: 12.6,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.tPrimary.withOpacity(0.86),
                      height: 1.45,
                    ),
                    children: [
                      // ✅ 날짜 강조 (골드)
                      TextSpan(
                        text: _formatDateLabel(_selectedDay),
                        style: TextStyle(
                          color: AppTheme.gold.withOpacity(0.95),
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const TextSpan(
                        text: ' 의 데이터가 삭제됩니다.\n',
                      ),

                      const TextSpan(
                        text: '삭제된 일기와 카드는 되돌릴 수 없어요!',
                      ),
                    ],
                  ),
                ),


              ),

              const SizedBox(height: 2),
              // ✅ 2) "정말 삭제할 때만 눌러주세요" 박스는 완전히 제거
            ],
          ),

          actions: [
            // ✅ 취소 하이라이트 유지
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.of(ctx).pop(false),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.gold.withOpacity(0.14),
                foregroundColor: AppTheme.tPrimary.withOpacity(0.92),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: const StadiumBorder(),
                side: BorderSide(color: AppTheme.gold.withOpacity(0.35), width: 1),
                textStyle: GoogleFonts.gowunDodum(
                  fontSize: 12.6,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: const Text('취소'),
            ),
            const SizedBox(width: 6),

            // ✅ 삭제하기: 테두리 없는 텍스트 버튼(버건디)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: danger.withOpacity(0.92),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                textStyle: GoogleFonts.gowunDodum(
                  fontSize: 12.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('삭제하기'),
            ),
          ],
        );
      },
    );

    if (ok == true) {
      // TODO: 여기서 실제 삭제 호출 (DiaryFirestore.delete 같은거)
      // 지금은 UI만: 스낵바로 확인
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
    try {
      final user = await AuthService.ensureSignedIn();
      _uid = user.uid;

      await _loadMonthDots();
      await _loadSelectedDay();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('초기화 실패: $e')),
      );
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

      setState(() {
        if (data == null) {
          _beforeByKey.remove(k);
          _afterByKey.remove(k);
          _cardAssetsByKey.remove(k);
          _hasEntryKeys.remove(k);
          return;
        }

        _beforeByKey[k] = (data['beforeText'] ?? '').toString();
        _afterByKey[k] = (data['afterText'] ?? '').toString();

        final ids =
            (data['cards'] as List?)?.map((e) => (e as num).toInt()).toList() ?? <int>[];

        String cardAssetPath(int id) {
          final safe = id.clamp(0, 77);
          return 'asset/cards/${cp.kTarotFileNames[safe]}';
        }

        _cardAssetsByKey[k] = ids.map(cardAssetPath).toList();
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
        ListDiaryPage(
          initialDate: _selectedDay,
        ),
      ),
    );
  }

  // ================== ✅ WriteDiary로 이동 (페이드) ==================
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
    if (!isInMonth) return calMuted.withOpacity(0.55);

    if (day.weekday == DateTime.sunday) return calSun.withOpacity(0.90);
    if (day.weekday == DateTime.saturday) return calSat.withOpacity(0.90);

    return calInk.withOpacity(0.88);
  }

  // ✅✅ (중요) day cell은 반드시 State 안 메서드여야 함
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
        splashColor: isInMonth ? calLine.withOpacity(0.18) : Colors.transparent,
        highlightColor: isInMonth ? calLine.withOpacity(0.10) : Colors.transparent,
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
                          color:
                          isSelected ? gold.withOpacity(0.14) : Colors.transparent,
                          border: Border.all(
                            color: gold.withOpacity(isSelected ? 0.55 : 0.40),
                            width: isSelected ? 1.4 : 1.0,
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.only(top: isSelected ? 1.0 : 1.5),
                      child: Text(
                        '${day.day}',
                        style: GoogleFonts.gowunDodum(
                          color: isToday ? gold.withOpacity(0.85) : dayColor,
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
                        color: calInk.withOpacity(isSelected ? 0.75 : 0.45),
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

  // ✅ Bottom CTA 라벨 (선택 날짜에 기록 있으면 "수정", 없으면 "쓰기")
  String _bottomCtaLabel(bool hasSelected) => hasSelected ? '일기 수정' : '일기 쓰기';

  @override
  Widget build(BuildContext context) {
    final monthCells = _buildMonthCells(_focusedMonth);

    final selectedKey = _key(_selectedDay);
    final cards = _cardAssetsByKey[selectedKey] ?? const <String>[];
    final hasSelected = _hasEntry(_selectedDay);

    final before = (_beforeByKey[selectedKey] ?? '').trim();
    final after = (_afterByKey[selectedKey] ?? '').trim();

    // ✅ BottomBox에 가려지지 않도록 스크롤 하단 여백 계산
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final safeBottom = media.padding.bottom;

    // ⛳ BottomBox 실제 높이 (필요하면 80~92 사이에서 미세조정)
    const double bottomBarH = 84;

    final scrollBottomPad =
        bottomBarH + safeBottom + LayoutTokens.scrollBottomSpacer + keyboard;


    return Scaffold(
      backgroundColor: bgSolid,
      body: SafeArea(
        child: Column(
          children: [
            // ✅ TOP + CENTER(스크롤)
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  0,
                  LayoutTokens.scrollTopPad,
                  0,
                  scrollBottomPad,
                ),

                child: Column(
                  children: [
                    // ================== ✅ 헤더 (TopBox) ==================
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

                    // ================== ✅ CENTER 묶음 ==================
                    CenterBox(
                      child: Column(
                        children: [
                          // 1) 캘린더 카드
                          _GlassCard(
                            bg: Colors.white.withOpacity(0.035),
                            border: _panelBorder,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(_radius),
                              child: Container(
                                color: Colors.white.withOpacity(0.035),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ===== 월 이동 =====
                                    Container(
                                      height: 34,
                                      padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                      decoration:
                                      const BoxDecoration(color: Colors.transparent),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _MiniIconButton(
                                            icon: Icons.chevron_left_rounded,
                                            onTap: _prevMonth,
                                            color: calInk.withOpacity(0.88),
                                            splash: _inkSplash,
                                            highlight: _inkHighlight,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(_monthLabel(_focusedMonth),
                                              style: _tsMonth),
                                          const SizedBox(width: 8),
                                          _MiniIconButton(
                                            icon: Icons.chevron_right_rounded,
                                            onTap: _nextMonth,
                                            color: calInk.withOpacity(0.88),
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
                                        borderRadius:
                                        const BorderRadius.vertical(top: Radius.circular(18)),
                                        color: Colors.white.withOpacity(0.02),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Row(
                                          children: [
                                            _Weekday("일",
                                                color: sundayInk.withOpacity(0.90)),
                                            _Weekday("월",
                                                color: headerInk.withOpacity(0.85)),
                                            _Weekday("화",
                                                color: headerInk.withOpacity(0.85)),
                                            _Weekday("수",
                                                color: headerInk.withOpacity(0.85)),
                                            _Weekday("목",
                                                color: headerInk.withOpacity(0.85)),
                                            _Weekday("금",
                                                color: headerInk.withOpacity(0.85)),
                                            _Weekday("토",
                                                color: saturdayInk.withOpacity(0.90)),
                                          ],
                                        ),
                                      ),
                                    ),

                                    Transform.translate(
                                      offset: const Offset(0, -_weekdayLift),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                        padding: const EdgeInsets.fromLTRB(4, 1, 4, 4),
                                        child: GridView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: 42,
                                          gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                                            final has = isInMonth ? _hasEntry(day) : false;
                                            final dayColor =
                                            _dayNumberColor(day, isInMonth: isInMonth);

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
                              bg: Colors.white.withOpacity(0.07),
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
                                        onTap: () =>
                                            setState(() => _cardsExpanded = !_cardsExpanded),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 2, vertical: 2),
                                          child: Row(
                                            children: [
                                              Icon(Icons.style_rounded,
                                                  size: 16, color: gold.withOpacity(0.78)),
                                              const SizedBox(width: 6),
                                              Text(
                                                _cardsExpanded ? '카드 접기' : '카드 펼치기',
                                                style: AppTheme.uiSmallLabel,
                                              ),
                                              const Spacer(),
                                              AnimatedRotation(
                                                turns: _cardsExpanded ? 0.5 : 0,
                                                duration: const Duration(milliseconds: 180),
                                                child: Icon(Icons.keyboard_arrow_down_rounded,
                                                    color: gold.withOpacity(0.80)),
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
                                                        right: idx == cards.length - 1 ? 0 : 8),
                                                    child: SizedBox(
                                                      width: 88,
                                                      child: Center(
                                                        child: AspectRatio(
                                                          aspectRatio: 2.0 / 3.1,
                                                          child: Stack(
                                                            clipBehavior: Clip.none,
                                                            children: [
                                                              Positioned.fill(
                                                                child: IgnorePointer(
                                                                  child: Transform.translate(
                                                                    offset: const Offset(0, 7),
                                                                    child: DecoratedBox(
                                                                      decoration: BoxDecoration(
                                                                        borderRadius:
                                                                        BorderRadius.circular(6),
                                                                        boxShadow: [
                                                                          BoxShadow(
                                                                            color: Colors.black
                                                                                .withOpacity(0.22),
                                                                            blurRadius: 14,
                                                                            spreadRadius: -6,
                                                                            offset: const Offset(3, 9),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              ClipRRect(
                                                                borderRadius:
                                                                BorderRadius.circular(10),
                                                                child: Stack(
                                                                  fit: StackFit.expand,
                                                                  children: [
                                                                    Align(
                                                                      alignment: Alignment.center,
                                                                      child: ClipRect(
                                                                        child: Align(
                                                                          alignment: Alignment.center,
                                                                          widthFactor: _cardTrimWf,
                                                                          heightFactor: _cardTrimHf,
                                                                          child: Image.asset(
                                                                            path,
                                                                            fit: BoxFit.cover,
                                                                            filterQuality:
                                                                            FilterQuality.high,
                                                                          ),
                                                                        ),
                                                                      ),
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
                            height: 200, // ✅ 기존 Expanded 대신, 스크롤 구조에서 안정적인 높이
                            child: LayoutBuilder(
                              builder: (context, c) {
                                if (_loadingDay) {
                                  return Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: gold.withOpacity(0.75),
                                      ),
                                    ),
                                  );
                                }

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

                          const SizedBox(height: 84 + LayoutTokens.scrollBottomSpacer),

                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ================== ✅ BOTTOM (일기 수정 + 정리[디자인만]) ==================
            BottomBox(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IntrinsicWidth(
                      child: _ActionPillButton(
                        emphasis: true,
                        label: _bottomCtaLabel(hasSelected),
                        icon: Icons.edit_rounded,
                        onPressed: _onWriteOrEdit,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // ✅ 여기
                    _SoftDeleteDummyButton(
                      onTap: () {
                        _confirmDeleteDialog();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ WriteDiary와 동일한 타이트 아이콘 버튼
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
            // ✅ 부모 IconTheme 무시하고 여기서 강제
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
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
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
            color: Colors.black.withOpacity(0.18),
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

  const _EmptyDayCard({
    required this.tsBody,
  });

  @override
  Widget build(BuildContext context) {
    final gold = AppTheme.gold;
    final tPrimary = AppTheme.tPrimary;
    final tSecondary = AppTheme.tSecondary;
    final tMuted = AppTheme.tMuted;

    return _GlassCard(
      bg: Colors.white.withOpacity(0.04),
      border: gold.withOpacity(0.18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: gold.withOpacity(0.18), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 14, color: gold.withOpacity(0.85)),
                  const SizedBox(width: 6),
                  Text(
                    '오늘의 기록',
                    style: GoogleFonts.gowunDodum(
                      color: tSecondary.withOpacity(0.85),
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
                color: tPrimary.withOpacity(0.92),
                fontSize: 13.2,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '카드를 뽑고 한 줄만 적어도 충분해요.',
              style: GoogleFonts.gowunDodum(
                color: tMuted.withOpacity(0.92),
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

  bool get _afterUnlocked {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(widget.selectedDay.year, widget.selectedDay.month, widget.selectedDay.day);
    return !today.isBefore(day); // today >= day
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

    String emptyHint() {
      if (isBefore) return "아직 예상 기록이 없어요.\n(쓰기 화면에서 저장해줘!)";
      if (!_afterUnlocked) return "실제 하루는 내일(다음날)부터 열려요.\n🔒 아직 잠겨 있어요.";
      return "아직 실제 기록이 없어요.\n(다음날부터 작성 가능)";
    }

    final bodyStyle = AppTheme.diaryText;

    final frameBorder = gold.withOpacity(0.16);

    return _GlassCard(
      bg: Colors.white.withOpacity(0.045),
      border: frameBorder,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            Container(
              height: 34,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: gold.withOpacity(0.12), width: 1),
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
                  Container(width: 1, color: gold.withOpacity(0.08)),
                  Expanded(
                    child: _SegTab(
                      label: "실제 하루",
                      selected: isAfter,
                      onTap: _onTapAfter,
                      enabled: _afterUnlocked,
                      leading: _afterUnlocked
                          ? null
                          : Icon(Icons.lock_rounded,
                          size: 14, color: AppTheme.tPrimary.withOpacity(0.55)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: gold.withOpacity(0.18),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: SingleChildScrollView(
                    child: Text(
                      content.isEmpty ? emptyHint() : content,
                      style: content.isEmpty
                          ? bodyStyle.copyWith(
                        color: AppTheme.tMuted.withOpacity(0.90),
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
          ],
        ),
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool emphasis;

  const _ActionPillButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    const double h = 36;
    final tone = AppTheme.gold;

    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        splashColor: tone.withOpacity(0.14),
        highlightColor: tone.withOpacity(0.08),
        child: Ink(
          height: h,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: emphasis
                ? tone.withOpacity(0.10)
                : const Color(0xFF2E2348).withOpacity(0.86),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: emphasis ? tone.withOpacity(0.20) : tone.withOpacity(0.30),
              width: 1,
            ),
            boxShadow: emphasis
                ? [
              BoxShadow(
                color: tone.withOpacity(0.14),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: AppTheme.editBlue.withOpacity(0.95),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.gowunDodum(
                  fontSize: 12.6,
                  fontWeight: FontWeight.w900,
                  color: tone.withOpacity(0.82),
                  height: 1.0,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================== 페이드 라우트 ==================
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
        splashColor: enabled ? gold.withOpacity(0.12) : Colors.transparent,
        highlightColor: enabled ? gold.withOpacity(0.06) : Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          height: 26,
          decoration: BoxDecoration(
            color: selected ? gold.withOpacity(0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: selected ? Border.all(color: gold.withOpacity(0.20), width: 1) : null,
            boxShadow: selected
                ? [
              BoxShadow(
                color: gold.withOpacity(0.14),
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
                        ? (selected ? tPrimary.withOpacity(0.88) : tPrimary.withOpacity(0.48))
                        : tPrimary.withOpacity(0.42),
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

  const _ViewModeSwitchButton({
    required this.onTap,
  });

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
          splashColor: gold.withOpacity(0.14),
          highlightColor: gold.withOpacity(0.08),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gold.withOpacity(0.22), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.view_list_rounded, size: 16, color: tPrimary.withOpacity(0.86)),
                const SizedBox(width: 6),
                Text(
                  '리스트',
                  style: GoogleFonts.gowunDodum(
                    color: tPrimary.withOpacity(0.86),
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

class _InsetXYClipper extends CustomClipper<Rect> {
  final double insetX; // 좌/우
  final double insetY; // 상/하
  const _InsetXYClipper({required this.insetX, required this.insetY});

  @override
  Rect getClip(Size size) {
    final double maxX = (size.width / 2) - 1;
    final double maxY = (size.height / 2) - 1;

    final double ix = insetX.clamp(0.0, maxX) as double;
    final double iy = insetY.clamp(0.0, maxY) as double;

    return Rect.fromLTWH(
      ix,
      iy,
      size.width - 2 * ix,
      size.height - 2 * iy,
    );
  }

  @override
  bool shouldReclip(covariant _InsetXYClipper old) =>
      old.insetX != insetX || old.insetY != insetY;
}


/// ✅ '일기 삭제' 더미 버튼
/// - 버튼/텍스트 색: 일기 수정과 동일
/// - X 아이콘만 버건디 → 위험도 인식 집중
class _SoftDeleteDummyButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SoftDeleteDummyButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const double h = 36;
    final gold = AppTheme.gold;
    const Color danger = Color(0xFFB45A64);

    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        splashColor: danger.withOpacity(0.18),
        highlightColor: danger.withOpacity(0.08),
        child: Ink(
          height: h,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: gold.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: gold.withOpacity(0.20), width: 1),
            boxShadow: [
              BoxShadow(
                color: gold.withOpacity(0.14),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.close_rounded, size: 22, color: danger.withOpacity(0.45)),
                  Icon(Icons.close_rounded, size: 22, color: danger.withOpacity(0.95)),
                ],
              ),
              const SizedBox(width: 4),
              Text(
                '일기 삭제',
                style: GoogleFonts.gowunDodum(
                  fontSize: 12.6,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: 0.1,
                  color: gold.withOpacity(0.82), // ✅ 노란기 살짝 완화
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

