// list_diary.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/app_theme.dart';
import 'ui/layout_tokens.dart';

import 'calander_diary.dart'; // 캘린더로 전환 (페이드)

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

  @override
  void initState() {
    super.initState();
    final base = widget.initialDate ?? DateTime.now();
    _focusedMonth = DateTime(base.year, base.month, 1);
  }

  String _monthLabel(DateTime m) => "${m.year}년 ${m.month}월";

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
    // TODO: 해당 월 데이터 로딩
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
    // TODO: 해당 월 데이터 로딩
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

  // ===== 더미 데이터(레이아웃 확인용) =====
  // 나중에 Firestore 월 목록으로 교체
  List<_DiaryRowModel> _mockRows() {
    final y = _focusedMonth.year;
    final m = _focusedMonth.month;

    return List.generate(12, (i) {
      final day = i + 1;
      final date = DateTime(y, m, day);

      // 더미: 예상/실제 텍스트
      final before = (i % 4 == 0)
          ? "" // 일부러 비워서 "예상 배지만" 케이스 확인
          : "예상 기록입니다. 내용이 길면 두 줄까지만 보여주고 말줄임 처리할거야. (${i + 1})";

      // 더미: 실제 텍스트는 일부만 채워서 "기록없음/잠김" 같이 확인
      final after = (i % 5 == 0)
          ? ""
          : "실제 기록입니다. 여기에도 두 줄까지만 보여주고 말줄임 처리. (${i + 1})";

      return _DiaryRowModel(
        date: date,
        cardAsset: 'asset/cards/${(i % 78).toString().padLeft(2, '0')}.png',
        beforeText: before,
        afterText: after,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _mockRows();

    return Scaffold(
      backgroundColor: AppTheme.bgSolid,
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
                      MediaQuery.of(context).viewInsets.bottom,
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
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              child: Row(
                                children: [
                                  // 왼쪽 여백(센터 정렬용)
                                  const SizedBox(width: 4),

                                  // 가운데: 월 이동
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _MiniIconButton(
                                          icon: Icons.chevron_left_rounded,
                                          onTap: _prevMonth,
                                          color: AppTheme.calInk.withOpacity(0.90),
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
                                          color: AppTheme.calInk.withOpacity(0.90),
                                          splash: AppTheme.inkSplash,
                                          highlight: AppTheme.inkHighlight,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 오른쪽: 검색/정렬 (작게)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      _TinyGhostChip(
                                        icon: Icons.search_rounded,
                                        label: '검색',
                                      ),
                                      SizedBox(width: 8),
                                      _TinyGhostChip(
                                        icon: Icons.swap_vert_rounded,
                                        label: '정렬',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // 2) 리스트 컨텐츠
                          if (rows.isEmpty)
                            const _EmptyListCard()
                          else
                            Column(
                              children: [
                                for (int i = 0; i < rows.length; i++) ...[
                                  _DiaryListRow(model: rows[i]),
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
  final String cardAsset; // 대표 카드 1장

  // ✅ 리스트에서 보여줄 텍스트(예상/실제)
  final String beforeText;
  final String afterText;

  _DiaryRowModel({
    required this.date,
    required this.cardAsset,
    required this.beforeText,
    required this.afterText,
  });
}

// ---------------- Widgets ----------------

class _DiaryListRow extends StatelessWidget {
  final _DiaryRowModel model;

  const _DiaryListRow({required this.model});

  String _dateLabel(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

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

    Widget afterBlock() {
      // 1) 실제 텍스트가 있으면 2줄
      if (afterTrim.isNotEmpty) {
        return _LabeledText2Lines(
          badge: "실제",
          badgeTone: gold.withOpacity(0.85),
          text: afterTrim,
          textTone: AppTheme.tPrimary.withOpacity(0.82),
        );
      }

      // 2) 미래(내일~)면 잠김 아이콘
      if (_isFuture(model.date)) {
        return _BadgeWithIconOnlyLine(
          badge: "실제기록",
          badgeTone: AppTheme.tMuted.withOpacity(0.80),
          icon: Icons.lock_rounded,
          iconTone: AppTheme.tMuted.withOpacity(0.85),
        );
      }

      // 3) 과거~오늘인데 실제 없음 → 기록없음
      return _AfterStateLine(
        badge: "실제기록",
        badgeTone: AppTheme.tMuted.withOpacity(0.80),
        text: "- 기록 없음",
        textTone: AppTheme.tMuted.withOpacity(0.82),
      );
    }

    return _GlassCard(
      bg: Colors.white.withOpacity(0.04),
      border: AppTheme.panelBorder,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 왼쪽: 카드 썸네일 (대표 1장)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 62,
                height: 86,
                color: Colors.white.withOpacity(0.04),
                child: Image.asset(
                  model.cardAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Center(
                      child: Icon(Icons.style_rounded,
                          color: gold.withOpacity(0.55), size: 18),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(width: 12),

            // 오른쪽: 날짜 + 예상/실제
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 날짜 라벨
                  Row(
                    children: [
                      _DatePill(text: _dateLabel(model.date)),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          color: AppTheme.tMuted.withOpacity(0.55)),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ✅ 예상: 내용 없으면 배지만
                  if (beforeTrim.isEmpty)
                    _BadgeOnlyLine(
                      badge: "예상",
                      badgeTone: AppTheme.tMuted.withOpacity(0.80),
                    )
                  else
                    _LabeledText2Lines(
                      badge: "예상",
                      badgeTone: AppTheme.tMuted.withOpacity(0.80),
                      text: beforeTrim,
                      textTone: AppTheme.tPrimary.withOpacity(0.86),
                    ),

                  const SizedBox(height: 8),

                  // ✅ 실제: 미래 잠김 / 과거-오늘 기록없음 / 있으면 2줄
                  afterBlock(),
                ],
              ),
            ),
          ],
        ),
      ),
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

  const _TinyGhostChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final gold = AppTheme.gold;

    return Container(
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
          Icon(icon, size: 15, color: AppTheme.tPrimary.withOpacity(0.70)),
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
