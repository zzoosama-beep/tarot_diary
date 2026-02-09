// lib/arcana/write_arcana.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// UI
import '../theme/app_theme.dart';
import '../ui/layout_tokens.dart';
import '../ui/app_buttons.dart';
import '../ui/app_toast.dart';

// Card
import 'arcana_labels.dart';
import '../ui/tarot_card_preview.dart';

// Left Float Tab
import 'lefttab_arcana_sheet.dart';

// DB
import '../backend/arcana_repo.dart';

// Auth / Device / Dalnyang
import 'package:firebase_auth/firebase_auth.dart';
import '../backend/device_id_service.dart';
import '../backend/dalnyang_api.dart';
import '../error/app_error_handler.dart';

// ✅ withOpacity 대체(프로젝트 공용 패턴)
Color _a(Color c, double o) => c.withAlpha((o * 255).round());

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

  // ================== DATA (카드 메타는 항상 78장) ==================
  late final List<_ArcanaCard> _allCards = _buildAllCards();

  // 접힘, 펼치기
  bool _meaningOpen = true;
  bool _myNoteOpen = true;
  bool _saving = false;

  // ✅ 달냥이(아르카나 도감) 상태
  bool _askingArcana = false;

  bool get _canAskArcana => _selectedCard != null && !_askingArcana;

  // =========================================================
  // ✅ ArcanaLabels 기반: 카드명(ko/en) 생성 (로컬 선언 금지)
  // =========================================================
  String _arcanaKoNameById(int id) {
    final koMajor = ArcanaLabels.majorKoName(id);
    if (koMajor != null) return koMajor;

    final fn = ArcanaLabels.kTarotFileNames[id];
    final koMinor = ArcanaLabels.minorKoFromFilename(fn);
    if (koMinor != null && koMinor.isNotEmpty) return koMinor;

    return ArcanaLabels.prettyEnTitleFromFilename(fn);
  }

  String _arcanaEnNameById(int id) {
    final fn = ArcanaLabels.kTarotFileNames[id];
    return ArcanaLabels.prettyEnTitleFromFilename(fn);
  }

  /// ✅ 광고 보기 전 사전 체크(남은 보상 횟수)
  Future<void> _precheckRewardBeforeAd() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw DalnyangKnownException('로그인이 필요해!');

    final idToken = (await user.getIdToken(true)) ?? '';
    if (idToken.isEmpty) {
      throw DalnyangKnownException('로그인 토큰을 가져오지 못했어. 다시 로그인해줘!');
    }

    final deviceId = await DeviceIdService.getOrCreate();
    final status = await DalnyangApi.getRewardStatus(
      idToken: idToken,
      deviceId: deviceId,
    );

    if (status.remaining <= 0) {
      throw DalnyangKnownException(
        '오늘 받을 수 있는 보상은 하루 ${status.limit}회까지야 🐾\n'
            '오늘은 모두 사용했어. 내일 다시 시도해줘!',
      );
    }
  }

  /// ✅ 아르카나 도감용 달냥이 호출 → 기본 의미에 자동 붙이기
  Future<void> _askArcanaFromDallyang() async {
    if (_askingArcana) return;

    final selected = _selectedCard;
    if (selected == null) {
      _toast('카드를 먼저 선택해줘!');
      return;
    }

    setState(() => _askingArcana = true);
    _toast('달냥이가 정리 중…');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw DalnyangKnownException('로그인이 필요해!');

      final idToken = (await user.getIdToken(true)) ?? '';
      if (idToken.isEmpty) {
        throw DalnyangKnownException('로그인 토큰을 가져오지 못했어. 다시 로그인해줘!');
      }

      final deviceId = await DeviceIdService.getOrCreate();

      // ✅ 카드명(ko/en) - ArcanaLabels에서만 생성
      final cardId = selected.id;
      final cardKo = _arcanaKoNameById(cardId);
      final cardEn = _arcanaEnNameById(cardId);

      final answer = await DalnyangApi.ask(
        idToken: idToken,
        deviceId: deviceId,
        question: '이 카드의 의미를 도감용으로 정리해줘.',
        context: {
          'source': 'arcana',
          'card_ko': cardKo,
          'card_en': cardEn,
        },
      );

      if (!mounted) return;

      // ✅ 기본 의미에 자동으로 붙이기
      final add = '\n\n---\n${answer.trim()}\n';
      setState(() {
        _meaningC.text = (_meaningC.text.trimRight()) + add;
        _meaningC.selection = TextSelection.collapsed(offset: _meaningC.text.length);
      });

      _toast('기본 의미에 달냥이 답을 붙였어!');
    } catch (e) {
      await handleDalnyangError(context, e);
    } finally {
      if (mounted) setState(() => _askingArcana = false);
    }
  }

  @override
  void dispose() {
    _meaningC.dispose();
    _myNoteC.dispose();
    _tagsC.dispose();
    super.dispose();
  }

  // =========================================================
  // ✅ 카드 메타 생성 (title은 영문 유지, 한글은 ArcanaLabels로 표시)
  // =========================================================
  List<_ArcanaCard> _buildAllCards() {
    final names = ArcanaLabels.kTarotFileNames;

    final cards = <_ArcanaCard>[];
    for (int i = 0; i < names.length; i++) {
      final file = names[i];

      // ✅ cardId는 리스트 index(0~77)로 통일 (파일 앞 2자리도 결국 0~77)
      final id = i;

      final path = 'asset/cards/$file';
      final isMajor = id <= 21;
      final suit = isMajor ? MinorSuit.unknown : _guessSuitFromFilename(file);

      cards.add(_ArcanaCard(
        id: id,
        assetPath: path,
        title: ArcanaLabels.prettyEnTitleFromFilename(file), // ✅ 영문 제목
        isMajor: isMajor,
        suit: suit,
      ));
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
    try {
      return _allCards.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  bool get _canSave {
    if (_selectedId == null) return false;
    return _meaningC.text.trim().isNotEmpty ||
        _myNoteC.text.trim().isNotEmpty ||
        _tagsC.text.trim().isNotEmpty;
  }

  // =========================================================
  // ✅ TOAST (공용)
  // =========================================================
  void _toast(String msg, {double bottom = 110}) {
    if (!mounted) return;
    AppToast.show(context, msg, bottom: bottom);
  }

  // =========================================================
  // ✅ 카드 선택 시: 기존 저장 데이터 있으면 자동 로드
  // =========================================================
  Future<void> _loadExistingNoteIfAny(int cardId) async {
    try {
      final repo = ArcanaRepo.I as dynamic;
      final data = await repo.read(cardId: cardId);

      if (!mounted) return;

      if (data == null) {
        _meaningC.text = '';
        _myNoteC.text = '';
        _tagsC.text = '';
        setState(() {});
        return;
      }

      _meaningC.text = (data['meaning'] ?? '').toString();
      _myNoteC.text = (data['myNote'] ?? '').toString();
      _tagsC.text = (data['tags'] ?? '').toString();
      setState(() {});
    } catch (_) {
      // read()가 없거나 실패해도 앱은 정상 동작 (저장만 가능)
    }
  }

  // =========================================================
  // ✅ 저장
  // =========================================================
  void _trySave() async {
    if (_saving) return;

    final selected = _selectedCard;
    if (selected == null) {
      _toast('카드를 먼저 선택해줘!');
      return;
    }

    final id = selected.id; // ✅ 0~77 통일

    if (!_canSave) {
      _toast('내용을 한 줄이라도 적어줘!');
      return;
    }

    setState(() => _saving = true);
    try {
      await ArcanaRepo.I.save(
        cardId: id,
        title: selected.title,
        meaning: _meaningC.text.trim(),
        myNote: _myNoteC.text.trim(),
        tags: _tagsC.text.trim(),
      );

      await ArcanaRepo.I.debugDump();

      final saved = await ArcanaRepo.I.read(cardId: id);
      if (saved == null) {
        _toast('⚠️ 저장 직후 read=null (cardId=$id)  DB 저장이 안 됨');
      } else {
        _toast('✅ 저장 확인됨 (cardId=$id)');
      }

      _toast('저장 완료!');

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    } catch (e) {
      _toast('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // =========================================================
  // ✅ 카드 선택 Sheet
  // =========================================================
  Future<void> _openPicker() async {
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

      final card = _allCards.firstWhere((c) => c.id == pickedId);
      if (card.isMajor) {
        _group = ArcanaGroup.major;
      } else {
        _group = ArcanaGroup.minor;
        _suit = card.suit == MinorSuit.unknown ? _suit : card.suit;
      }
    });

    final selected = _selectedCard;
    if (selected != null) {
      await _loadExistingNoteIfAny(selected.id);
    }
  }

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final selected = _selectedCard;

    return Scaffold(
      backgroundColor: AppTheme.bgSolid,

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FabSlot(
            child: HomeFloatingButton(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false),
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
                        trailing: DallyangAskPill(
                          enabled: _canAskArcana,
                          confirmMessage: '광고 1회 시청 후, 선택한 카드의 도감용 의미를 달냥이가 정리해줄게!',
                          precheckBeforeAd: _precheckRewardBeforeAd,
                          onReward: () async {
                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) throw DalnyangKnownException('로그인이 필요해!');

                              final idToken = (await user.getIdToken(true)) ?? '';
                              if (idToken.isEmpty) {
                                throw DalnyangKnownException('로그인 토큰을 가져오지 못했어. 다시 로그인해줘!');
                              }

                              final deviceId = await DeviceIdService.getOrCreate();
                              final adEventId = '$deviceId-${DateTime.now().millisecondsSinceEpoch}';

                              await DalnyangApi.creditRewardedAd(
                                idToken: idToken,
                                deviceId: deviceId,
                                adEventId: adEventId,
                              );

                              await _askArcanaFromDallyang();
                            } catch (e) {
                              await handleDalnyangError(context, e);
                            }
                          },
                          onDisabledTap: () {
                            if (_selectedCard == null) _toast('카드를 먼저 선택해줘!');
                            if (_askingArcana) _toast('달냥이가 정리 중이야…');
                          },
                          onNotReady: () => _toast('광고 준비 중이야. 잠깐만 다시 눌러줘!'),
                        ),
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
      ),
    );
  }
}

// =========================================================
// Widgets
// =========================================================

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
  final String title; // 영문 타이틀
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
  final _ArcanaCard? selected;
  final VoidCallback onTap;

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

    String subtitle() {
      if (!has) return '카드 선택 버튼을 눌러서 카드를 선택해줘';

      if (selected!.isMajor) {
        final ko = ArcanaLabels.majorKoName(selected!.id) ?? '';
        return '$ko - 메이저 아르카나';
      }

      final fn = ArcanaLabels.kTarotFileNames[selected!.id];
      final koMinor = ArcanaLabels.minorKoFromFilename(fn) ?? '마이너 아르카나';
      return koMinor;
    }

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
                                color: has ? _a(AppTheme.gold, 0.95) : _a(AppTheme.tSecondary, 0.85),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle(),
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

  // ✅ 우측 trailing (달냥이에게 물어보기 등)
  final Widget? trailing;

  const _FieldBox({
    required this.title,
    required this.hint,
    required this.controller,
    required this.isOpen,
    required this.onToggle,
    required this.onChanged,
    this.trailing,
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
                // ✅ 헤더: 토글 영역과 trailing 클릭 영역 분리
                Row(
                  children: [
                    InkWell(
                      onTap: onToggle,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Container(
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
                      ),
                    ),
                    const Spacer(),
                    if (trailing != null) trailing!,
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onToggle,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 22,
                          color: _a(AppTheme.tSecondary, 0.75),
                        ),
                      ),
                    ),
                  ],
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
