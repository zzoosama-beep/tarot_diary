import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../arcana/arcana_labels.dart';

import '../theme/app_theme.dart';
import '../ui/layout_tokens.dart';
import '../ui/app_buttons.dart';

import 'calander_diary.dart';
import '../backend/diary_repo.dart';
import '../error/error_reporter.dart';
import 'edit_diary.dart';
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
  late DateTime _focusedMonth;

  final Map<String, bool> _rowCollapsedByKey = {};
  String _rowKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  bool _loading = false;
  List<_DiaryRowModel> _rows = [];

  bool _sortDesc = true;

  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _didInitialLoad = false;

  @override
  void initState() {
    super.initState();
    final base = widget.initialDate ?? DateTime.now();
    _focusedMonth = DateTime(base.year, base.month, 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didInitialLoad) {
      _didInitialLoad = true;
      _loadMonth();
      return;
    }

    _loadMonth();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _monthLabel(DateTime m) => "${m.year}년 ${m.month}월";

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
    list.sort(
          (a, b) => _sortDesc
          ? b.date.compareTo(a.date)
          : a.date.compareTo(b.date),
    );
  }

  void _toggleSort() {
    setState(() {
      _sortDesc = !_sortDesc;
      _applySort(_rows);
    });
  }

  void _resetSearchOnMonthChange() {
    _query = '';
    _searchCtrl.clear();
    _searchOpen = false;
  }

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

  Future<void> _openCalendarPage() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      _fadeRoute(
        CalanderDiaryPage(
          initialViewMode: DiaryViewMode.calendar,
          selectedDate: DateTime(_focusedMonth.year, _focusedMonth.month, 1),
        ),
      ),
    );
  }

  void _showUserMessage(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.gowunDodum(
              fontSize: 13.2,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  String _readDiaryErrorMessage() {
    return '기록을 열지 못했습니다.\n잠시 후 다시 시도해주세요.';
  }

  String _loadMonthErrorMessage() {
    return '이 달의 기록을 불러오지 못했습니다.\n잠시 후 다시 시도해주세요.';
  }

  Future<void> _openWriteFor(DateTime date) async {
    if (!mounted) return;

    final safeDate = DateTime(date.year, date.month, date.day);

    try {
      final data = await DiaryRepo.I.read(date: safeDate);
      if (!mounted) return;

      if (data == null) {
        _showUserMessage('선택한 날짜의 기록을 찾지 못했습니다.');
        return;
      }

      final List<int> pickedCardIds =
          (data['cards'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
              <int>[];

      final int cardCount =
      ((data['cardCount'] as int?) ?? pickedCardIds.length).clamp(1, 3);

      final String initialBeforeText = (data['beforeText'] ?? '').toString();
      final String initialAfterText = (data['afterText'] ?? '').toString();

      final changed = await Navigator.of(context).push(
        _fadeRoute(
          EditDiaryPage(
            pickedCardIds: pickedCardIds.take(cardCount).toList(),
            cardCount: cardCount,
            selectedDate: safeDate,
            initialBeforeText: initialBeforeText,
            initialAfterText: initialAfterText,
          ),
        ),
      );

      if (changed == true) {
        await _loadMonth();
      }
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'ListDiaryPage._openWriteFor',
        error: e,
        stackTrace: st,
        extra: {
          'date': safeDate.toIso8601String(),
        },
      );

      if (!mounted) return;
      _showUserMessage(_readDiaryErrorMessage());
    }
  }

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
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'ListDiaryPage._loadMonth',
        error: e,
        stackTrace: st,
        extra: {
          'focusedMonth': _focusedMonth.toIso8601String(),
        },
      );

      if (!mounted) return;
      setState(() => _rows = []);
      _showUserMessage(_loadMonthErrorMessage());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  double _pageSidePadding(double width) {
    if (width < 360) return 12;
    if (width < 430) return 14;
    return 18;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows(List<_DiaryRowModel>.from(_rows));
    _applySort(rows);

    final bg = AppTheme.bgColor;
    final panel = AppTheme.panelFill;
    final panelBorder = AppTheme.panelBorder;
    final chipBg = AppTheme.calendarBg;

    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 360;
    final sidePad = _pageSidePadding(width);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  sidePad,
                  LayoutTokens.scrollTopPad,
                  sidePad,
                  LayoutTokens.scrollBottomSpacer +
                      MediaQuery.of(context).viewInsets.bottom,
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
                        style: AppTheme.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                      right: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CalendarSwitchButton(onTap: _openCalendarPage),
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
                          _GlassCard(
                            bg: panel,
                            border: panelBorder,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                isNarrow ? 8 : 10,
                                10,
                                isNarrow ? 8 : 10,
                                10,
                              ),
                              child: Column(
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final compact = constraints.maxWidth < 340;

                                      if (compact) {
                                        return Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                _MiniIconButton(
                                                  icon: Icons.chevron_left_rounded,
                                                  onTap: _prevMonth,
                                                  color: AppTheme.a(
                                                    AppTheme.tSecondary,
                                                    0.88,
                                                  ),
                                                  splash: AppTheme.inkSplash,
                                                  highlight:
                                                  AppTheme.inkHighlight,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    _monthLabel(_focusedMonth),
                                                    style: AppTheme.month,
                                                    overflow:
                                                    TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                _MiniIconButton(
                                                  icon: Icons.chevron_right_rounded,
                                                  onTap: _nextMonth,
                                                  color: AppTheme.a(
                                                    AppTheme.tSecondary,
                                                    0.88,
                                                  ),
                                                  splash: AppTheme.inkSplash,
                                                  highlight:
                                                  AppTheme.inkHighlight,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _TinyGhostChip(
                                                  icon: Icons.search_rounded,
                                                  label: '검색',
                                                  bg: chipBg,
                                                  border: panelBorder,
                                                  onTap: _toggleSearch,
                                                ),
                                                _TinyGhostChip(
                                                  icon: _sortDesc
                                                      ? Icons.south_rounded
                                                      : Icons.north_rounded,
                                                  label: '정렬',
                                                  bg: chipBg,
                                                  border: panelBorder,
                                                  onTap: _toggleSort,
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      }

                                      return Row(
                                        children: [
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _MiniIconButton(
                                                    icon: Icons.chevron_left_rounded,
                                                    onTap: _prevMonth,
                                                    color: AppTheme.a(
                                                      AppTheme.tSecondary,
                                                      0.88,
                                                    ),
                                                    splash: AppTheme.inkSplash,
                                                    highlight:
                                                    AppTheme.inkHighlight,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      _monthLabel(_focusedMonth),
                                                      style: AppTheme.month,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  _MiniIconButton(
                                                    icon: Icons.chevron_right_rounded,
                                                    onTap: _nextMonth,
                                                    color: AppTheme.a(
                                                      AppTheme.tSecondary,
                                                      0.88,
                                                    ),
                                                    splash: AppTheme.inkSplash,
                                                    highlight:
                                                    AppTheme.inkHighlight,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _TinyGhostChip(
                                                icon: Icons.search_rounded,
                                                label: '검색',
                                                bg: chipBg,
                                                border: panelBorder,
                                                onTap: _toggleSearch,
                                              ),
                                              _TinyGhostChip(
                                                icon: _sortDesc
                                                    ? Icons.south_rounded
                                                    : Icons.north_rounded,
                                                label: '정렬',
                                                bg: chipBg,
                                                border: panelBorder,
                                                onTap: _toggleSort,
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  if (_searchOpen) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      height: 1,
                                      color: AppTheme.panelBorderSoft,
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isNarrow ? 8 : 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.diaryFieldBg,
                                        borderRadius:
                                        BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppTheme.panelBorderSoft,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.search_rounded,
                                            size: 17,
                                            color: AppTheme.a(
                                              AppTheme.tMuted,
                                              0.80,
                                            ),
                                          ),
                                          const SizedBox(width: 7),
                                          Expanded(
                                            child: TextField(
                                              controller: _searchCtrl,
                                              onChanged: (v) =>
                                                  setState(() => _query = v),
                                              style: GoogleFonts.gowunDodum(
                                                color: AppTheme.a(
                                                  AppTheme.tPrimary,
                                                  0.92,
                                                ),
                                                fontSize:
                                                isNarrow ? 12.2 : 12.6,
                                                fontWeight: FontWeight.w700,
                                                height: 1.2,
                                              ),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                border: InputBorder.none,
                                                contentPadding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 4,
                                                ),
                                                hintText: '이 달의 기록에서 검색',
                                                hintStyle:
                                                GoogleFonts.gowunDodum(
                                                  color: AppTheme.a(
                                                    AppTheme.tMuted,
                                                    0.72,
                                                  ),
                                                  fontSize:
                                                  isNarrow ? 12.0 : 12.4,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (_query.trim().isNotEmpty)
                                            _MiniIconButton(
                                              icon: Icons.close_rounded,
                                              onTap: _clearSearch,
                                              color: AppTheme.a(
                                                AppTheme.tPrimary,
                                                0.80,
                                              ),
                                              splash: AppTheme.inkSplash,
                                              highlight:
                                              AppTheme.inkHighlight,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_loading)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppTheme.a(
                                      AppTheme.accent,
                                      0.80,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else if (rows.isEmpty)
                            SizedBox(
                              width: double.infinity,
                              child: _searchOpen && _query.trim().isNotEmpty
                                  ? const _EmptySearchCard()
                                  : const _EmptyListCard(),
                            )
                          else
                            Column(
                              children: [
                                for (int i = 0; i < rows.length; i++) ...[
                                  Builder(
                                    builder: (_) {
                                      final k = _rowKey(rows[i].date);
                                      final collapsed =
                                          _rowCollapsedByKey[k] ?? false;

                                      return _DiaryListRow(
                                        model: rows[i],
                                        onTap: () =>
                                            _openWriteFor(rows[i].date),
                                        collapsed: collapsed,
                                        onToggleCollapsed: () {
                                          setState(() {
                                            _rowCollapsedByKey[k] = !collapsed;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                ],
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

class _DiaryRowModel {
  final DateTime date;
  final List<int> cardIds;
  final String beforeText;
  final String afterText;

  _DiaryRowModel({
    required this.date,
    required this.cardIds,
    required this.beforeText,
    required this.afterText,
  });
}

class _DiaryListRow extends StatelessWidget {
  final _DiaryRowModel model;
  final VoidCallback onTap;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  const _DiaryListRow({
    required this.model,
    required this.onTap,
    required this.collapsed,
    required this.onToggleCollapsed,
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

  String _formatKoreanDateFull(DateTime d) =>
      '${d.year}. ${d.month}. ${d.day} (${_weekdayKo(d.weekday)})';

  bool _isFuture(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    return day.isAfter(today);
  }

  @override
  Widget build(BuildContext context) {
    final panelBorder = AppTheme.panelBorder;
    final panelBorderSoft = AppTheme.panelBorderSoft;
    final isNarrow = MediaQuery.of(context).size.width < 360;

    final beforeTrim = model.beforeText.trim();
    final afterTrim = model.afterText.trim();

    Widget beforeBlock() {
      final tone = AppTheme.a(AppTheme.accent, 0.88);
      if (beforeTrim.isEmpty) {
        return _BadgeOnlyLine(
          badge: '예상',
          badgeTone: tone,
        );
      }
      return _LabeledText2Lines(
        badge: '예상',
        badgeTone: tone,
        text: beforeTrim,
        textTone: AppTheme.a(AppTheme.tPrimary, 0.88),
        maxLines: 6,
      );
    }

    Widget afterBlock() {
      final tone = AppTheme.a(AppTheme.accentDeep, 0.88);
      if (afterTrim.isNotEmpty) {
        return _LabeledText2Lines(
          badge: '실제',
          badgeTone: tone,
          text: afterTrim,
          textTone: AppTheme.a(AppTheme.tPrimary, 0.84),
          maxLines: 6,
        );
      }

      if (_isFuture(model.date)) {
        return _BadgeWithIconOnlyLine(
          badge: '실제',
          badgeTone: AppTheme.a(AppTheme.tMuted, 0.76),
          icon: Icons.lock_rounded,
          iconTone: AppTheme.a(AppTheme.tMuted, 0.82),
        );
      }

      return _AfterStateLine(
        badge: '실제',
        badgeTone: AppTheme.a(AppTheme.tMuted, 0.76),
        text: '-',
        textTone: AppTheme.a(AppTheme.tMuted, 0.82),
      );
    }

    return _GlassCard(
      bg: AppTheme.panelFill,
      border: panelBorder,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isNarrow ? 10 : 12,
            10,
            isNarrow ? 10 : 12,
            10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _formatKoreanDateFull(model.date),
                      style: GoogleFonts.gowunDodum(
                        color: AppTheme.a(AppTheme.tPrimary, 0.92),
                        fontSize: isNarrow ? 12.0 : 12.4,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _PlainToggleButton(
                    collapsed: collapsed,
                    onTap: onToggleCollapsed,
                  ),
                ],
              ),
              if (collapsed) ...[
                const SizedBox(height: 6),
              ] else ...[
                const SizedBox(height: 10),
                Center(
                  child: _CardThumbRow(
                    cardIds: model.cardIds,
                    tagPrefix: 'list_${model.date.toIso8601String()}',
                  ),
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: panelBorderSoft),
                const SizedBox(height: 10),
                beforeBlock(),
                const SizedBox(height: 10),
                afterBlock(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlainToggleButton extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onTap;

  const _PlainToggleButton({
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon =
    collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: AppTheme.inkSplash,
        highlightColor: AppTheme.inkHighlight,
        child: SizedBox(
          width: 34,
          height: 28,
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: AppTheme.a(AppTheme.tMuted, 0.88),
            ),
          ),
        ),
      ),
    );
  }
}

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
    final ids = cardIds.take(3).toList();
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 360;

    final thumbW = isNarrow ? 54.0 : 62.0;
    final thumbH = isNarrow ? 94.0 : 108.0;
    final gap = isNarrow ? 8.0 : 10.0;

    if (ids.isEmpty) {
      return Container(
        width: isNarrow ? 66 : 74,
        height: isNarrow ? 66 : 74,
        decoration: BoxDecoration(
          color: AppTheme.a(Colors.white, 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.panelBorderSoft, width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.style_rounded,
          color: AppTheme.a(AppTheme.tMuted, 0.70),
          size: 20,
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: gap,
      runSpacing: gap,
      children: List.generate(ids.length, (i) {
        final path = _assetOf(ids[i]);

        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Material(
            color: AppTheme.a(Colors.white, 0.04),
            child: InkWell(
              splashColor: AppTheme.inkSplash,
              highlightColor: AppTheme.inkHighlight,
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
                  width: thumbW,
                  height: thumbH,
                  child: Image.asset(
                    path,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.style_rounded,
                        color: AppTheme.a(AppTheme.tMuted, 0.70),
                        size: 18,
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

class _EmptyListCard extends StatelessWidget {
  const _EmptyListCard();

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 360;

    return _GlassCard(
      bg: AppTheme.panelFill,
      border: AppTheme.panelBorder,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 108),
        padding: EdgeInsets.fromLTRB(
          isNarrow ? 16 : 18,
          18,
          isNarrow ? 16 : 18,
          18,
        ),
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이 달에는 아직 기록이 없어요.',
              style: GoogleFonts.gowunDodum(
                color: AppTheme.a(AppTheme.tPrimary, 0.78),
                fontSize: isNarrow ? 13.0 : 13.6,
                fontWeight: FontWeight.w900,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '캘린더에서 날짜를 선택하고 일기를 작성해보세요.',
              style: GoogleFonts.gowunDodum(
                color: AppTheme.a(AppTheme.tPrimary, 0.64),
                fontSize: isNarrow ? 11.8 : 12.1,
                fontWeight: FontWeight.w800,
                height: 1.5,
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
    final isNarrow = MediaQuery.of(context).size.width < 360;

    return _GlassCard(
      bg: AppTheme.panelFill,
      border: AppTheme.panelBorder,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 108),
        padding: EdgeInsets.fromLTRB(
          isNarrow ? 16 : 18,
          18,
          isNarrow ? 16 : 18,
          18,
        ),
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '검색 결과가 없어요.',
              style: GoogleFonts.gowunDodum(
                color: AppTheme.a(AppTheme.tPrimary, 0.78),
                fontSize: isNarrow ? 13.0 : 13.6,
                fontWeight: FontWeight.w900,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '다른 키워드로 다시 검색해보세요.',
              style: GoogleFonts.gowunDodum(
                color: AppTheme.a(AppTheme.tPrimary, 0.64),
                fontSize: isNarrow ? 11.8 : 12.1,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color tone;

  const _Badge({
    required this.text,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.a(tone, 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.a(tone, 0.32), width: 1),
      ),
      child: Text(
        text,
        style: GoogleFonts.gowunDodum(
          color: AppTheme.a(AppTheme.tPrimary, 0.92),
          fontSize: 11.6,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}

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

class _LabeledText2Lines extends StatelessWidget {
  final String badge;
  final Color badgeTone;
  final String text;
  final Color textTone;
  final int maxLines;

  const _LabeledText2Lines({
    required this.badge,
    required this.badgeTone,
    required this.text,
    required this.textTone,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 360;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Badge(text: badge, tone: badgeTone),
        const SizedBox(height: 6),
        Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.gowunDodum(
            color: textTone,
            fontSize: isNarrow ? 12.2 : 12.6,
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

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
    final isNarrow = MediaQuery.of(context).size.width < 360;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Badge(text: badge, tone: badgeTone),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.gowunDodum(
            color: textTone,
            fontSize: isNarrow ? 11.8 : 12.2,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _TinyGhostChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color border;
  final VoidCallback? onTap;

  const _TinyGhostChip({
    required this.icon,
    required this.label,
    required this.bg,
    required this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 360;

    final content = Container(
      height: isNarrow ? 27 : 28,
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 9 : 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.a(AppTheme.tPrimary, 0.74)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.gowunDodum(
              color: AppTheme.a(AppTheme.tPrimary, 0.74),
              fontSize: isNarrow ? 11.2 : 11.6,
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
        splashColor: AppTheme.inkSplash,
        highlightColor: AppTheme.inkHighlight,
        child: content,
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
          width: isNarrow ? 26 : 28,
          height: isNarrow ? 26 : 28,
          child: Center(
            child: Icon(
              icon,
              size: isNarrow ? 18 : 20,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarSwitchButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CalendarSwitchButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tPrimary = AppTheme.tPrimary;
    final isNarrow = MediaQuery.of(context).size.width < 360;

    return Tooltip(
      message: '캘린더로 보기',
      waitDuration: const Duration(milliseconds: 400),
      showDuration: const Duration(seconds: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: AppTheme.inkSplash,
          highlightColor: AppTheme.inkHighlight,
          child: Ink(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 8 : 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: AppTheme.calendarBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.panelBorder, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: isNarrow ? 15 : 16,
                  color: AppTheme.a(tPrimary, 0.88),
                ),
                const SizedBox(width: 6),
                Text(
                  '캘린더',
                  style: GoogleFonts.gowunDodum(
                    color: AppTheme.a(tPrimary, 0.88),
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
      decoration: glassPanelDecoration(
        radius: 18,
        fill: bg,
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