// lib/arcana/list_arcana.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../ui/layout_tokens.dart';

// ✅ (이미 프로젝트에 있다면) 78장 파일명 재사용
import '../cardpicker.dart' as cp;

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
  ArcanaSort _sort = ArcanaSort.numberAsc;
  ArcanaFilter _filter = ArcanaFilter.all;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  // ================== DATA (DB 연결 X, 로컬 더미) ==================
  // 카드 파일명은 cardpicker.dart의 kTarotFileNames를 그대로 사용.
  // (없으면 cardpicker.dart에 이미 쓰고 있던 리스트가 있을 거라 그걸 가져오면 됨)
  List<_ArcanaItem> _buildItems() {
    // ✅ 0~77
    final names = cp.kTarotFileNames;
    final items = <_ArcanaItem>[];

    for (int i = 0; i < names.length; i++) {
      final path = 'asset/cards/${names[i]}';
      items.add(_ArcanaItem(
        id: i,
        title: _prettyName(names[i]),
        assetPath: path,
      ));
    }

    // ✅ Filter (UX만: “전체/메이저/마이너” 느낌만)
    final filtered = items.where((e) {
      if (_filter == ArcanaFilter.all) return true;
      if (_filter == ArcanaFilter.major) return e.id <= 21; // 0~21 메이저(관례)
      return e.id >= 22; // 22~77 마이너(관례)
    }).toList();

    // ✅ Search
    final q = _query.trim().toLowerCase();
    final searched = q.isEmpty
        ? filtered
        : filtered.where((e) {
      return e.title.toLowerCase().contains(q) ||
          e.id.toString().contains(q);
    }).toList();

    // ✅ Sort
    searched.sort((a, b) {
      switch (_sort) {
        case ArcanaSort.numberAsc:
          return a.id.compareTo(b.id);
        case ArcanaSort.numberDesc:
          return b.id.compareTo(a.id);
        case ArcanaSort.nameAsc:
          return a.title.compareTo(b.title);
        case ArcanaSort.nameDesc:
          return b.title.compareTo(a.title);
      }
    });

    return searched;
  }

  static String _prettyName(String filename) {
    // "00-TheFool.png" -> "TheFool"
    var s = filename;
    s = s.replaceAll('.png', '');
    final dash = s.indexOf('-');
    if (dash >= 0 && dash + 1 < s.length) s = s.substring(dash + 1);
    // 가독성: CamelCase 사이에 공백 넣기(대충)
    s = s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return s;
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final items = _buildItems();

    final tsTitle = GoogleFonts.gowunDodum(
      fontSize: 16.5,
      fontWeight: FontWeight.w900,
      color: AppTheme.headerInk,
      letterSpacing: -0.2,
    );

    return Scaffold(
      backgroundColor: AppTheme.bgSolid,
      body: SafeArea(
        child: Column(
          children: [
            // =========================================
            // ✅ TOP: 뒤로가기 + 타이틀 (list_diary 느낌)
            // =========================================
            TopBox(
              left: Transform.translate(
                offset: const Offset(LayoutTokens.backBtnNudgeX, 0),
                child: _TightIconButton(
                  icon: Icons.arrow_back_rounded,
                  color: AppTheme.headerInk,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              title: Text('타로카드 도감', style: tsTitle),
              right: const SizedBox(width: 40),
            ),

            // =========================================
            // ✅ CENTER: 상단 컨트롤 + 리스트 (UX 차용)
            // =========================================
            Expanded(
              child: CenterBox(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      // ✅ list_diary에서 "월 이동(왼쪽) + 검색/정렬(오른쪽)" 같은 줄 느낌
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            // 왼쪽: 필터(전체/메이저/마이너) — 월 이동 자리 대체
                            _FilterPill(
                              value: _filter,
                              onChanged: (v) => setState(() => _filter = v),
                            ),
                            const Spacer(),
                            // 오른쪽: 검색(작게)
                            _SquareIcon(
                              icon: Icons.search_rounded,
                              onTap: () async {
                                // UX: 검색창 포커스
                                FocusScope.of(context).requestFocus();
                              },
                            ),
                            const SizedBox(width: 8),
                            // 오른쪽: 정렬(작게)
                            _SortPill(
                              value: _sort,
                              onChanged: (v) => setState(() => _sort = v),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ✅ 검색 입력줄(상단 고정)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _GlassLine(
                          child: TextField(
                            controller: _searchC,
                            onChanged: (v) => setState(() => _query = v),
                            style: GoogleFonts.gowunDodum(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.tPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: '카드 이름/번호로 검색',
                              hintStyle: GoogleFonts.gowunDodum(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _a(AppTheme.tSecondary, 0.85),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                              const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: _a(AppTheme.tSecondary, 0.9),
                                ),
                                onPressed: () {
                                  _searchC.clear();
                                  setState(() => _query = '');
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ✅ 리스트
                      Expanded(
                        child: items.isEmpty
                            ? _EmptyState(
                          text: '검색 결과가 없어요.',
                          sub: '다른 키워드로 찾아보자.',
                        )
                            : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final it = items[i];
                            return _ArcanaListTile(
                              item: it,
                              onTap: () {
                                // ✅ DB 연결 전: 행동만(추후 상세/기록 페이지로 연결 예정)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '(${it.id}) ${it.title} - 추후 상세/기록 연결 예정',
                                      style: GoogleFonts.gowunDodum(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    duration:
                                    const Duration(milliseconds: 900),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ✅ list_diary처럼 “하단 바텀 고정 버튼”은 지금은 없음(요청대로)
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

enum ArcanaSort { numberAsc, numberDesc, nameAsc, nameDesc }
enum ArcanaFilter { all, major, minor }

// =========================================================
// ✅ UI bits (list_diary 느낌: 글라스 카드/작은 버튼들)
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
                // 썸네일 (작게, list_diary의 카드 썸네일 영역 느낌)
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

                // 텍스트
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
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: _a(AppTheme.tSecondary, 0.65)),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

class _SquareIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SquareIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _a(AppTheme.panelFill, 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _a(AppTheme.gold, 0.16), width: 1),
          ),
          child: Icon(icon, size: 18, color: _a(AppTheme.tPrimary, 0.92)),
        ),
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  final ArcanaSort value;
  final ValueChanged<ArcanaSort> onChanged;
  const _SortPill({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _a(AppTheme.panelFill, 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _a(AppTheme.gold, 0.16), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ArcanaSort>(
          value: value,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          dropdownColor: _a(AppTheme.panelFill, 0.95),
          iconEnabledColor: _a(AppTheme.tSecondary, 0.9),
          style: GoogleFonts.gowunDodum(
            fontSize: 12.6,
            fontWeight: FontWeight.w900,
            color: _a(AppTheme.tPrimary, 0.92),
          ),
          items: const [
            DropdownMenuItem(
              value: ArcanaSort.numberAsc,
              child: Text('번호↑'),
            ),
            DropdownMenuItem(
              value: ArcanaSort.numberDesc,
              child: Text('번호↓'),
            ),
            DropdownMenuItem(
              value: ArcanaSort.nameAsc,
              child: Text('이름↑'),
            ),
            DropdownMenuItem(
              value: ArcanaSort.nameDesc,
              child: Text('이름↓'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final ArcanaFilter value;
  final ValueChanged<ArcanaFilter> onChanged;
  const _FilterPill({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _a(AppTheme.panelFill, 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _a(AppTheme.gold, 0.16), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ArcanaFilter>(
          value: value,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          dropdownColor: _a(AppTheme.panelFill, 0.95),
          iconEnabledColor: _a(AppTheme.tSecondary, 0.9),
          style: GoogleFonts.gowunDodum(
            fontSize: 12.6,
            fontWeight: FontWeight.w900,
            color: _a(AppTheme.tPrimary, 0.92),
          ),
          items: const [
            DropdownMenuItem(
              value: ArcanaFilter.all,
              child: Text('전체'),
            ),
            DropdownMenuItem(
              value: ArcanaFilter.major,
              child: Text('메이저'),
            ),
            DropdownMenuItem(
              value: ArcanaFilter.minor,
              child: Text('마이너'),
            ),
          ],
        ),
      ),
    );
  }
}
