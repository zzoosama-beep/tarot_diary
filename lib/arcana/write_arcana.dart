// lib/arcana/write_arcana.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../ui/layout_tokens.dart';
import '../ui/app_buttons.dart';
// ✅ 공통 toast
import '../ui/app_toast.dart';

import '../cardpicker.dart' as cp;

import '../ui/tarot_card_preview.dart';
import 'lefttab_arcana_sheet.dart';

// ✅ withOpacity 대체(프로젝트 공용 패턴)
Color _a(Color c, double o) => c.withAlpha((o * 255).round());

// ✅ 라벤더 톤(색조)은 유지하고, "명도"만 살짝 내려서 어둡게
Color _darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  final l = (hsl.lightness - amount).clamp(0.0, 1.0);
  return hsl.withLightness(l).toColor();
}

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
  ArcanaGroup _group = ArcanaGroup.major;
  MinorSuit _suit = MinorSuit.wands;

  int? _selectedId;

  final TextEditingController _meaningC = TextEditingController();
  final TextEditingController _myNoteC = TextEditingController();
  final TextEditingController _tagsC = TextEditingController();

  // ================== DATA (DB X, 로컬) ==================
  late final List<_ArcanaCard> _allCards = _buildAllCards();

  // 접힘, 펼치기
  bool _meaningOpen = true;
  bool _myNoteOpen = true;
  bool _saving = false;

  @override
  void dispose() {
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
    if (f.contains('pentacles') ||
        f.contains('pentacle') ||
        f.contains('coins') ||
        f.contains('coin')) {
      return MinorSuit.pentacles;
    }
    return MinorSuit.unknown;
  }

  String _prettyName(
      String filename,
      int id, {
        required bool isMajor,
        required MinorSuit? suit,
      }) {
    var s = filename.replaceAll('.png', '');

    // 번호-이름 패턴이면 번호 제거
    final dash = s.indexOf('-');
    if (dash >= 0 && dash + 1 < s.length) s = s.substring(dash + 1);

    // CamelCase 공백
    s = s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');

    // 마이너에서 파일명이 애매할 경우 임시 라벨
    if (!isMajor) {
      final ss = _suitLabel(suit ?? MinorSuit.unknown);
      final minorIndex = (id - 22).clamp(0, 999);
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
        return '전체';
    }
  }

  String _groupLabel(ArcanaGroup g) => g == ArcanaGroup.major ? '메이저' : '마이너';

  List<_ArcanaCard> _filteredCards({
    required ArcanaGroup group,
    required MinorSuit suit,
  }) {
    final list = _allCards.where((c) {
      if (group == ArcanaGroup.major) return c.isMajor;

      // minor
      if (!c.isMajor) {
        if (suit == MinorSuit.unknown) return true;
        return c.suit == suit || c.suit == MinorSuit.unknown;
      }
      return false;
    }).toList();

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
    final hasAny = _meaningC.text.trim().isNotEmpty ||
        _myNoteC.text.trim().isNotEmpty ||
        _tagsC.text.trim().isNotEmpty;
    return hasAny;
  }

  // ================== TOAST (공용) ==================
  void _toast(String msg, {double bottom = 110}) {
    if (!mounted) return;
    AppToast.show(context, msg, bottom: bottom);
  }

  void _trySave() async {
    if (_saving) return;

    // ✅ 카드 미선택
    if (_selectedId == null) {
      _toast('카드를 먼저 선택해줘!');
      return;
    }

    // ✅ 텍스트 전부 비어있음
    if (!_canSave) {
      _toast('내용을 한 줄이라도 적어줘!');
      return;
    }

    setState(() => _saving = true);
    try {
      // TODO: 실제 저장 로직 여기에 넣기
      // 예) await ArcanaRepo.save(...)

      _toast('저장 완료!');
    } catch (e) {
      _toast('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPicker() async {
    // ✅ sheet에는 ArcanaCardItem 타입으로 넘겨주기
    final items = _allCards
        .map(
          (c) => ArcanaCardItem(
        id: c.id,
        title: c.title,
        assetPath: c.assetPath,
        isMajor: c.isMajor,
        suit: c.suit,
      ),
    )
        .toList();

    final pickedId = await LeftTabArcanaSheet.open(
      context,
      title: '카드 선택',
      initialGroup: _group,
      initialSuit: _suit,
      initialSelectedId: _selectedId,
      allCards: items,
      suitLabel: _suitLabel,
      groupLabel: _groupLabel,
      filter: ({required group, required suit}) {
        final filtered = _filteredCards(group: group, suit: suit);
        return filtered
            .map(
              (c) => ArcanaCardItem(
            id: c.id,
            title: c.title,
            assetPath: c.assetPath,
            isMajor: c.isMajor,
            suit: c.suit,
          ),
        )
            .toList();
      },
    );

    if (pickedId == null) return;

    setState(() {
      _selectedId = pickedId;

      final card = _allCards[pickedId];
      if (card.isMajor) {
        _group = ArcanaGroup.major;
      } else {
        _group = ArcanaGroup.minor;
        _suit = card.suit == MinorSuit.unknown ? _suit : card.suit;
      }
    });
  }

  // ================== BUILD ==================
  @override
  Widget build(BuildContext context) {
    final selected = _selectedCard;

    return Scaffold(
      backgroundColor: AppTheme.bgSolid,

      // ✅ 오른쪽 하단 저장 FAB
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FabSlot(
            child: HomeFloatingButton(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
              },
            ),
          ),
          const SizedBox(height: 10),
          FabSlot(
            child: SaveFloatingButton(
              onPressed: _trySave,
              enabled: (_canSave && !_saving),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,


      body: SafeArea(
        child: Stack(
          children: [
            Column(
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
                  title: Text('78장 아르카나 기록', style: _tsTitle),
                  right: const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: CenterBox(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 28),
                      child: Column(
                        children: [
                          _PickAndSummaryBox(
                            selected: selected,
                            onTap: _openPicker,
                            tagsC: _tagsC,
                            onTagsChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          _FieldBox(
                            title: '기본 의미',
                            hint: '이 카드가 상징하는 기본 의미를 짧게 적어봐요.',
                            controller: _meaningC,
                            isOpen: _meaningOpen,
                            onToggle: () => setState(() => _meaningOpen = !_meaningOpen),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          _FieldBox(
                            title: '나의 해석 / 경험',
                            hint: '내 기준으로 이 카드가 어떤 의미였는지 기록해요.',
                            controller: _myNoteC,
                            isOpen: _myNoteOpen,
                            onToggle: () => setState(() => _myNoteOpen = !_myNoteOpen),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// 아래부터는 네 기존 그대로 유지
// =========================================================

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
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 64,
              height: 86,
              color: _a(Colors.black, 0.12),
              child: Image.asset(
                card!.assetPath,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.style_rounded,
                  size: 20,
                  color: _a(AppTheme.tSecondary, 0.85),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.gowunDodum(
                    fontSize: 14.6,
                    fontWeight: FontWeight.w900,
                    color: _a(AppTheme.tPrimary, 0.95),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card!.isMajor ? '메이저 아르카나 · ${card!.id}' : '마이너 아르카나',
                  style: GoogleFonts.gowunDodum(
                    fontSize: 12.3,
                    fontWeight: FontWeight.w700,
                    color: _a(AppTheme.tSecondary, 0.92),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 18, color: _a(AppTheme.tSecondary, 0.55)),
        ],
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

class _PickAndSummaryBox extends StatelessWidget {
  static const List<String> _majorKo = [
    '바보', '마법사', '고위 여사제', '여황제', '황제', '교황',
    '연인', '전차', '힘', '은둔자', '운명의 수레바퀴', '정의',
    '매달린 사람', '죽음', '절제', '악마', '탑', '별',
    '달', '태양', '심판', '세계',
  ];

  final _ArcanaCard? selected;
  final VoidCallback onTap;

  // ✅ 정석 주입
  final TextEditingController tagsC;
  final ValueChanged<String> onTagsChanged;

  const _PickAndSummaryBox({
    required this.selected,
    required this.onTap,
    required this.tagsC,
    required this.onTagsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final has = selected != null;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _a(Colors.black, 0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: _a(AppTheme.panelFill, 0.34),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _a(AppTheme.gold, 0.16), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              has ? selected!.title : '카드 미선택',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.gowunDodum(
                                fontSize: 17.0,
                                fontWeight: FontWeight.w900,
                                color: has
                                    ? _a(AppTheme.gold, 0.95)
                                    : _a(AppTheme.tSecondary, 0.85),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              has
                                  ? (selected!.isMajor
                                  ? '${_majorKo[selected!.id]} - 메이저 아르카나'
                                  : '마이너 아르카나')
                                  : '카드 선택 버튼을 눌러서 카드를 선택해줘',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.gowunDodum(
                                fontSize: 12.6,
                                fontWeight: FontWeight.w700,
                                color: _a(AppTheme.tSecondary, 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: has ? _a(AppTheme.gold, 0.14) : _a(AppTheme.panelFill, 0.28),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: has ? _a(AppTheme.gold, 0.40) : _a(AppTheme.gold, 0.16),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                has ? Icons.autorenew_rounded : Icons.add_rounded,
                                size: 16,
                                color: has ? _a(AppTheme.gold, 0.95) : _a(AppTheme.tSecondary, 0.78),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                has ? '카드 변경' : '카드 선택',
                                style: GoogleFonts.gowunDodum(
                                  fontSize: 12.4,
                                  fontWeight: FontWeight.w900,
                                  color: has ? _a(AppTheme.gold, 0.95) : _a(AppTheme.tSecondary, 0.78),
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: _a(AppTheme.gold, 0.10),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: _SelectedSummaryInner(
                    card: selected,
                    tagsC: tagsC,
                    onTagsChanged: onTagsChanged,
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

/// ✅ 기존 _SelectedSummary를 "박스 없이 내용만"으로 만든 버전
class _SelectedSummaryInner extends StatelessWidget {
  final _ArcanaCard? card;
  final TextEditingController tagsC;
  final ValueChanged<String> onTagsChanged;

  const _SelectedSummaryInner({
    required this.card,
    required this.tagsC,
    required this.onTagsChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (card == null) {
      return Text(
        '선택된 카드가 없어요.',
        style: GoogleFonts.gowunDodum(
          fontSize: 12.6,
          fontWeight: FontWeight.w800,
          color: _a(AppTheme.tSecondary, 0.92),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              TarotCardPreview.open(
                context,
                assetPath: card!.assetPath,
                heroTag: 'arcana_${card!.id}',
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 98,
                height: 172,
                color: _a(Colors.black, 0.12),
                child: Image.asset(
                  card!.assetPath,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 170,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: tagsC,
                    onChanged: onTagsChanged,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: GoogleFonts.gowunDodum(
                      fontSize: 13.6,
                      fontWeight: FontWeight.w700,
                      color: _a(AppTheme.tPrimary, 0.95),
                      height: 1.25,
                    ),
                    decoration: InputDecoration(
                      hintText: '키워드 입력\n(예: #시작, #도전, #자유)',
                      hintStyle: GoogleFonts.gowunDodum(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: _a(AppTheme.tSecondary, 0.75),
                        height: 1.2,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
                      filled: true,
                      fillColor: _a(AppTheme.panelFill, 0.40),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _a(AppTheme.gold, 0.16), width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _a(AppTheme.gold, 0.16), width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _a(AppTheme.gold, 0.26), width: 1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldBox extends StatelessWidget {
  final String title;
  final String hint;
  final TextEditingController controller;
  final bool isOpen;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  const _FieldBox({
    required this.title,
    required this.hint,
    required this.controller,
    required this.isOpen,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: _a(AppTheme.panelFill, 0.24),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _a(AppTheme.gold, 0.16), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _a(AppTheme.gold, 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _a(AppTheme.gold, 0.26), width: 1),
                          ),
                          child: Text(
                            title,
                            style: GoogleFonts.gowunDodum(
                              fontSize: 12.8,
                              fontWeight: FontWeight.w900,
                              color: _a(AppTheme.gold, 0.92),
                              height: 1.0,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          isOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 22,
                          color: _a(AppTheme.tSecondary, 0.75),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOpen) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    onChanged: onChanged,
                    minLines: 6,
                    maxLines: null,
                    style: GoogleFonts.gowunDodum(
                      fontSize: 13.2,
                      fontWeight: FontWeight.w700,
                      color: _a(AppTheme.tPrimary, 0.92),
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: GoogleFonts.gowunDodum(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w600,
                        color: _a(AppTheme.tSecondary, 0.72),
                        height: 1.35,
                      ),
                      filled: true,
                      fillColor: _a(AppTheme.panelFill, 0.58),
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _a(AppTheme.gold, 0.18), width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _a(AppTheme.gold, 0.18), width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _a(AppTheme.gold, 0.32), width: 1),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
