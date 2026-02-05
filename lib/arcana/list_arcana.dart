// lib/arcana/list_arcana.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../ui/layout_tokens.dart';

// ✅ (이미 프로젝트에 있다면) 78장 파일명 재사용
import '../cardpicker.dart' as cp;

// ✅ 공용 정렬
import '../list_sorting.dart';

// ✅ withOpacity 대체(프로젝트 공용 패턴)
Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class ListArcanaPage extends StatefulWidget {
  const ListArcanaPage({super.key});

  @override
  State<ListArcanaPage> createState() => _ListArcanaPageState();
}

class _ListArcanaPageState extends State<ListArcanaPage> {
  // ================== STATE ==================
  final TextEditingController _searchC = TextEditingController();

  String _query = '';
  ListSort _sort = ListSort.numberAsc;
  ArcanaFilter _filter = ArcanaFilter.all;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  // ================== DATA (DB 연결 X, 로컬 더미) ==================
  List<_ArcanaItem> _buildItems() {
    final names = cp.kTarotFileNames;
    final items = <_ArcanaItem>[];

    for (int i = 0; i < names.length; i++) {
      final filename = names[i];
      final path = 'asset/cards/$filename';

      // ✅ "00-TheFool.png" 앞의 2자리 숫자를 id로 사용 (순서 바뀌어도 안전)
      final parsedId = int.tryParse(filename.substring(0, 2));
      final id = parsedId ?? i;

      items.add(_ArcanaItem(
        id: id,
        title: _prettyName(filename),
        assetPath: path,
      ));
    }

    // ✅ Filter (칩 기준)
    final filtered = items.where((e) {
      switch (_filter) {
        case ArcanaFilter.all:
          return true;
        case ArcanaFilter.major:
          return e.id <= 21;
        case ArcanaFilter.minor:
          return e.id >= 22;

      // 마이너 수트(관례): 22~35 Wands, 36~49 Cups, 50~63 Swords, 64~77 Pentacles
        case ArcanaFilter.wands:
          return e.id >= 22 && e.id <= 35;
        case ArcanaFilter.cups:
          return e.id >= 36 && e.id <= 49;
        case ArcanaFilter.swords:
          return e.id >= 50 && e.id <= 63;
        case ArcanaFilter.pentacles:
          return e.id >= 64 && e.id <= 77;
      }
    }).toList();

    // ✅ Search
    final q = _query.trim().toLowerCase();
    final searched = q.isEmpty
        ? filtered
        : filtered.where((e) {
      return e.title.toLowerCase().contains(q) || e.id.toString().contains(q);
    }).toList();

    // ✅ Sort (공용)
    searched.sort(
          (a, b) => compareListSort(
        _sort,
        idA: a.id,
        idB: b.id,
        titleA: a.title,
        titleB: b.title,
      ),
    );

    return searched;
  }

  static String _prettyName(String filename) {
    var s = filename;
    s = s.replaceAll('.png', '');
    final dash = s.indexOf('-');
    if (dash >= 0 && dash + 1 < s.length) s = s.substring(dash + 1);
    s = s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return s;
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final items = _buildItems();

    return Scaffold(
      backgroundColor: AppTheme.bgSolid,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // ✅ TOP 고정
            Padding(
              padding: EdgeInsets.only(top: LayoutTokens.scrollTopPad),
              child: TopBox(
                left: Transform.translate(
                  offset: const Offset(LayoutTokens.backBtnNudgeX, 0),
                  child: _TightIconButton(
                    icon: Icons.arrow_back_rounded,
                    color: AppTheme.headerInk,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                title: Text('타로카드 도감', style: AppTheme.title),
                right: const SizedBox.shrink(), // ✅ 비움
              ),
            ),

            const SizedBox(height: 14),

            // ✅ 검색 + 칩 고정 (CenterBox 안에 그대로)
            CenterBox(
              child: Column(
                children: [
                  // ✅ 검색 + 정렬 한 줄
                  // ✅ 검색 + 칩을 하나의 박스로 묶기
                  _GlassLine(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        children: [
                          // 1) 검색 + 정렬 한 줄 (박스 안)
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      size: 20, // ✅ 살짝 키움 (18 → 20)
                                      color: _a(AppTheme.gold, 0.90), // ✅ 칩/정렬과 동일한 골드 톤
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: _a(Colors.black, 0.06),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: _a(AppTheme.gold, 0.16),
                                            width: 1,
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _searchC,
                                          onChanged: (v) => setState(() => _query = v),
                                          style: GoogleFonts.gowunDodum(
                                            fontSize: 13.2,
                                            fontWeight: FontWeight.w800,
                                            color: _a(AppTheme.tPrimary, 0.95),
                                            height: 1.2,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: '카드이름/번호',
                                            hintStyle: GoogleFonts.gowunDodum(
                                              fontSize: 12.6,
                                              fontWeight: FontWeight.w700,
                                              color: _a(AppTheme.tSecondary, 0.85),
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                          ),
                                        ),
                                      ),
                                    ),

                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              _SortPill(
                                value: _sort,
                                onChanged: (v) => setState(() => _sort = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 4,
                            endIndent: 4,
                            color: _a(AppTheme.gold, 0.18),
                          ),

                          const SizedBox(height: 8),

                          // 2) 칩 라인 (박스 안)
                          SizedBox(
                            height: 36, // ✅ 칩 줄 높이 고정(깔끔)
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _FilterChipPill(
                                    label: '전체',
                                    selected: _filter == ArcanaFilter.all,
                                    onTap: () => setState(() => _filter = ArcanaFilter.all),
                                  ),
                                  _FilterChipPill(
                                    label: '메이저',
                                    selected: _filter == ArcanaFilter.major,
                                    onTap: () => setState(() => _filter = ArcanaFilter.major),
                                  ),
                                  _FilterChipPill(
                                    label: '마이너',
                                    selected: _filter == ArcanaFilter.minor,
                                    onTap: () => setState(() => _filter = ArcanaFilter.minor),
                                  ),
                                  _FilterChipPill(
                                    label: '완즈',
                                    selected: _filter == ArcanaFilter.wands,
                                    onTap: () => setState(() => _filter = ArcanaFilter.wands),
                                  ),
                                  _FilterChipPill(
                                    label: '컵',
                                    selected: _filter == ArcanaFilter.cups,
                                    onTap: () => setState(() => _filter = ArcanaFilter.cups),
                                  ),
                                  _FilterChipPill(
                                    label: '소드',
                                    selected: _filter == ArcanaFilter.swords,
                                    onTap: () => setState(() => _filter = ArcanaFilter.swords),
                                  ),
                                  _FilterChipPill(
                                    label: '펜타클',
                                    selected: _filter == ArcanaFilter.pentacles,
                                    onTap: () => setState(() => _filter = ArcanaFilter.pentacles),
                                  ),
                                ].expand((w) => [w, const SizedBox(width: 6)]).toList()
                                  ..removeLast(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),



                  const SizedBox(height: 10),


                ],
              ),
            ),

            const SizedBox(height: 10),

            // ✅ 리스트만 스크롤
            Expanded(
              child: (items.isEmpty)
                  ? const Center(
                child: _EmptyState(
                  text: '검색 결과가 없어요.',
                  sub: '다른 키워드로 찾아보자.',
                ),
              )
                  : ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  24.0, // ← CenterBox 좌우 여백과 동일한 값
                  0,
                  24.0,
                  LayoutTokens.scrollBottomBase +
                      MediaQuery.of(context).viewInsets.bottom,
                ),

                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final it = items[i];
                  return _ArcanaListTile(
                    item: it,
                    onTap: () {},
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

  }
}

// =========================================================
// ✅ Models / Enums
// =========================================================
class _ArcanaItem {
  final int id;
  final String title;
  final String assetPath;

  const _ArcanaItem({
    required this.id,
    required this.title,
    required this.assetPath,
  });
}

// ✅ 필터 확장 (칩용)
enum ArcanaFilter { all, major, minor, wands, cups, swords, pentacles }

// =========================================================
// ✅ UI bits
// =========================================================
class _GlassLine extends StatelessWidget {
  final Widget child;
  const _GlassLine({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: _a(AppTheme.panelFill, 0.50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _a(AppTheme.gold, 0.18), width: 1),
        ),
        child: child,
      ),
    );
  }
}

class _FilterChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? _a(AppTheme.gold, 0.12)         // ✅ 선택: 살짝 골드 배경
        : _a(AppTheme.panelFill, 0.18);   // ✅ 비선택: 패널 톤

    final bd = selected
        ? _a(AppTheme.gold, 0.40)         // ✅ 선택: 골드 보더
        : _a(AppTheme.gold, 0.14);        // ✅ 비선택: 아주 약한 골드 보더

    final fg = selected
        ? _a(AppTheme.gold, 0.92)         // ✅ 선택: 골드 글씨
        : _a(AppTheme.tSecondary, 0.88);  // ✅ 비선택: 서브톤 글씨 (중요!)

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: bd, width: 1),
          ),
          child: Text(
            label,
            style: GoogleFonts.gowunDodum(
              fontSize: 12.8,
              fontWeight: FontWeight.w900,
              color: fg,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcanaListTile extends StatelessWidget {
  final _ArcanaItem item;
  final VoidCallback onTap;

  const _ArcanaListTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const r = 18.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        child: Ink(
          decoration: BoxDecoration(
            color: _a(AppTheme.panelFill, 0.58),
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: _a(AppTheme.gold, 0.18), width: 1),
            boxShadow: [
              BoxShadow(
                color: _a(Colors.black, 0.12),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 46,
                    height: 60,
                    color: _a(Colors.black, 0.10),
                    child: Image.asset(
                      item.assetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.style_rounded,
                        color: _a(AppTheme.tSecondary, 0.85),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${item.id.toString().padLeft(2, '0')}  ${item.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.gowunDodum(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.tPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '기록/설명(추후) · 태그/메모(추후)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.gowunDodum(
                          fontSize: 12.3,
                          fontWeight: FontWeight.w700,
                          color: _a(AppTheme.tSecondary, 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 20, color: _a(AppTheme.tSecondary, 0.65)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  final String sub;
  const _EmptyState({required this.text, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 34, color: _a(AppTheme.tSecondary, 0.7)),
            const SizedBox(height: 10),
            Text(
              text,
              style: GoogleFonts.gowunDodum(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: _a(AppTheme.tPrimary, 0.92),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              sub,
              style: GoogleFonts.gowunDodum(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _a(AppTheme.tSecondary, 0.90),
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
      splashColor: AppTheme.inkSplash,
      highlightColor: AppTheme.inkHighlight,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Icon(icon, size: 24, color: color),
        ),
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  final ListSort value;
  final ValueChanged<ListSort> onChanged;
  const _SortPill({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30, // ✅ 전체 높이 다운
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _a(AppTheme.panelFill, 0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _a(AppTheme.gold, 0.45),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: Theme(
          data: Theme.of(context).copyWith(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          ),
          child: DropdownButton<ListSort>(
            value: value,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },

            isDense: true,
            iconSize: 18, // ✅ 아이콘만 살짝 줄이기
            borderRadius: BorderRadius.circular(12),
            dropdownColor: _a(AppTheme.panelFill, 0.95),
            iconEnabledColor: _a(AppTheme.gold, 0.85),

            selectedItemBuilder: (context) {
              return ListSort.values.map((s) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _shortSortLabel(s),
                    style: GoogleFonts.gowunDodum(
                      fontSize: 12.4,
                      fontWeight: FontWeight.w900,
                      color: _a(AppTheme.gold, 0.92),
                      height: 1.0,
                    ),
                  ),
                );
              }).toList();
            },

            style: GoogleFonts.gowunDodum(
              fontSize: 12.4,
              fontWeight: FontWeight.w900,
              color: _a(AppTheme.gold, 0.92),
              height: 1.0,
            ),

            items: ListSort.values.map(
                  (s) => DropdownMenuItem<ListSort>(
                value: s,
                child: Text(listSortLabel(s)),
              ),
            ).toList(),
          ),
        ),
      ),

    );
  }
}



String _shortSortLabel(ListSort s) {
  switch (s) {
    case ListSort.numberAsc:
      return '번호↑';
    case ListSort.numberDesc:
      return '번호↓';
    case ListSort.nameAsc:
      return '이름↑';
    case ListSort.nameDesc:
      return '이름↓';
  }
}
