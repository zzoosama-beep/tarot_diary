// lib/arcana/list_arcana.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../ui/app_buttons.dart';
import '../ui/layout_tokens.dart';
import '../ui/arcana_labels.dart';
import '../list_sorting.dart';

import '../backend/arcana_repo.dart';

// ✅ withOpacity 대체
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

  late Future<Map<int, Map<String, dynamic>>> _notesF;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Widget _labelChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _a(AppTheme.gold, 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _a(AppTheme.gold, 0.35), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.gowunDodum(
          fontSize: 12,
          height: 1.0,
          color: _a(AppTheme.gold, 0.95),
          fontWeight: FontWeight.w900,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }


  Widget _buildNotePreview(Map<String, dynamic>? note) {
    if (note == null) {
      return Text(
        '아직 등록된 내용이 없어요',
        style: TextStyle(
          fontSize: 12.5,
          height: 1.25,
          color: _a(AppTheme.tMuted, 0.9),
        ),
      );
    }

    // ✅ DB 매핑
    final keyword = (note['keyword'] ?? note['keywords'] ?? note['tags'] ?? '').toString().trim();
    final meaning = (note['meaning'] ?? '').toString().trim();
    final myNote  = (note['myNote'] ?? note['my_note'] ?? '').toString().trim();

    // 전부 비었으면 “없어요”
    if (keyword.isEmpty && meaning.isEmpty && myNote.isEmpty) {
      return Text(
        '아직 등록된 내용이 없어요',
        style: TextStyle(
          fontSize: 12.5,
          height: 1.25,
          color: _a(AppTheme.tMuted, 0.9),
        ),
      );
    }

    Widget valueText(String v) {
      return Text(
        v.isEmpty ? '-' : v,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.gowunDodum(
          fontSize: 12.2,
          fontWeight: FontWeight.w700,
          color: _a(AppTheme.tPrimary, 0.92),
          height: 1.15,
        ),
      );
    }

    Widget rowLine(String label, String value) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _labelChip(label),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.gowunDodum(
                fontSize: 12.2,
                fontWeight: FontWeight.w700,
                color: _a(AppTheme.tPrimary, 0.92),
                height: 1.0,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _a(Colors.black, 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _a(AppTheme.gold, 0.14), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          rowLine('키워드', keyword),
          const SizedBox(height: 8),
          rowLine('기본 의미', meaning),
          const SizedBox(height: 8),
          rowLine('나의 해석', myNote),
        ],
      ),
    );
  }



  Future<Map<int, Map<String, dynamic>>> _loadNotes() async {
    final rows = await ArcanaRepo.I.listAll();

    // ✅ 여기 무조건 찍혀야 함
    debugPrint('[LIST_ARCANA] listAll rowCount=${rows.length}');
    for (final r in rows) {
      debugPrint('[LIST_ARCANA] row cardId=${r['cardId']} title=${r['title']}');
    }

    final map = <int, Map<String, dynamic>>{};
    for (final r in rows) {
      final raw = r['cardId'];
      final id = (raw is int)
          ? raw
          : (raw is num)
          ? raw.toInt()
          : int.tryParse(raw.toString());

      if (id == null) {
        debugPrint('[LIST_ARCANA] ⚠️ invalid cardId raw=$raw row=$r');
        continue;
      }
      map[id] = r;
    }


    debugPrint('[LIST_ARCANA] notes mapSize=${map.length}');
    debugPrint('[LIST_ARCANA] has 0? ${map.containsKey(0)} / has 6? ${map.containsKey(6)} / has 13? ${map.containsKey(13)} / has 27? ${map.containsKey(27)}');

    return map;
  }


  // ================== CARD META ==================
  List<_ArcanaItem> _buildItems(Map<int, Map<String, dynamic>> notes) {
    final names = ArcanaLabels.kTarotFileNames;
    final items = <_ArcanaItem>[];

    for (int i = 0; i < names.length; i++) {
      final filename = names[i];
      final path = 'asset/cards/$filename';

      // ✅ 파일명 "00-xxxx.png"에서 표준 id 추출
      final parsed = (filename.length >= 2) ? int.tryParse(filename.substring(0, 2)) : null;
      final id = parsed ?? i; // fallback

      final note = notes[id];


      items.add(
        _ArcanaItem(
          id: id,
          title: _prettyName(filename),
          assetPath: path,
          note: note,
        ),
      );
    }

    // Filter
    final filtered = items.where((e) {
      switch (_filter) {
        case ArcanaFilter.all:
          return true;
        case ArcanaFilter.major:
          return e.id <= 21;
        case ArcanaFilter.minor:
          return e.id >= 22;
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

    // Search
    final q = _query.trim().toLowerCase();
    final searched = q.isEmpty
        ? filtered
        : filtered.where((e) {
      return e.title.toLowerCase().contains(q) ||
          e.id.toString().contains(q);
    }).toList();

    // Sort
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
    var s = filename.replaceAll('.png', '');
    final dash = s.indexOf('-');
    if (dash >= 0 && dash + 1 < s.length) s = s.substring(dash + 1);
    s = s.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
    );
    return s;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notesF = _loadNotes();
  }


  @override
  void initState() {
    super.initState();
    _notesF = _loadNotes();
  }


  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<int, Map<String, dynamic>>>(
      future: _notesF,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            backgroundColor: AppTheme.bgSolid,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'LIST_ARCANA Future error:\n${snap.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          );
        }

        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final notes = snap.data ?? {};
        final items = _buildItems(notes);


      return Scaffold(
          backgroundColor: AppTheme.bgSolid,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: LayoutTokens.scrollTopPad),
                TopBox(
                  left: Transform.translate(
                    offset: const Offset(LayoutTokens.backBtnNudgeX, 0),
                    child: _TightIconButton(
                      icon: Icons.arrow_back_rounded,
                      color: AppTheme.headerInk,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  title: Text('타로카드 도감', style: AppTheme.title),
                  right: const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                // 검색 / 필터
                CenterBox(
                  child: Column(
                    children: [
                      _GlassLine(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(
                            children: [
                              // 🔍 검색 + 정렬
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.search_rounded,
                                          size: 20,
                                          color: _a(AppTheme.gold, 0.90),
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

                              // 🏷 필터 칩
                              SizedBox(
                                height: 36,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      AppFilterChipPill(
                                        label: '전체',
                                        selected: _filter == ArcanaFilter.all,
                                        onTap: () => setState(() => _filter = ArcanaFilter.all),
                                      ),
                                      AppFilterChipPill(
                                        label: '메이저',
                                        selected: _filter == ArcanaFilter.major,
                                        onTap: () => setState(() => _filter = ArcanaFilter.major),
                                      ),
                                      AppFilterChipPill(
                                        label: '마이너',
                                        selected: _filter == ArcanaFilter.minor,
                                        onTap: () => setState(() => _filter = ArcanaFilter.minor),
                                      ),
                                      AppFilterChipPill(
                                        label: '완즈',
                                        selected: _filter == ArcanaFilter.wands,
                                        onTap: () => setState(() => _filter = ArcanaFilter.wands),
                                      ),
                                      AppFilterChipPill(
                                        label: '컵',
                                        selected: _filter == ArcanaFilter.cups,
                                        onTap: () => setState(() => _filter = ArcanaFilter.cups),
                                      ),
                                      AppFilterChipPill(
                                        label: '소드',
                                        selected: _filter == ArcanaFilter.swords,
                                        onTap: () => setState(() => _filter = ArcanaFilter.swords),
                                      ),
                                      AppFilterChipPill(
                                        label: '펜타클',
                                        selected: _filter == ArcanaFilter.pentacles,
                                        onTap: () => setState(() => _filter = ArcanaFilter.pentacles),
                                      ),
                                    ]
                                        .expand((w) => [w, const SizedBox(width: 6)])
                                        .toList()
                                      ..removeLast(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: items.isEmpty
                      ? const _EmptyState(
                    text: '검색 결과가 없어요.',
                    sub: '다른 키워드로 찾아보자.',
                  )
                      : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      0,
                      24,
                      LayoutTokens.scrollBottomBase +
                          MediaQuery.of(context).viewInsets.bottom,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      return _ArcanaListTile(
                        item: items[i],
                        notePreviewBuilder: _buildNotePreview,
                      );
                    },

                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =========================================================
// MODELS
// =========================================================
class _ArcanaItem {
  final int id;
  final String title;
  final String assetPath;
  final Map<String, dynamic>? note;

  const _ArcanaItem({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.note,
  });
}

enum ArcanaFilter { all, major, minor, wands, cups, swords, pentacles }

// =========================================================
// TILE
// =========================================================
class _ArcanaListTile extends StatelessWidget {
  final _ArcanaItem item;
  final Widget Function(Map<String, dynamic>? note) notePreviewBuilder;

  const _ArcanaListTile({
    required this.item,
    required this.notePreviewBuilder,
  });


  @override
  Widget build(BuildContext context) {
    final hasNote = item.note != null;
    final meaning = (item.note?['meaning'] ?? '').toString();
    final myNote = (item.note?['myNote'] ?? '').toString();
    final tags = (item.note?['tags'] ?? '').toString();

    final en = item.title; // 이미 prettyName 되어있음
    final filename = item.assetPath.split('/').last; // "22-AceOfWands.png"
    final titleLine = ArcanaLabels.listTitle(
      id: item.id,
      enTitle: en,
      filename: filename,
    );


    final summary = [
      if (tags.isNotEmpty) tags,
      if (meaning.isNotEmpty) meaning,
      if (myNote.isNotEmpty) myNote,
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          // TODO: write_arcana로 이동(cardId 전달)
        },
        child: Ink(
          decoration: BoxDecoration(
            color: _a(AppTheme.panelFill, hasNote ? 0.72 : 0.50),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasNote ? _a(AppTheme.gold, 0.45) : _a(AppTheme.gold, 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: _a(Colors.black, 0.12),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    item.assetPath,
                    width: 46,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.style_rounded,
                      color: _a(AppTheme.tSecondary, 0.85),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleLine,
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
                      notePreviewBuilder(item.note),

                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  hasNote ? Icons.bookmark_rounded : Icons.chevron_right_rounded,
                  color: _a(AppTheme.gold, hasNote ? 0.9 : 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================
// ETC UI
// =========================================================
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

// ✅ (누락됐던) GlassLine
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

// ✅ (누락됐던) SortPill
class _SortPill extends StatelessWidget {
  final ListSort value;
  final ValueChanged<ListSort> onChanged;
  const _SortPill({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
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
            iconSize: 18,
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
            items: ListSort.values
                .map((s) => DropdownMenuItem<ListSort>(
              value: s,
              child: Text(listSortLabel(s)),
            ))
                .toList(),
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


