// lib/arcana/write_arcana.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../ui/layout_tokens.dart';
import '../ui/app_buttons.dart';
import '../cardpicker.dart' as cp;

// ✅ withOpacity 대체(프로젝트 공용 패턴)
Color _a(Color c, double o) => c.withAlpha((o * 255).round());

enum ArcanaGroup { major, minor }
enum MinorSuit { wands, cups, swords, pentacles, unknown }

class WriteArcanaPage extends StatefulWidget {
  const WriteArcanaPage({super.key});

  @override
  State<WriteArcanaPage> createState() => _WriteArcanaPageState();
}

class _WriteArcanaPageState extends State<WriteArcanaPage> {
  // ================== UI ==================
  late final TextStyle _tsTitle = GoogleFonts.gowunDodum(
    fontSize: 16.5,
    fontWeight: FontWeight.w900,
    color: AppTheme.headerInk,
    letterSpacing: -0.2,
  );

  // ================== STATE ==================
  bool _selectExpanded = true;

  ArcanaGroup _group = ArcanaGroup.major;
  MinorSuit _suit = MinorSuit.wands;

  int? _selectedId;

  final TextEditingController _meaningC = TextEditingController();
  final TextEditingController _myNoteC = TextEditingController();
  final TextEditingController _tagsC = TextEditingController();

  final ScrollController _cardListC = ScrollController();

  // ================== DATA (DB X, 로컬) ==================
  late final List<_ArcanaCard> _allCards = _buildAllCards();

  @override
  void dispose() {
    _cardListC.dispose(); // ✅ 추가
    _meaningC.dispose();
    _myNoteC.dispose();
    _tagsC.dispose();
    super.dispose();
  }


  List<_ArcanaCard> _buildAllCards() {
    final names = cp.kTarotFileNames;

    final cards = <_ArcanaCard>[];
    for (int i = 0; i < names.length; i++) {
      final file = names[i];
      final path = 'asset/cards/$file';

      final isMajor = i <= 21; // 관례(0~21)
      final suit = isMajor ? null : _guessSuitFromFilename(file);

      cards.add(
        _ArcanaCard(
          id: i,
          assetPath: path,
          title: _prettyName(file, i, isMajor: isMajor, suit: suit),
          isMajor: isMajor,
          suit: suit ?? MinorSuit.unknown,
        ),
      );
    }
    return cards;
  }

  MinorSuit _guessSuitFromFilename(String file) {
    final f = file.toLowerCase();
    if (f.contains('wands') || f.contains('wand')) return MinorSuit.wands;
    if (f.contains('cups') || f.contains('cup')) return MinorSuit.cups;
    if (f.contains('swords') || f.contains('sword')) return MinorSuit.swords;
    if (f.contains('pentacles') || f.contains('pentacle') || f.contains('coins') || f.contains('coin')) {
      return MinorSuit.pentacles;
    }
    return MinorSuit.unknown;
  }

  String _prettyName(String filename, int id,
      {required bool isMajor, required MinorSuit? suit}) {
    // 예: "00-TheFool.png" -> "The Fool" 비슷하게
    var s = filename.replaceAll('.png', '');

    // 번호-이름 패턴이면 번호 제거
    final dash = s.indexOf('-');
    if (dash >= 0 && dash + 1 < s.length) s = s.substring(dash + 1);

    // CamelCase 공백
    s = s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');

    // 마이너에서 파일명이 애매할 경우 "완즈 1" 같은 라벨을 임시로라도 주기
    if (!isMajor) {
      final ss = _suitLabel(suit ?? MinorSuit.unknown);
      // 파일명이 숫자를 포함하지 않으면 id 기반으로라도 표기
      final minorIndex = (id - 22).clamp(0, 999);
      // 56장을 4슈트로 대충 분배(정확 매핑은 나중에 파일명/리스트 확정 후 수정)
      final rankGuess = (minorIndex % 14) + 1;
      final hasNumber = RegExp(r'\d').hasMatch(s);
      if (!hasNumber) return '$ss $rankGuess';
    }
    return s;
  }

  String _suitLabel(MinorSuit s) {
    switch (s) {
      case MinorSuit.wands:
        return '완즈';
      case MinorSuit.cups:
        return '컵';
      case MinorSuit.swords:
        return '소드';
      case MinorSuit.pentacles:
        return '펜타클';
      case MinorSuit.unknown:
        return '마이너';
    }
  }

  List<_ArcanaCard> _filteredCards() {
    final list = _allCards.where((c) {
      if (_group == ArcanaGroup.major) return c.isMajor;
      // minor
      if (!c.isMajor) {
        if (_suit == MinorSuit.unknown) return true;
        return c.suit == _suit || c.suit == MinorSuit.unknown; // 파일명이 슈트 인식 안되면 임시로 포함
      }
      return false;
    }).toList();

    // 번호순
    list.sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  _ArcanaCard? get _selectedCard {
    final id = _selectedId;
    if (id == null) return null;
    if (id < 0 || id >= _allCards.length) return null;
    return _allCards[id];
  }

  bool get _canSave {
    if (_selectedId == null) return false;
    // 기록이 전부 비면 저장 막기(원하면 나중에 완화)
    final hasAny = _meaningC.text.trim().isNotEmpty ||
        _myNoteC.text.trim().isNotEmpty ||
        _tagsC.text.trim().isNotEmpty;
    return hasAny;
  }

  void _selectCard(int id) {
    setState(() => _selectedId = id);
    // UX: 선택하면 기록 영역으로 집중(원하면 자동 접기)
    // setState(() => _selectExpanded = false);
  }

  // ================== BUILD ==================
  @override
  Widget build(BuildContext context) {
    final selected = _selectedCard;
    final cards = _filteredCards();

    return Scaffold(
      backgroundColor: AppTheme.bgSolid,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: LayoutTokens.scrollTopPad),

            // TOP
            TopBox(
              left: Transform.translate(
                offset: const Offset(LayoutTokens.backBtnNudgeX, 0),
                child: _TightIconButton(
                  icon: Icons.arrow_back_rounded,
                  color: AppTheme.headerInk,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              title: Text('78장 아르카나 기록', style: _tsTitle),
              right: const SizedBox.shrink(),
            ),

            const SizedBox(height: 12),

            // CENTER
            Expanded(
              child: CenterBox(
                child: _GlassPanel(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      children: [
                        // 1) 카드 선택 (좌: 미니 토글 / 우: 드롭박스+리스트)
                        // 1) 카드 선택 (좌: 미니 토글 / 우: 드롭박스+리스트)
                        SizedBox(
                          height: _selectExpanded ? 320 : 70, // ✅ Row 전체 높이 확정
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch, // ✅ 이제 stretch 써도 안전
                            children: [
                              SizedBox(
                                width: 108,
                                child: _SelectLeftMini(
                                  selectedTitle: selected?.title,
                                  selectedId: selected?.id,
                                  expanded: _selectExpanded,
                                  onToggle: () =>
                                      setState(() => _selectExpanded = !_selectExpanded),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AnimatedCrossFade(
                                  firstChild: const SizedBox.shrink(),
                                  secondChild: _SelectBody(
                                    controller: _cardListC,
                                    group: _group,
                                    suit: _suit,
                                    onGroupChanged: (g) => setState(() => _group = g),
                                    onSuitChanged: (s) => setState(() => _suit = s),
                                    cards: cards,
                                    selectedId: _selectedId,
                                    onSelect: _selectCard,
                                  ),
                                  crossFadeState: _selectExpanded
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,
                                  duration: const Duration(milliseconds: 160),
                                ),
                              ),
                            ],
                          ),
                        ),



                        const SizedBox(height: 10),

                        // 2) 선택 카드 요약(항상)
                        _SelectedSummary(card: selected),

                        const SizedBox(height: 10),

                        // 3) 기록 입력(스크롤)
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Column(
                              children: [
                                _FieldBox(
                                  title: '기본 의미',
                                  hint: '이 카드가 상징하는 기본 의미를 짧게 적어봐요.',
                                  controller: _meaningC,
                                  minLines: 2,
                                  maxLines: 5,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 10),
                                _FieldBox(
                                  title: '나의 해석 / 경험',
                                  hint: '내 기준으로 이 카드가 어떤 의미였는지 기록해요.',
                                  controller: _myNoteC,
                                  minLines: 6,
                                  maxLines: 14,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 10),
                                _FieldBox(
                                  title: '키워드(선택)',
                                  hint: '#연애 #직장 #조언 처럼 적어도 좋아요.',
                                  controller: _tagsC,
                                  minLines: 1,
                                  maxLines: 2,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // BOTTOM CTA
            BottomBox(
              child: _GlassPanel(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: AppCtaButton(
                    label: '타로 기록',
                    icon: Icons.bookmark_add_rounded,
                    onPressed: _canSave
                        ? () {
                      // ✅ DB 연결은 아직 하지 않음
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '저장(예정): ${_selectedCard?.title ?? "-"}',
                            style: GoogleFonts.gowunDodum(fontWeight: FontWeight.w800),
                          ),
                          duration: const Duration(milliseconds: 900),
                        ),
                      );
                    }
                        : null,
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

// =========================================================
// UI: Select Header/Body
// =========================================================

class _SelectHeader extends StatelessWidget {
  final bool expanded;
  final String subtitle;
  final VoidCallback onToggle;

  const _SelectHeader({
    required this.expanded,
    required this.subtitle,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: _a(AppTheme.panelFill, 0.36),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _a(AppTheme.gold, 0.16), width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: _a(AppTheme.tPrimary, 0.90)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '카드 선택',
                      style: GoogleFonts.gowunDodum(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: _a(AppTheme.tPrimary, 0.94),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.gowunDodum(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                        color: _a(AppTheme.tSecondary, 0.92),
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 22,
                color: _a(AppTheme.tSecondary, 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectLeftMini extends StatelessWidget {
  final String? selectedTitle;
  final int? selectedId;
  final bool expanded;
  final VoidCallback onToggle;

  const _SelectLeftMini({
    required this.selectedTitle,
    required this.selectedId,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final has = selectedId != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _a(AppTheme.panelFill, 0.34),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _a(AppTheme.gold, 0.16), width: 1),
          ),
          child: expanded
          // =========================
          // ✅ 펼친 상태(320): 풀 UI
          // =========================
              ? Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(Icons.tune_rounded,
                  size: 18, color: _a(AppTheme.tPrimary, 0.90)),
              const SizedBox(height: 8),
              Text(
                '카드선택',                 // ✅ 줄바꿈 제거
                maxLines: 1,               // ✅ 한 줄 고정
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.gowunDodum(
                  fontSize: 12.0,          // ✅ 12.2 → 12.0 살짝 다운
                  fontWeight: FontWeight.w900,
                  color: _a(AppTheme.tPrimary, 0.92),
                  height: 1.0,             // ✅ 높이 줄여서 안전
                ),
              ),

              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _a(AppTheme.panelFill, 0.26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _a(AppTheme.gold, 0.10), width: 1),
                ),
                child: Text(
                  has ? '#${selectedId.toString().padLeft(2, '0')}' : '-',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.gowunDodum(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: has
                        ? _a(AppTheme.gold, 0.88)
                        : _a(AppTheme.tSecondary, 0.75),
                    height: 1.0,
                  ),
                ),
              ),

              const Spacer(),

              Icon(Icons.expand_less_rounded,
                  size: 22, color: _a(AppTheme.tSecondary, 0.85)),
            ],
          )

          // =========================
          // ✅ 접힌 상태(70): 컴팩트 UI (오버플로 방지)
          // =========================
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tune_rounded,
                  size: 18, color: _a(AppTheme.tPrimary, 0.90)),
              const SizedBox(height: 6),
              Text(
                has ? '#${selectedId.toString().padLeft(2, '0')}' : '-',
                textAlign: TextAlign.center,
                style: GoogleFonts.gowunDodum(
                  fontSize: 12.2,
                  fontWeight: FontWeight.w900,
                  color: has
                      ? _a(AppTheme.gold, 0.88)
                      : _a(AppTheme.tSecondary, 0.75),
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Icon(Icons.expand_more_rounded,
                  size: 22, color: _a(AppTheme.tSecondary, 0.85)),
            ],
          ),
        ),
      ),
    );
  }
}


class _SelectBody extends StatelessWidget {
  final ScrollController controller;
  final ArcanaGroup group;
  final MinorSuit suit;
  final ValueChanged<ArcanaGroup> onGroupChanged;
  final ValueChanged<MinorSuit> onSuitChanged;

  final List<_ArcanaCard> cards;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  const _SelectBody({
    required this.controller,
    required this.group,
    required this.suit,
    required this.onGroupChanged,
    required this.onSuitChanged,
    required this.cards,
    required this.selectedId,
    required this.onSelect,
  });

  String _groupLabel(ArcanaGroup g) => g == ArcanaGroup.major ? '메이저' : '마이너';

  String _suitLabel(MinorSuit s) {
    switch (s) {
      case MinorSuit.wands:
        return '완즈';
      case MinorSuit.cups:
        return '컵';
      case MinorSuit.swords:
        return '소드';
      case MinorSuit.pentacles:
        return '펜타클';
      case MinorSuit.unknown:
        return '전체';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 320, // ✅ 메이저 0~21 충분히 스크롤되는 높이
        child: Column(
          children: [
            // 드롭다운 라인
            Row(
              children: [
                Expanded(
                  child: _PillDropdown<ArcanaGroup>(
                    value: group,
                    items: ArcanaGroup.values,
                    labelOf: _groupLabel,
                    onChanged: onGroupChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: group == ArcanaGroup.minor
                      ? _PillDropdown<MinorSuit>(
                    value: suit,
                    items: const [
                      MinorSuit.wands,
                      MinorSuit.cups,
                      MinorSuit.swords,
                      MinorSuit.pentacles,
                      MinorSuit.unknown,
                    ],
                    labelOf: _suitLabel,
                    onChanged: onSuitChanged,
                  )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ✅ 리스트 영역은 Expanded로 꽉
            // ✅ 리스트 영역은 Expanded로 꽉
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _a(AppTheme.panelFill, 0.28),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _a(AppTheme.gold, 0.14), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ScrollbarTheme(
                    data: ScrollbarThemeData(
                      // ✅ “옅게” 보이도록
                      thumbColor: MaterialStateProperty.all(
                        _a(AppTheme.tSecondary, 0.35),
                      ),
                      trackColor: MaterialStateProperty.all(Colors.transparent),
                      trackBorderColor: MaterialStateProperty.all(Colors.transparent),
                    ),
                    child: RawScrollbar(
                      controller: controller,
                      thumbVisibility: true,
                      thickness: 3,
                      radius: const Radius.circular(999),

                      // ✅ 라운드 모서리 끝부분 피해서 보이게
                      mainAxisMargin: 10,
                      crossAxisMargin: 6,

                      child: ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        itemCount: cards.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final c = cards[i];
                          final selected = selectedId == c.id;
                          return _CardRow(
                            card: c,
                            selected: selected,
                            onTap: () => onSelect(c.id),
                          );
                        },
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

class _CardRow extends StatelessWidget {
  final _ArcanaCard card;
  final bool selected;
  final VoidCallback onTap;

  const _CardRow({
    required this.card,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected ? _a(AppTheme.gold, 0.42) : _a(AppTheme.gold, 0.14);
    final bg = selected ? _a(AppTheme.panelFill, 0.58) : _a(AppTheme.panelFill, 0.36);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
              Text(
                card.isMajor
                    ? card.id.toString().padLeft(2, '0')
                    : '', // 마이너는 “완즈 1” 같은 제목에 이미 정보가 들어감(지금은 비움)
                style: GoogleFonts.gowunDodum(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w900,
                  color: _a(AppTheme.tSecondary, 0.9),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  card.title,
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
              if (selected)
                Icon(Icons.check_circle_rounded, size: 18, color: _a(AppTheme.gold, 0.88))
              else
                Icon(Icons.chevron_right_rounded, size: 18, color: _a(AppTheme.tSecondary, 0.55)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedSummary extends StatelessWidget {
  final _ArcanaCard? card;
  const _SelectedSummary({required this.card});

  @override
  Widget build(BuildContext context) {
    if (card == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _a(AppTheme.panelFill, 0.30),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _a(AppTheme.gold, 0.12), width: 1),
        ),
        child: Text(
          '선택된 카드가 없어요. 위에서 카드를 골라줘.',
          style: GoogleFonts.gowunDodum(
            fontSize: 12.6,
            fontWeight: FontWeight.w800,
            color: _a(AppTheme.tSecondary, 0.92),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _a(AppTheme.panelFill, 0.34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _a(AppTheme.gold, 0.14), width: 1),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 64,
              color: _a(Colors.black, 0.12),
              child: Image.asset(
                card!.assetPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.style_rounded,
                  size: 18,
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
                  card!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.gowunDodum(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _a(AppTheme.tPrimary, 0.95),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card!.isMajor ? '메이저 아르카나 · #${card!.id.toString().padLeft(2, '0')}' : '마이너 아르카나',
                  style: GoogleFonts.gowunDodum(
                    fontSize: 12.3,
                    fontWeight: FontWeight.w700,
                    color: _a(AppTheme.tSecondary, 0.92),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  final String title;
  final String hint;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _FieldBox({
    required this.title,
    required this.hint,
    required this.controller,
    required this.minLines,
    required this.maxLines,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _a(AppTheme.panelFill, 0.30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _a(AppTheme.gold, 0.14), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.gowunDodum(
                fontSize: 12.8,
                fontWeight: FontWeight.w900,
                color: _a(AppTheme.tPrimary, 0.92),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              onChanged: onChanged,
              minLines: minLines,
              maxLines: maxLines,
              style: GoogleFonts.gowunDodum(
                fontSize: 13.2,
                fontWeight: FontWeight.w800,
                color: _a(AppTheme.tPrimary, 0.94),
                height: 1.25,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.gowunDodum(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                  color: _a(AppTheme.tSecondary, 0.86),
                  height: 1.25,
                ),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// Common widgets
// =========================================================

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    const r = 20.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: Container(
        decoration: BoxDecoration(
          color: _a(AppTheme.panelFill, 0.55),
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: _a(AppTheme.gold, 0.22), width: 1),
          boxShadow: [
            BoxShadow(
              color: _a(Colors.black, 0.18),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
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

class _ArcanaCard {
  final int id;
  final String title;
  final String assetPath;
  final bool isMajor;
  final MinorSuit suit;

  const _ArcanaCard({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.isMajor,
    required this.suit,
  });
}
