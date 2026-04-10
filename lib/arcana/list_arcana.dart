import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../ui/app_buttons.dart';
import '../ui/layout_tokens.dart';
import 'arcana_labels.dart';
import '../list_sorting.dart';
import '../error/error_reporter.dart';

import '../backend/arcana_repo.dart';

// ✅ write_arcana로 "직접 push" (arguments 헷갈림 제거)
import 'write_arcana.dart';

// ✅ withOpacity 대체
Color _a(Color c, double o) => c.withAlpha((o * 255).round());

// ✅ 키워드칩 공용 색
const Color _kKeywordChipBase = Color(0xFFB46AA0);
const Color _kKeywordChipText = Color(0xFFF4D7EE);
const Color _kKeywordChipBorderBase = Color(0xFFF0B8DB);

bool _isMajorId(int id) => id >= 0 && id <= 21;

/// 앞에 붙은 "22.", "22 ", "22-" 같은 전체 카드 번호 제거
String _stripLeadingDeckNumber(String text) {
  return text.replaceFirst(RegExp(r'^\s*\d{1,2}\s*[-.:)]?\s*'), '').trim();
}

/// 메이저 prefix 제거: "0. 바보" -> "바보"
String _stripMajorPrefix(String text) {
  return text.replaceFirst(RegExp(r'^\s*\d{1,2}\.\s*'), '').trim();
}

/// 중복 공백 정리
String _normalizeSpaces(String text) {
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 이름 정렬용 한글 키
/// - major: "0. 바보" -> "바보"
/// - minor: 앞 deck number 제거
String _buildKoSortKey(String koTitle) {
  final stripped = _stripLeadingDeckNumber(_stripMajorPrefix(koTitle));
  return _normalizeSpaces(stripped);
}

/// minor 한글 제목 정리
/// 예: "완즈2" -> "완즈 2", "펜타클기사" -> "펜타클 기사"
String _formatMinorKoTitle(String text) {
  var s = _stripLeadingDeckNumber(text);
  s = _normalizeSpaces(s);

  final patterns = [
    RegExp(r'^(완즈)\s*(10|[1-9]|시종|기사|여왕|왕)$'),
    RegExp(r'^(컵)\s*(10|[1-9]|시종|기사|여왕|왕)$'),
    RegExp(r'^(소드)\s*(10|[1-9]|시종|기사|여왕|왕)$'),
    RegExp(r'^(펜타클)\s*(10|[1-9]|시종|기사|여왕|왕)$'),
  ];

  for (final reg in patterns) {
    final m = reg.firstMatch(s);
    if (m != null) {
      return '${m.group(1)} ${m.group(2)}';
    }
  }

  return s;
}

/// minor 영문 제목 정리
String _formatMinorEnTitle(String text) {
  return _normalizeSpaces(_stripLeadingDeckNumber(text));
}

/// 검색용:
/// - major는 "0" 같은 앞번호 허용
/// - minor는 deck number 제거 후 제목만 검색
String _buildSearchText({
  required int id,
  required String koTitle,
  required String enTitle,
}) {
  if (_isMajorId(id)) {
    return '${id.toString()} $koTitle $enTitle'.toLowerCase();
  }

  final ko = _stripLeadingDeckNumber(koTitle);
  final en = _stripLeadingDeckNumber(enTitle);

  return _normalizeSpaces('$ko $en').toLowerCase();
}

class ListArcanaPage extends StatefulWidget {
  const ListArcanaPage({super.key});

  @override
  State<ListArcanaPage> createState() => _ListArcanaPageState();
}

class _ListArcanaPageState extends State<ListArcanaPage> {
  final TextEditingController _searchC = TextEditingController();

  String _query = '';
  ListSort _sort = ListSort.numberAsc;
  ArcanaFilter _filter = ArcanaFilter.all;

  late Future<Map<int, Map<String, dynamic>>> _notesF;
  bool _didInitialLoad = false;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Color get _bg => AppTheme.bgColor;
  Color get _ink => _a(AppTheme.homeInkWarm, 0.94);
  Color get _inkDim => _a(AppTheme.homeInkWarm, 0.70);

  Color get _panel => _a(Colors.white, 0.045);
  Color get _panelStrong => _a(Colors.white, 0.06);
  Color get _border => _a(AppTheme.headerInk, 0.15);
  Color get _borderSoft => _a(AppTheme.headerInk, 0.10);

  Color get _field => _a(Colors.black, 0.14);
  Color get _fieldBorder => _a(AppTheme.headerInk, 0.14);

  TextStyle get _tsTitle =>
      AppTheme.title.copyWith(color: _a(AppTheme.homeInkWarm, 0.96));

  TextStyle get _tsBody => GoogleFonts.gowunDodum(
    fontSize: 12.8,
    fontWeight: FontWeight.w700,
    color: _a(AppTheme.homeInkWarm, 0.82),
    height: 1.2,
  );

  bool _hasMeaningfulNote(Map<String, dynamic>? note) {
    if (note == null) return false;

    final keyword = (note['keyword'] ?? note['keywords'] ?? note['tags'] ?? '')
        .toString()
        .trim();
    final meaning = (note['meaning'] ?? '').toString().trim();
    final myNote = (note['myNote'] ?? note['my_note'] ?? '').toString().trim();

    return keyword.isNotEmpty || meaning.isNotEmpty || myNote.isNotEmpty;
  }

  Widget _buildNotePreview(Map<String, dynamic>? note) {
    if (!_hasMeaningfulNote(note)) {
      return const SizedBox.shrink();
    }

    final keyword = (note!['keyword'] ?? note['keywords'] ?? note['tags'] ?? '')
        .toString()
        .trim();
    final meaning = (note['meaning'] ?? '').toString().trim();
    final myNote = (note['myNote'] ?? note['my_note'] ?? '').toString().trim();

    Widget labelBadge({
      required String text,
      required Color textColor,
      required Color fillColor,
      required Color borderColor,
    }) {
      return Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.gowunDodum(
            fontSize: 11.2,
            fontWeight: FontWeight.w900,
            color: textColor,
            height: 1.0,
          ),
        ),
      );
    }

    Widget rowLine({
      required String label,
      required String value,
      required Color badgeText,
      required Color badgeFill,
      required Color badgeBorder,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: labelBadge(
              text: label,
              textColor: badgeText,
              fillColor: badgeFill,
              borderColor: badgeBorder,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.gowunDodum(
                fontSize: 13.2,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFCDB8D7),
                height: 1.22,
              ),
            ),
          ),
        ],
      );
    }

    final rows = <Widget>[];

    if (keyword.isNotEmpty) {
      rows.add(
        rowLine(
          label: '키워드',
          value: keyword,
          badgeText: _kKeywordChipText,
          badgeFill: _a(_kKeywordChipBase, 0.18),
          badgeBorder: _a(_kKeywordChipBorderBase, 0.30),
        ),
      );
    }

    if (meaning.isNotEmpty) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 6));
      rows.add(
        rowLine(
          label: '기본의미',
          value: meaning,
          badgeText: _kKeywordChipText,
          badgeFill: _a(_kKeywordChipBase, 0.18),
          badgeBorder: _a(_kKeywordChipBorderBase, 0.30),
        ),
      );
    }

    if (myNote.isNotEmpty) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 6));
      rows.add(
        rowLine(
          label: '나의해석',
          value: myNote,
          badgeText: _kKeywordChipText,
          badgeFill: _a(_kKeywordChipBase, 0.18),
          badgeBorder: _a(_kKeywordChipBorderBase, 0.30),
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Future<Map<int, Map<String, dynamic>>> _loadNotes() async {
    final rows = await ArcanaRepo.I.listAll();

    final map = <int, Map<String, dynamic>>{};
    for (final r in rows) {
      final raw = r['cardId'];
      final id = (raw is int)
          ? raw
          : (raw is num)
          ? raw.toInt()
          : int.tryParse(raw.toString());

      if (id == null) {
        continue;
      }
      map[id] = r;
    }

    return map;
  }

  List<_ArcanaItem> _buildItems(Map<int, Map<String, dynamic>> notes) {
    final names = ArcanaLabels.kTarotFileNames;
    final items = <_ArcanaItem>[];

    for (int i = 0; i < names.length; i++) {
      final filename = names[i];
      final path = 'asset/cards/$filename';

      final parsed =
      (filename.length >= 2) ? int.tryParse(filename.substring(0, 2)) : null;
      final id = parsed ?? i;

      final note = notes[id];
      final titleData = _buildTitleData(id: id, filename: filename);

      items.add(
        _ArcanaItem(
          id: id,
          title: titleData.searchText,
          koTitle: titleData.koTitle,
          koSortKey: titleData.koSortKey,
          enTitle: titleData.enTitle,
          assetPath: path,
          note: note,
        ),
      );
    }

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

    final q = _query.trim().toLowerCase();

    final searched = q.isEmpty
        ? filtered
        : filtered.where((e) {
      return e.searchTarget.contains(q);
    }).toList();

    searched.sort(
          (a, b) => compareListSort(
        _sort,
        idA: a.id,
        idB: b.id,
        titleA: a.koSortKey,
        titleB: b.koSortKey,
      ),
    );

    return searched;
  }

  static _ArcanaTitleData _buildTitleData({
    required int id,
    required String filename,
  }) {
    final fallbackEn = _prettyName(filename);

    final raw = ArcanaLabels.listTitle(
      id: id,
      enTitle: fallbackEn,
      filename: filename,
    ).trim();

    String ko = '';
    String enTitle = fallbackEn;

    if (raw.contains('/')) {
      final parts = raw.split('/').map((e) => e.trim()).toList();

      if (parts.length >= 2) {
        final left = parts.first;
        final right = parts.sublist(1).join('/').trim();

        final hasKoreanLeft = RegExp(r'[가-힣]').hasMatch(left);
        final hasKoreanRight = RegExp(r'[가-힣]').hasMatch(right);

        if (hasKoreanLeft && !hasKoreanRight) {
          ko = left;
          enTitle = right.isNotEmpty ? right : fallbackEn;
        } else if (!hasKoreanLeft && hasKoreanRight) {
          ko = right;
          enTitle = left.isNotEmpty ? left : fallbackEn;
        } else {
          enTitle = left.isNotEmpty ? left : fallbackEn;
          ko = right;
        }
      }
    } else if (raw.contains('(') && raw.contains(')')) {
      final reg = RegExp(r'^(.*?)\s*\((.*?)\)\s*$');
      final m = reg.firstMatch(raw);

      if (m != null) {
        final a = (m.group(1) ?? '').trim();
        final b = (m.group(2) ?? '').trim();

        final hasKoreanA = RegExp(r'[가-힣]').hasMatch(a);
        final hasKoreanB = RegExp(r'[가-힣]').hasMatch(b);

        if (hasKoreanA && !hasKoreanB) {
          ko = a;
          enTitle = b.isNotEmpty ? b : fallbackEn;
        } else if (!hasKoreanA && hasKoreanB) {
          ko = b;
          enTitle = a.isNotEmpty ? a : fallbackEn;
        } else {
          enTitle = a.isNotEmpty ? a : fallbackEn;
          ko = b;
        }
      } else {
        if (RegExp(r'[가-힣]').hasMatch(raw)) {
          ko = raw;
        } else {
          enTitle = raw.isNotEmpty ? raw : fallbackEn;
        }
      }
    } else {
      if (RegExp(r'[가-힣]').hasMatch(raw)) {
        ko = raw;
      } else if (raw.isNotEmpty) {
        enTitle = raw;
      }
    }

    if (ko.isEmpty) {
      final majorKo = ArcanaLabels.majorKoName(id);
      if (majorKo != null && majorKo.isNotEmpty) {
        ko = majorKo;
      } else {
        final minorKo = ArcanaLabels.minorKoFromFilename(filename);
        if (minorKo != null && minorKo.isNotEmpty) {
          ko = minorKo;
        }
      }
    }

    if (ko.isEmpty) ko = enTitle;

    if (_isMajorId(id)) {
      ko = _stripMajorPrefix(ko);
      enTitle = _stripMajorPrefix(enTitle);

      ko = '${id.toString()}. $ko';
      enTitle = _normalizeSpaces(enTitle);
    } else {
      ko = _formatMinorKoTitle(ko);
      enTitle = _formatMinorEnTitle(enTitle);
    }

    final koTitle = _normalizeSpaces(ko);
    final normalizedEnTitle = _normalizeSpaces(enTitle);

    final searchText = _buildSearchText(
      id: id,
      koTitle: koTitle,
      enTitle: normalizedEnTitle,
    );

    return _ArcanaTitleData(
      koTitle: koTitle,
      koSortKey: _buildKoSortKey(koTitle),
      enTitle: normalizedEnTitle,
      searchText: searchText,
    );
  }

  static String _prettyName(String filename) {
    var s = filename.replaceAll('.png', '');
    final dash = s.indexOf('-');
    if (dash >= 0 && dash + 1 < s.length) s = s.substring(dash + 1);

    s = s.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
    );

    s = s.replaceAll(RegExp(r'\bOf\b'), 'of');
    return s;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didInitialLoad) {
      _notesF = _loadNotes();
      _didInitialLoad = true;
      return;
    }

    setState(() {
      _notesF = _loadNotes();
    });
  }

  @override
  void initState() {
    super.initState();
    _notesF = Future.value(<int, Map<String, dynamic>>{});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<int, Map<String, dynamic>>>(
      future: _notesF,
      builder: (context, snap) {
        if (snap.hasError) {
          ErrorReporter.I.record(
            source: 'ListArcanaPage.loadNotes',
            error: snap.error ?? 'unknown',
            stackTrace: snap.stackTrace,
          );

          return Scaffold(
            backgroundColor: _bg,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '데이터를 불러오는 중 문제가 발생했어요.\n잠시 후 다시 시도해주세요.',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          );
        }

        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: _bg,
            body: Center(
              child: CircularProgressIndicator(
                color: _a(AppTheme.homeInkWarm, 0.85),
              ),
            ),
          );
        }

        final notes = snap.data ?? {};
        final items = _buildItems(notes);

        return Scaffold(
          backgroundColor: _bg,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    final double sidePad = MediaQuery.of(context).size.width < 360
                        ? 12
                        : (MediaQuery.of(context).size.width < 430 ? 14 : 18);

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        sidePad,
                        LayoutTokens.scrollTopPad,
                        sidePad,
                        0,
                      ),
                      child: SizedBox(
                        height: 40,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 56,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Transform.translate(
                                  offset: const Offset(2, 0), // ← 여기 바꿔
                                  child: AppPressButton(
                                    onTap: () {
                                      final nav = Navigator.of(context);
                                      if (nav.canPop()) {
                                        nav.pop();
                                      } else {
                                        nav.pushNamedAndRemoveUntil('/', (route) => false);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    normalColor: Colors.transparent,
                                    pressedColor: _a(Colors.white, 0.12),
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Center(
                                        child: Icon(
                                          Icons.arrow_back_rounded,
                                          color: _a(AppTheme.homeInkWarm, 0.96),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Transform.translate(
                                  offset: const Offset(0, 0),
                                  child: Text(
                                    '타로카드 도감',
                                    style: _tsTitle,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 56,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Transform.translate(
                                  offset: const Offset(4, 1),
                                  child: AppHeaderHomeIconButton(
                                    onTap: () {
                                      Navigator.of(context)
                                          .pushNamedAndRemoveUntil('/', (route) => false);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                CenterBox(
                  child: Column(
                    children: [
                      _PanelBox(
                        fill: _panel,
                        border: _border,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.search_rounded,
                                          size: 20,
                                          color: _a(AppTheme.homeInkWarm, 0.82),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _field,
                                              borderRadius:
                                              BorderRadius.circular(10),
                                              border: Border.all(
                                                color: _fieldBorder,
                                                width: 1,
                                              ),
                                            ),
                                            child: TextField(
                                              controller: _searchC,
                                              onChanged: (v) =>
                                                  setState(() => _query = v),
                                              style: GoogleFonts.gowunDodum(
                                                fontSize: 13.2,
                                                fontWeight: FontWeight.w800,
                                                color: _ink,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: '카드이름/번호',
                                                hintStyle:
                                                GoogleFonts.gowunDodum(
                                                  fontSize: 12.6,
                                                  fontWeight: FontWeight.w700,
                                                  color: _inkDim,
                                                ),
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 6,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    flex: 0,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minWidth: 76,
                                        maxWidth: 88,
                                      ),
                                      child: _SortPill(
                                        value: _sort,
                                        onChanged: (v) => setState(() => _sort = v),
                                        fill: _a(Colors.black, 0.12),
                                        border: _border,
                                        textColor: _a(AppTheme.homeInkWarm, 0.92),
                                        iconColor: _a(AppTheme.homeInkWarm, 0.80),
                                        dropdownColor:
                                        _a(const Color(0xFF1E1330), 0.95),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Divider(
                                height: 1,
                                thickness: 1,
                                indent: 4,
                                endIndent: 4,
                                color: _borderSoft,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 36,
                                child: _FilterChipsScroller(
                                  iconColor: _a(AppTheme.homeInkWarm, 0.78),
                                  child: Row(
                                    children: [
                                      _FilterChipPill(
                                        label: '전체',
                                        selected: _filter == ArcanaFilter.all,
                                        onTap: () =>
                                            setState(() => _filter = ArcanaFilter.all),
                                      ),
                                      _FilterChipPill(
                                        label: '메이저',
                                        selected: _filter == ArcanaFilter.major,
                                        onTap: () => setState(
                                                () => _filter = ArcanaFilter.major),
                                      ),
                                      _FilterChipPill(
                                        label: '마이너',
                                        selected: _filter == ArcanaFilter.minor,
                                        onTap: () => setState(
                                                () => _filter = ArcanaFilter.minor),
                                      ),
                                      _FilterChipPill(
                                        label: '완즈',
                                        selected: _filter == ArcanaFilter.wands,
                                        onTap: () =>
                                            setState(() => _filter = ArcanaFilter.wands),
                                      ),
                                      _FilterChipPill(
                                        label: '컵',
                                        selected: _filter == ArcanaFilter.cups,
                                        onTap: () =>
                                            setState(() => _filter = ArcanaFilter.cups),
                                      ),
                                      _FilterChipPill(
                                        label: '소드',
                                        selected: _filter == ArcanaFilter.swords,
                                        onTap: () => setState(
                                                () => _filter = ArcanaFilter.swords),
                                      ),
                                      _FilterChipPill(
                                        label: '펜타클',
                                        selected:
                                        _filter == ArcanaFilter.pentacles,
                                        onTap: () => setState(
                                                () => _filter = ArcanaFilter.pentacles),
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
                    sub: '다른 키워드로 찾아보세요.',
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
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      return _ArcanaListTile(
                        item: items[i],
                        notePreviewBuilder: _buildNotePreview,
                        hasMeaningfulNote: _hasMeaningfulNote,
                        panel: _panelStrong,
                        panelWeak: _panel,
                        border: _border,
                        borderSoft: _borderSoft,
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

class _ArcanaTitleData {
  final String koTitle;
  final String koSortKey;
  final String enTitle;
  final String searchText;

  const _ArcanaTitleData({
    required this.koTitle,
    required this.koSortKey,
    required this.enTitle,
    required this.searchText,
  });
}

class _ArcanaItem {
  final int id;
  final String title;
  final String koTitle;
  final String koSortKey;
  final String enTitle;
  final String assetPath;
  final Map<String, dynamic>? note;

  const _ArcanaItem({
    required this.id,
    required this.title,
    required this.koTitle,
    required this.koSortKey,
    required this.enTitle,
    required this.assetPath,
    required this.note,
  });

  String get searchTarget => '$koTitle $enTitle $title'.toLowerCase();
}

enum ArcanaFilter { all, major, minor, wands, cups, swords, pentacles }

class _ArcanaListTile extends StatelessWidget {
  final _ArcanaItem item;
  final Widget Function(Map<String, dynamic>? note) notePreviewBuilder;
  final bool Function(Map<String, dynamic>? note) hasMeaningfulNote;

  final Color panel;
  final Color panelWeak;
  final Color border;
  final Color borderSoft;

  const _ArcanaListTile({
    required this.item,
    required this.notePreviewBuilder,
    required this.hasMeaningfulNote,
    required this.panel,
    required this.panelWeak,
    required this.border,
    required this.borderSoft,
  });

  @override
  Widget build(BuildContext context) {
    final hasNote = hasMeaningfulNote(item.note);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WriteArcanaPage(cardId: item.id),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: hasNote ? panel : panelWeak,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasNote ? border : borderSoft,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 46,
                    height: 60,
                    color: Colors.transparent,
                    alignment: Alignment.center,
                    child: Image.asset(
                      item.assetPath,
                      width: 46,
                      height: 60,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.style_rounded,
                        color: _a(AppTheme.homeInkWarm, 0.70),
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
                        item.koTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.gowunDodum(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE6CFE3),
                          letterSpacing: -0.18,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.enTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.gowunDodum(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFCBB6E3),
                        ),
                      ),
                      if (hasNote) ...[
                        const SizedBox(height: 8),
                        notePreviewBuilder(item.note),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    hasNote
                        ? Icons.bookmark_rounded
                        : Icons.chevron_right_rounded,
                    color: hasNote
                        ? _a(_kKeywordChipBase, 0.55)
                        : _a(AppTheme.homeInkWarm, 0.55),
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
            Icon(
              Icons.inbox_rounded,
              size: 34,
              color: _a(AppTheme.homeInkWarm, 0.62),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: GoogleFonts.gowunDodum(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: _a(AppTheme.homeInkWarm, 0.90),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              sub,
              style: GoogleFonts.gowunDodum(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _a(AppTheme.homeInkWarm, 0.72),
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

class _PanelBox extends StatelessWidget {
  final Widget child;
  final Color fill;
  final Color border;

  const _PanelBox({
    required this.child,
    required this.fill,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1),
        boxShadow: null,
      ),
      child: child,
    );
  }
}

class _SortPill extends StatelessWidget {
  final ListSort value;
  final ValueChanged<ListSort> onChanged;

  final Color fill;
  final Color border;
  final Color textColor;
  final Color iconColor;
  final Color dropdownColor;

  const _SortPill({
    required this.value,
    required this.onChanged,
    required this.fill,
    required this.border,
    required this.textColor,
    required this.iconColor,
    required this.dropdownColor,
  });

  @override
  Widget build(BuildContext context) {
    const double pillHeight = 32;
    const double menuItemHeight = 48; // ✅ 반드시 48 이상

    Widget menuText(String text, {Color? color}) {
      return Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.gowunDodum(
          fontSize: 11.6,
          fontWeight: FontWeight.w900,
          color: color ?? textColor,
          height: 1.0,
        ),
      );
    }

    return Container(
      height: pillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: Theme(
          data: Theme.of(context).copyWith(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
          child: DropdownButton<ListSort>(
            value: value,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            isDense: true,
            isExpanded: true,
            itemHeight: menuItemHeight,
            menuMaxHeight: 220,
            iconSize: 16,
            borderRadius: BorderRadius.circular(12),
            dropdownColor: dropdownColor,
            iconEnabledColor: iconColor,
            selectedItemBuilder: (context) {
              return ListSort.values.map((s) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: menuText(
                    _shortSortLabel(s),
                    color: textColor,
                  ),
                );
              }).toList();
            },
            style: GoogleFonts.gowunDodum(
              fontSize: 11.6,
              fontWeight: FontWeight.w900,
              color: textColor,
              height: 1.0,
            ),
            items: ListSort.values.map((s) {
              return DropdownMenuItem<ListSort>(
                value: s,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: menuText(
                    listSortLabel(s),
                    color: _a(Colors.white, 0.95),
                  ),
                ),
              );
            }).toList(),
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
        ? _a(const Color(0xFFFFF2E6), 0.92)
        : _a(Colors.black, 0.10);
    final border = selected
        ? _a(AppTheme.headerInk, 0.20)
        : _a(AppTheme.headerInk, 0.14);
    final text = selected
        ? _a(const Color(0xFF3A2147), 0.92)
        : _a(AppTheme.homeInkWarm, 0.84);

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
            border: Border.all(color: border, width: 1),
            boxShadow: null,
          ),
          child: Text(
            label,
            style: GoogleFonts.gowunDodum(
              fontSize: 12.6,
              fontWeight: FontWeight.w900,
              color: text,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChipsScroller extends StatefulWidget {
  final Widget child;
  final Color iconColor;

  const _FilterChipsScroller({
    required this.child,
    required this.iconColor,
  });

  @override
  State<_FilterChipsScroller> createState() => _FilterChipsScrollerState();
}

class _FilterChipsScrollerState extends State<_FilterChipsScroller> {
  final ScrollController _controller = ScrollController();

  bool _showLeftHint = false;
  bool _showRightHint = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalc());
  }

  void _handleScroll() {
    if (!_controller.hasClients) return;
    _recalc();
  }

  void _recalc() {
    if (!mounted || !_controller.hasClients) return;

    final position = _controller.position;
    final max = position.maxScrollExtent;
    final offset = _controller.offset;

    final nextLeft = offset > 4;
    final nextRight = max > 1 && offset < max - 4;

    if (nextLeft != _showLeftHint || nextRight != _showRightHint) {
      setState(() {
        _showLeftHint = nextLeft;
        _showRightHint = nextRight;
      });
    }
  }

  Future<void> _scrollLeftOnce() async {
    if (!_controller.hasClients) return;

    final double target =
    (_controller.offset - 100.0).clamp(0.0, _controller.position.maxScrollExtent);

    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _scrollRightOnce() async {
    if (!_controller.hasClients) return;

    final double target =
    (_controller.offset + 100.0).clamp(0.0, _controller.position.maxScrollExtent);

    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Widget _arrowButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFF6B5A8E),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _a(Colors.white, 0.18),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: _a(Colors.white, 0.92),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _recalc());
            return false;
          },
          child: SizeChangedLayoutNotifier(
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: EdgeInsets.only(
                  left: _showLeftHint ? 30 : 0,
                  right: _showRightHint ? 30 : 0,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),

        if (_showLeftHint)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: _arrowButton(
                icon: Icons.chevron_left_rounded,
                onTap: _scrollLeftOnce,
              ),
            ),
          ),

        if (_showRightHint)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: _arrowButton(
                icon: Icons.chevron_right_rounded,
                onTap: _scrollRightOnce,
              ),
            ),
          ),
      ],
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