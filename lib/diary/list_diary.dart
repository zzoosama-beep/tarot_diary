// list_diary.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../arcana/arcana_labels.dart';

import '../theme/app_theme.dart';
import '../ui/layout_tokens.dart';
import '../ui/app_buttons.dart';

import 'calander_diary.dart'; // 캘린더로 전환 (페이드)
import '../backend/diary_repo.dart';
import 'write_diary.dart';
import '../main_home_page.dart';
import '../ui/tarot_card_preview.dart';

class ListDiaryPage extends StatefulWidget {
  final DateTime? initialDate;

  const ListDiaryPage({
    super.key,
    this.initialDate,
  });

  @override
  State<ListDiaryPage> createState() => _ListDiaryPageState();
}

class _ListDiaryPageState extends State<ListDiaryPage> {
  // ===== 월 상태 =====
  late DateTime _focusedMonth;

  // ✅ 월 리스트 데이터
  bool _loading = false;
  List<_DiaryRowModel> _rows = [];

  // ✅ 정렬 토글: true=최신순(내림차순), false=과거순(오름차순)
  bool _sortDesc = true;

  // ✅ 검색 상태: 월 범위 내에서만 필터링
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    final base = widget.initialDate ?? DateTime.now();
    _focusedMonth = DateTime(base.year, base.month, 1);
    _loadMonth();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _monthLabel(DateTime m) => "${m.year}년 ${m.month}월";

  // ---------------- Search / Sort helpers ----------------

  String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  List<_DiaryRowModel> _filteredRows(List<_DiaryRowModel> input) {
    final q = _norm(_query);
    if (q.isEmpty) return input;

    return input.where((r) {
      final hay = _norm('${r.beforeText} ${r.afterText}');
      return hay.contains(q);
    }).toList();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) _clearSearch();
    });
  }

  void _clearSearch() {
    _query = '';
    _searchCtrl.clear();
    setState(() {});
  }

  void _applySort(List<_DiaryRowModel> list) {
    list.sort((a, b) =>
    _sortDesc
        ? b.date.compareTo(a.date) // 최신순
        : a.date.compareTo(b.date) // 과거순
    );
  }

  void _toggleSort() {
    setState(() {
      _sortDesc = !_sortDesc;
      _applySort(_rows); // 원본 순서도 토글에 맞춰 유지
    });
  }

  void _resetSearchOnMonthChange() {
    _query = '';
    _searchCtrl.clear();
    _searchOpen = false;
  }

  // ---------------- Month navigation ----------------

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      _resetSearchOnMonthChange();
    });
    _loadMonth();
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
      _resetSearchOnMonthChange();
    });
    _loadMonth();
  }

  // ✅ 캘린더로 이동(페이드)
  Future<void> _openCalendarPage() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      _fadeRoute(
        CalanderDiaryPage(
          initialViewMode: DiaryViewMode.calendar,
        ),
      ),
    );
  }

  Future<void> _openWriteFor(DateTime date) async {
    if (!mounted) return;

    // ✅ 리스트에서 보고 있는 날짜로 바로 연결
    final changed = await Navigator.of(context).push(
      _fadeRoute(
        WriteDiaryPage(
          selectedDate: DateTime(date.year, date.month, date.day),
          initialDate: DateTime(date.year, date.month, date.day),
        ),
      ),
    );

    // ✅ 저장/수정하고 돌아오면 리스트 갱신
    if (changed == true) {
      await _loadMonth();
    }
  }


  // ================== ✅ 로컬 DB: 월 데이터 로드 ==================
  Future<void> _loadMonth() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final docs = await DiaryRepo.I.listMonthDocs(month: _focusedMonth);

      DateTime parseDate(dynamic v) {
        if (v is DateTime) return DateTime(v.year, v.month, v.day);
        final s = (v ?? '').toString();
        final p = s.split('-');
        if (p.length == 3) {
          final y = int.tryParse(p[0]) ?? 2000;
          final m = int.tryParse(p[1]) ?? 1;
          final d = int.tryParse(p[2]) ?? 1;
          return DateTime(y, m, d);
        }
        return DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      }

      final rows = docs.map<_DiaryRowModel>((m) {
        final date = parseDate(m['dateKey'] ?? m['date']);

        final ids = (m['cards'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
            <int>[];

        final before = (m['beforeText'] ?? '').toString();
        final after = (m['afterText'] ?? '').toString();

        final safeIds = ids.take(3).map((e) => e.clamp(0, 77)).toList();

        return _DiaryRowModel(
          date: date,
          cardIds: safeIds,
          beforeText: before,
          afterText: after,
        );
      }).toList();

      _applySort(rows);

      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _rows = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 월 데이터(_rows) 안에서만 검색 필터 적용
    final rows = _filteredRows(List<_DiaryRowModel>.from(_rows));
    _applySort(rows); // 검색 결과도 현재 정렬 상태 유지

    return Scaffold(
      backgroundColor: AppTheme.bgSolid,

      // ✅ 오른쪽 하단 홈(메인) 버튼
      floatingActionButton: HomeFloatingButton(
        onPressed: () {
          Navigator.of(context).pushAndRemoveUntil(
            _fadeRoute(const MainHomePage()),
                (r) => false,
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  0,
                  LayoutTokens.scrollTopPad,
                  0,
                  LayoutTokens.scrollBottomSpacer +
                      MediaQuery
                          .of(context)
                          .viewInsets
                          .bottom,
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
                      title: Text('내 타로일기 보관함', style: AppTheme.title),
                      right: _CalendarSwitchButton(onTap: _openCalendarPage),
                    ),

                    const SizedBox(height: 12),

                    // ================== ✅ CENTER ==================
                    CenterBox(
                      child: Column(
                        children: [
                          // 1) 월 이동 Row + 우측(검색/정렬) 버튼
                          _GlassCard(
                            bg: Colors.white.withOpacity(0.035),
                            border: AppTheme.panelBorder,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
                              child: Row(
                                children: [
                                  const SizedBox(width: 4),

                                  // ✅ 월 이동: 왼쪽으로 붙이기 (오른쪽 검색/정렬은 그대로)
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _MiniIconButton(
                                            icon: Icons.chevron_left_rounded,
                                            onTap: _prevMonth,
                                            color: AppTheme.calInk.withOpacity(
                                                0.90),
                                            splash: AppTheme.inkSplash,
                                            highlight: AppTheme.inkHighlight,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(_monthLabel(_focusedMonth),
                                              style: AppTheme.month),
                                          const SizedBox(width: 6),
                                          _MiniIconButton(
                                            icon: Icons.chevron_right_rounded,
                                            onTap: _nextMonth,
                                            color: AppTheme.calInk.withOpacity(
                                                0.90),
                                            splash: AppTheme.inkSplash,
                                            highlight: AppTheme.inkHighlight,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // 오른쪽: 검색/정렬 (작게)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _TinyGhostChip(
                                        icon: Icons.search_rounded,
                                        label: '검색',
                                        onTap: _toggleSearch,
                                      ),
                                      const SizedBox(width: 8),

                                      _TinyGhostChip(
                                        icon: _sortDesc
                                            ? Icons.south_rounded
                                            : Icons.north_rounded,
                                        label: '정렬',
                                        onTap: _toggleSort,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ✅ 검색바 (월 내 검색)
                          if (_searchOpen) ...[
                            const SizedBox(height: 10),
                            _GlassCard(
                              bg: Colors.white.withOpacity(0.035),
                              border: AppTheme.panelBorder,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    12, 10, 12, 10),
                                child: Row(
                                  children: [
                                    Icon(Icons.search_rounded,
                                        size: 18,
                                        color: AppTheme.tMuted.withOpacity(
                                            0.85)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchCtrl,
                                        onChanged: (v) =>
                                            setState(() => _query = v),
                                        style: GoogleFonts.gowunDodum(
                                          color: AppTheme.tPrimary.withOpacity(
                                              0.92),
                                          fontSize: 12.8,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          border: InputBorder.none,
                                          hintText: '이 달의 기록에서 검색',
                                          hintStyle: GoogleFonts.gowunDodum(
                                            color: AppTheme.tMuted.withOpacity(
                                                0.70),
                                            fontSize: 12.4,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_query
                                        .trim()
                                        .isNotEmpty)
                                      _MiniIconButton(
                                        icon: Icons.close_rounded,
                                        onTap: _clearSearch,
                                        color: AppTheme.tPrimary.withOpacity(
                                            0.80),
                                        splash: AppTheme.inkSplash,
                                        highlight: AppTheme.inkHighlight,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 10),

                          // 2) 리스트 컨텐츠
                          if (_loading)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppTheme.gold.withOpacity(0.75),
                                  ),
                                ),
                              ),
                            )
                          else
                            if (rows.isEmpty)
                              _searchOpen && _query
                                  .trim()
                                  .isNotEmpty
                                  ? const _EmptySearchCard()
                                  : const _EmptyListCard()
                            else
                              Column(
                                children: [
                                  for (int i = 0; i < rows.length; i++) ...[
                                    _DiaryListRow(
                                      model: rows[i],
                                      onTap: () => _openWriteFor(rows[i].date),
                                    ),
                                    const SizedBox(height: 10),
                                  ]
                                ],
                              ),
                        ],
                      ),
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

// ---------------- Models ----------------

class _DiaryRowModel {
  final DateTime date;

  // ✅ 1~3장 “있는 그대로”
  final List<int> cardIds;

  // ✅ 리스트에서 보여줄 텍스트(예상/실제)
  final String beforeText;
  final String afterText;

  _DiaryRowModel({
    required this.date,
    required this.cardIds,
    required this.beforeText,
    required this.afterText,
  });
}

// ---------------- Widgets ----------------

class _DiaryListRow extends StatelessWidget {
  final _DiaryRowModel model;
  final VoidCallback onTap;

  const _DiaryListRow({
    required this.model,
    required this.onTap,
  });


  String _weekdayKo(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return '월';
      case DateTime.tuesday:
        return '화';
      case DateTime.wednesday:
        return '수';
      case DateTime.thursday:
        return '목';
      case DateTime.friday:
        return '금';
      case DateTime.saturday:
        return '토';
      case DateTime.sunday:
      default:
        return '일';
    }
  }

  String _formatKoreanDateFull(DateTime d) {
    return '${d.year}. ${d.month}. ${d.day} (${_weekdayKo(d.weekday)})';
  }

  bool _isFuture(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    return day.isAfter(today); // 내일~미래
  }

  @override
  Widget build(BuildContext context) {
    final gold = AppTheme.gold;

    final beforeTrim = model.beforeText.trim();
    final afterTrim = model.afterText.trim();

    Widget beforeBlock() {
      final tone = AppTheme.gold.withOpacity(0.85);

      if (beforeTrim.isEmpty) {
        return _BadgeOnlyLine(
          badge: "예상",
          badgeTone: tone,
        );
      }
      return _LabeledText2Lines(
        badge: "예상",
        badgeTone: tone,
        text: beforeTrim,
        textTone: AppTheme.tPrimary.withOpacity(0.86),
      );
    }

    Widget afterBlock() {
      if (afterTrim.isNotEmpty) {
        return _LabeledText2Lines(
          badge: "실제",
          badgeTone: gold.withOpacity(0.85),
          text: afterTrim,
          textTone: AppTheme.tPrimary.withOpacity(0.82),
        );
      }

      if (_isFuture(model.date)) {
        return _BadgeWithIconOnlyLine(
          badge: "실제",
          badgeTone: AppTheme.tMuted.withOpacity(0.80),
          icon: Icons.lock_rounded,
          iconTone: AppTheme.tMuted.withOpacity(0.85),
        );
      }

      return _AfterStateLine(
        badge: "실제",
        badgeTone: AppTheme.tMuted.withOpacity(0.80),
        text: "-",
        textTone: AppTheme.tMuted.withOpacity(0.82),
      );
    }

    return _GlassCard(
      bg: Colors.white.withOpacity(0.04),
      border: AppTheme.panelBorder,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          // ✅ 카드 라운드랑 동일
          borderRadius: BorderRadius.circular(18),
          splashColor: AppTheme.gold.withOpacity(0.10),
          highlightColor: AppTheme.gold.withOpacity(0.06),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _DatePill(text: _formatKoreanDateFull(model.date)),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        color: AppTheme.tMuted.withOpacity(0.55)),
                  ],
                ),
                const SizedBox(height: 10),

                Center(
                  child: _CardThumbRow(
                    cardIds: model.cardIds,
                    tagPrefix: 'list_${model.date.toIso8601String()}',
                  ),
                ),

                const SizedBox(height: 10),
                Container(height: 1, color: gold.withOpacity(0.12)),
                const SizedBox(height: 10),

                beforeBlock(),
                const SizedBox(height: 10),
                afterBlock(),
              ],
            ),
          ),
        ),
      ),
    );

  }
}

/// ✅ 카드 이미지 리스트(1~3장) - 가운데 정렬, 있는대로 표시
class _CardThumbRow extends StatelessWidget {
  final List<int> cardIds;
  final String tagPrefix;

  const _CardThumbRow({
    required this.cardIds,
    required this.tagPrefix,
  });

  String _assetOf(int id) {
    final safe = id.clamp(0, 77);
    return 'asset/cards/${ArcanaLabels.kTarotFileNames[safe]}';
  }

  @override
  Widget build(BuildContext context) {
    final gold = AppTheme.gold;
    final ids = cardIds.take(3).toList();

    // 카드가 없으면 placeholder
    if (ids.isEmpty) {
      return Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gold.withOpacity(0.14), width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.style_rounded, color: gold.withOpacity(0.55), size: 20),
      );
    }

    // ✅ 카드 1~3장: list_diary와 동일 여백(10)
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(ids.length, (i) {
        final path = _assetOf(ids[i]);

        return Padding(
          padding: EdgeInsets.only(right: i == ids.length - 1 ? 0 : 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Material(
              color: Colors.white.withOpacity(0.04),
              child: InkWell(
                onTap: () {
                  TarotCardPreview.open(
                    context,
                    assetPath: path,
                    heroTag: '${tagPrefix}_$i-$path',
                  );
                },
                child: Hero(
                  tag: '${tagPrefix}_$i-$path',
                  child: SizedBox(
                    width: 62,
                    height: 108,
                    child: Image.asset(
                      path,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(Icons.style_rounded,
                            color: gold.withOpacity(0.55), size: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}


class _DatePill extends StatelessWidget {
  final String text;
  const _DatePill({required this.text});

  @override
  Widget build(BuildContext context) {
    final gold = AppTheme.gold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: gold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gold.withOpacity(0.20), width: 1),
      ),
      child: Text(
        text,
        style: GoogleFonts.gowunDodum(
          color: AppTheme.tPrimary.withOpacity(0.90),
          fontSize: 11.6,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}

class _EmptyListCard extends StatelessWidget {
  const _EmptyListCard();

  @override
  Widget build(BuildContext context) {
    final gold = AppTheme.gold;

    return _GlassCard(
      bg: Colors.white.withOpacity(0.04),
      border: gold.withOpacity(0.18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이 달에는 아직 기록이 없어요.',
              style: GoogleFonts.gowunDodum(
                color: AppTheme.tPrimary.withOpacity(0.92),
                fontSize: 13.2,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '캘린더에서 날짜를 선택하고 일기를 작성해봐요.',
              style: GoogleFonts.gowunDodum(
                color: AppTheme.tMuted.withOpacity(0.92),
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchCard extends StatelessWidget {
  const _EmptySearchCard();

  @override
  Widget build(BuildContext context) {
    final gold = AppTheme.gold;

    return _GlassCard(
      bg: Colors.white.withOpacity(0.04),
      border: gold.withOpacity(0.18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '검색 결과가 없어요.',
              style: GoogleFonts.gowunDodum(
                color: AppTheme.tPrimary.withOpacity(0.92),
                fontSize: 13.2,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '다른 키워드로 다시 검색해보세요.',
              style: GoogleFonts.gowunDodum(
                color: AppTheme.tMuted.withOpacity(0.92),
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- “예상/실제” 라인 UI ----------------

class _Badge extends StatelessWidget {
  final String text;
  final Color tone;

  const _Badge({required this.text, required this.tone});

  @override
  Widget build(BuildContext context) {
    final gold = AppTheme.gold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gold.withOpacity(0.14), width: 1),
      ),
      child: Text(
        text,
        style: GoogleFonts.gowunDodum(
          color: tone,
          fontSize: 11.6,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}

/// ✅ 배지만 있는 라인 (예상 텍스트 비었을 때)
class _BadgeOnlyLine extends StatelessWidget {
  final String badge;
  final Color badgeTone;

  const _BadgeOnlyLine({
    required this.badge,
    required this.badgeTone,
  });

  @override
  Widget build(BuildContext context) {
    return _Badge(text: badge, tone: badgeTone);
  }
}

/// ✅ 배지 + 2줄 텍스트(말줄임)
class _LabeledText2Lines extends StatelessWidget {
  final String badge;
  final Color badgeTone;
  final String text;
  final Color textTone;

  const _LabeledText2Lines({
    required this.badge,
    required this.badgeTone,
    required this.text,
    required this.textTone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Badge(text: badge, tone: badgeTone),
        const SizedBox(height: 6),
        Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.gowunDodum(
            color: textTone,
            fontSize: 12.6,
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// ✅ 실제기록 잠김 표현: 배지 + 잠김 아이콘만
class _BadgeWithIconOnlyLine extends StatelessWidget {
  final String badge;
  final Color badgeTone;
  final IconData icon;
  final Color iconTone;

  const _BadgeWithIconOnlyLine({
    required this.badge,
    required this.badgeTone,
    required this.icon,
    required this.iconTone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Badge(text: badge, tone: badgeTone),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: iconTone),
      ],
    );
  }
}

/// ✅ 실제기록 - 기록없음
class _AfterStateLine extends StatelessWidget {
  final String badge;
  final Color badgeTone;
  final String text;
  final Color textTone;

  const _AfterStateLine({
    required this.badge,
    required this.badgeTone,
    required this.text,
    required this.textTone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Badge(text: badge, tone: badgeTone),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.gowunDodum(
            color: textTone,
            fontSize: 12.2,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

// ---------------- Small top-right chips ----------------

class _TinyGhostChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _TinyGhostChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gold = AppTheme.gold;

    final content = Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withOpacity(0.16), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.tPrimary.withOpacity(0.70)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.gowunDodum(
              color: AppTheme.tPrimary.withOpacity(0.70),
              fontSize: 11.6,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: gold.withOpacity(0.14),
        highlightColor: gold.withOpacity(0.08),
        child: content,
      ),
    );

  }
}

// ---------------- Shared UI bits ----------------

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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        splashColor: splash,
        highlightColor: highlight,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

class _CalendarSwitchButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CalendarSwitchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gold = AppTheme.gold;
    final tPrimary = AppTheme.tPrimary;

    return Tooltip(
      message: '캘린더로 보기',
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
                Icon(Icons.calendar_month_rounded,
                    size: 16, color: tPrimary.withOpacity(0.86)),
                const SizedBox(width: 6),
                Text(
                  '캘린더',
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

