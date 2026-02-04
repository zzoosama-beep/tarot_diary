import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

import '../ui/tarot_card_preview.dart';

// ✅ withOpacity 대체(프로젝트 공용 패턴)
Color _a(Color c, double o) => c.withAlpha((o * 255).round());

enum ArcanaGroup { major, minor }
enum MinorSuit { wands, cups, swords, pentacles, unknown }

class ArcanaCardItem {
  final int id;
  final String title;
  final String assetPath;
  final bool isMajor;
  final MinorSuit suit;

  const ArcanaCardItem({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.isMajor,
    required this.suit,
  });
}

/// ✅ 왼쪽에서 슬라이드로 나오는 카드 선택 시트
class LeftTabArcanaSheet {
  static Future<int?> open(
      BuildContext context, {
        required ArcanaGroup initialGroup,
        required MinorSuit initialSuit,
        required int? initialSelectedId,
        required List<ArcanaCardItem> allCards,
        required String Function(MinorSuit) suitLabel,
        required String Function(ArcanaGroup) groupLabel,
        required List<ArcanaCardItem> Function({required ArcanaGroup group, required MinorSuit suit}) filter,
        String title = '카드 선택',
      }) async {
    return showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'arcana-picker',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return _ArcanaPickerDialog(
          title: title,
          initialGroup: initialGroup,
          initialSuit: initialSuit,
          initialSelectedId: initialSelectedId,
          allCards: allCards,
          suitLabel: suitLabel,
          groupLabel: groupLabel,
          filter: filter,
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: const SizedBox.expand(),
              ),
            ),
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1.0, 0),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            ),
          ],
        );
      },
    );
  }
}

class _ArcanaPickerDialog extends StatefulWidget {
  final String title;

  final ArcanaGroup initialGroup;
  final MinorSuit initialSuit;
  final int? initialSelectedId;

  final List<ArcanaCardItem> allCards;
  final String Function(MinorSuit) suitLabel;
  final String Function(ArcanaGroup) groupLabel;
  final List<ArcanaCardItem> Function({required ArcanaGroup group, required MinorSuit suit}) filter;

  const _ArcanaPickerDialog({
    required this.title,
    required this.initialGroup,
    required this.initialSuit,
    required this.initialSelectedId,
    required this.allCards,
    required this.suitLabel,
    required this.groupLabel,
    required this.filter,
  });

  @override
  State<_ArcanaPickerDialog> createState() => _ArcanaPickerDialogState();
}

class _ArcanaPickerDialogState extends State<_ArcanaPickerDialog> {
  late ArcanaGroup _group = widget.initialGroup;
  late MinorSuit _suit = widget.initialSuit;

  final _q = TextEditingController();
  final _sc = ScrollController();

  @override
  void dispose() {
    _q.dispose();
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final sheetW = (w * 0.76).clamp(280.0, 360.0);

    final base = widget.filter(group: _group, suit: _suit);
    final query = _q.text.trim().toLowerCase();
    final cards = query.isEmpty
        ? base
        : base.where((c) => c.title.toLowerCase().contains(query)).toList();

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 바깥 탭 닫기
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox.expand(),
            ),
          ),

          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: sheetW,
              height: h,
              child: SafeArea(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _a(AppTheme.panelFill, 0.92),
                      border: Border(
                        right: BorderSide(color: _a(AppTheme.gold, 0.18), width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.30),
                          blurRadius: 26,
                          offset: const Offset(10, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 헤더
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: GoogleFonts.gowunDodum(
                                    fontSize: 15.2,
                                    fontWeight: FontWeight.w900,
                                    color: _a(AppTheme.tPrimary, 0.94),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: _a(AppTheme.tPrimary, 0.94),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 필터(메이저/마이너 + 슈트)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: _PillDropdown<ArcanaGroup>(
                                  value: _group,
                                  items: ArcanaGroup.values,
                                  labelOf: widget.groupLabel,
                                  onChanged: (v) => setState(() => _group = v),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _group == ArcanaGroup.minor
                                    ? _PillDropdown<MinorSuit>(
                                  value: _suit,
                                  items: const [
                                    MinorSuit.wands,
                                    MinorSuit.cups,
                                    MinorSuit.swords,
                                    MinorSuit.pentacles,
                                    MinorSuit.unknown,
                                  ],
                                  labelOf: widget.suitLabel,
                                  onChanged: (v) => setState(() => _suit = v),
                                )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),

                        // 검색
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                          child: _SearchBox(
                            controller: _q,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),

                        // 리스트
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                            decoration: BoxDecoration(
                              color: _a(AppTheme.panelFill, 0.28),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _a(AppTheme.gold, 0.14), width: 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: RawScrollbar(
                                controller: _sc,
                                thumbVisibility: true,
                                thickness: 3,
                                radius: const Radius.circular(999),
                                mainAxisMargin: 10,
                                crossAxisMargin: 6,
                                child: ListView.separated(
                                  controller: _sc,
                                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                                  itemCount: cards.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final c = cards[i];
                                    final selected = widget.initialSelectedId == c.id;
                                    return _CardRow(
                                      card: c,
                                      selected: selected,
                                      onTap: () => Navigator.of(context).pop(c.id), // ✅ 선택 즉시 닫힘 유지
                                      onPreview: () => TarotCardPreview.open(
                                        context,
                                        assetPath: c.assetPath,
                                        heroTag: 'arcana_pick_${c.id}', // ✅ heroTag는 고유하면 됨(선택)
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBox({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.gowunDodum(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: _a(AppTheme.tPrimary, 0.94),
      ),
      decoration: InputDecoration(
        hintText: '검색 (예: Fool, Magician...)',
        hintStyle: GoogleFonts.gowunDodum(
          fontSize: 12.8,
          fontWeight: FontWeight.w700,
          color: _a(AppTheme.tSecondary, 0.70),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: _a(AppTheme.panelFill, 0.36),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _a(AppTheme.gold, 0.14), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _a(AppTheme.gold, 0.14), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _a(AppTheme.gold, 0.22), width: 1),
        ),
        prefixIcon: Icon(Icons.search_rounded, color: _a(AppTheme.tSecondary, 0.75), size: 18),
      ),
    );
  }
}

class _PillDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const _PillDropdown({
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _a(AppTheme.panelFill, 0.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _a(AppTheme.gold, 0.16), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          dropdownColor: _a(AppTheme.panelFill, 0.96),
          iconEnabledColor: _a(AppTheme.tSecondary, 0.9),
          style: GoogleFonts.gowunDodum(
            fontSize: 12.8,
            fontWeight: FontWeight.w900,
            color: _a(AppTheme.tPrimary, 0.92),
          ),
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
              value: e,
              child: Text(labelOf(e)),
            ),
          )
              .toList(),
        ),
      ),
    );
  }
}

const Map<int, String> kMajorKo = {
  0: '바보',
  1: '마법사',
  2: '고위 여사제',
  3: '여황제',
  4: '황제',
  5: '교황',
  6: '연인',
  7: '전차',
  8: '힘',
  9: '은둔자',
  10: '운명의 수레바퀴',
  11: '정의',
  12: '매달린 사람',
  13: '죽음',
  14: '절제',
  15: '악마',
  16: '탑',
  17: '별',
  18: '달',
  19: '태양',
  20: '심판',
  21: '세계',
};

int _minorRankOf(ArcanaCardItem c) {
  // Rider-Waite 일반 순서 가정:
  // Wands: 22~35, Cups: 36~49, Swords: 50~63, Pentacles: 64~77
  switch (c.suit) {
    case MinorSuit.wands:
      return (c.id - 21).clamp(1, 14);
    case MinorSuit.cups:
      return (c.id - 35).clamp(1, 14);
    case MinorSuit.swords:
      return (c.id - 49).clamp(1, 14);
    case MinorSuit.pentacles:
      return (c.id - 63).clamp(1, 14);
    case MinorSuit.unknown:
    // 파일명에서 슈트 인식이 안 된 경우 fallback
      return ((c.id - 22) % 14 + 1).clamp(1, 14);
  }
}

String _displayNoText(ArcanaCardItem c) {
  if (c.isMajor) return c.id.toString();
  return _minorRankOf(c).toString();
}

String _courtNameOf(int rank) {
  switch (rank) {
    case 11:
      return '페이지';
    case 12:
      return '나이트';
    case 13:
      return '퀸';
    case 14:
      return '킹';
    default:
      return rank.toString();
  }
}

String _minorDisplayTitle(ArcanaCardItem c) {
  final rank = _minorRankOf(c);

  final suitName = switch (c.suit) {
    MinorSuit.wands => '완즈',
    MinorSuit.cups => '컵',
    MinorSuit.swords => '소드',
    MinorSuit.pentacles => '펜타클',
    MinorSuit.unknown => '마이너',
  };

  if (rank <= 10) {
    return '$suitName $rank';
  }

  return '$suitName ${_courtNameOf(rank)}';
}

String _displayTitle(ArcanaCardItem c) {
  if (c.isMajor) {
    return '${c.id}. ${c.title}';
  }

  final rank = _minorRankOf(c);
  return '$rank. ${_minorDisplayTitle(c)}';
}

class _CardRow extends StatelessWidget {
  final ArcanaCardItem card;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onPreview;

  const _CardRow({
    required this.card,
    required this.selected,
    required this.onTap,
    required this.onPreview,
  });


  @override
  Widget build(BuildContext context) {
    final border = selected ? _a(AppTheme.gold, 0.42) : _a(AppTheme.gold, 0.14);
    final bg = selected ? _a(AppTheme.panelFill, 0.58) : _a(AppTheme.panelFill, 0.36);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onPreview, // ✅ 길게 누르면 크게 보기
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 34,
                  height: 44,
                  color: _a(Colors.black, 0.12),
                  child: Image.asset(
                    card.assetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.style_rounded,
                      size: 18,
                      color: _a(AppTheme.tSecondary, 0.85),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: card.isMajor
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${card.id}. ${card.title}', // 영문 (기존 그대로)
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.gowunDodum(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: _a(AppTheme.tPrimary, 0.94),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      kMajorKo[card.id] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.gowunDodum(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                        color: _a(AppTheme.tSecondary, 0.86),
                        letterSpacing: -0.1,
                        height: 1.0,
                      ),
                    ),
                  ],
                )
                    : Text(
                  _displayTitle(card), // ✅ 마이너는 네가 만든 표시 규칙(1~14/페이지/나이트/퀸/킹)
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.gowunDodum(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: _a(AppTheme.tPrimary, 0.94),
                    letterSpacing: -0.2,
                  ),
                ),
              ),



              Icon(
                selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                size: 18,
                color: selected ? _a(AppTheme.gold, 0.88) : _a(AppTheme.tSecondary, 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
