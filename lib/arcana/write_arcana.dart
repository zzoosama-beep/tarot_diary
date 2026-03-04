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
  final int? cardId;

  const WriteArcanaPage({
    super.key,
    this.cardId,
  });

  @override
  State<WriteArcanaPage> createState() => _WriteArcanaPageState();
}

class _WriteArcanaPageState extends State<WriteArcanaPage> {
  // =========================================================
  // ✅ write_diary_one 톤 컬러셋 (이 파일 전용)
  // =========================================================
  Color get _bg => AppTheme.bgColor;
  Color get _ink => _a(AppTheme.homeInkWarm, 0.94);
  Color get _inkDim => _a(AppTheme.homeInkWarm, 0.70);

  // 플랫 패널 (글라스/그라데이션 제거)
  Color get _panel => _a(Colors.black, 0.08);
  Color get _panelStrong => _a(Colors.black, 0.11);

  Color get _border => _a(AppTheme.headerInk, 0.14);
  Color get _borderSoft => _a(AppTheme.headerInk, 0.10);

  // 입력 필드
  Color get _field => _a(Colors.black, 0.10);
  Color get _fieldBorder => _a(AppTheme.headerInk, 0.12);

  // 그림자: 한 겹만, 약하게 (list_arcana 톤)
  List<BoxShadow> get _shadowSoft => [
    BoxShadow(
      color: _a(Colors.black, 0.10),
      blurRadius: 10,
      offset: const Offset(0, 6),
      spreadRadius: -6,
    ),
  ];

  // =========================================================
  // ✅ Typography
  // =========================================================
  late final TextStyle _tsTitle = AppTheme.title.copyWith(
    fontSize: 16.5,
    fontWeight: FontWeight.w900,
    color: _a(AppTheme.homeInkWarm, 0.96),
    letterSpacing: -0.2,
  );

  TextStyle get _tsCardTitle => GoogleFonts.gowunDodum(
    fontSize: 16.4,
    fontWeight: FontWeight.w900,
    color: _ink,
    letterSpacing: -0.2,
  );

  TextStyle get _tsSub => GoogleFonts.gowunDodum(
    fontSize: 12.6,
    fontWeight: FontWeight.w700,
    color: _a(AppTheme.homeInkWarm, 0.82),
    height: 1.2,
  );

  // =========================================================
  // STATE
  // =========================================================
  ArcanaGroup _group = ArcanaGroup.major;
  MinorSuit _suit = MinorSuit.wands;

  int? _selectedId;

  final TextEditingController _meaningC = TextEditingController();
  final TextEditingController _myNoteC = TextEditingController();
  final TextEditingController _tagsC = TextEditingController();

  // DATA (카드 메타는 항상 78장)
  late final List<_ArcanaCard> _allCards = _buildAllCards();

  // 접힘, 펼치기
  bool _meaningOpen = true;
  bool _myNoteOpen = true;
  bool _saving = false;

  // ✅ 달냥이(아르카나 도감) 상태
  bool _askingArcana = false;

  bool get _canAskArcana => _selectedCard != null && !_askingArcana;

  // =========================================================
  // ✅ 상세에서 좌/우 스와이프로 카드 넘기기 (78장이어도 OK)
  // - 핵심: PageView로 78장 전체를 "순차 탐색"시키지 않고
  //         상세에서 옆 카드만 편하게 넘기는 용도(보조 이동)로 사용
  // - 구현: 단일 에디터 + 드래그 제스처로 id만 변경 (컨트롤러 공유 문제 방지)
  // - 안전: 카드 바꿀 때마다 현재 입력을 draft cache에 저장
  // =========================================================
  final Map<int, _ArcanaDraft> _draftById = {};
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();

    if (widget.cardId == null) {
      // ✅ 홈에서 그냥 들어온 케이스: 카드 선택 유도
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPickDialogOrRoute();
      });
    } else {
      // ✅ 특정 카드 편집 케이스 (상세 진입 → 좌우 스와이프 가능)
      final id = widget.cardId!;
      _selectedId = id; // ✅ 먼저 선택 상태
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _applyDraftOrLoad(id);
        if (mounted) setState(() {});
      });
    }
  }

  void _openPickDialogOrRoute() {
    Navigator.of(context).pushReplacementNamed('/list_arcana');
  }

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

      _stashDraft(); // ✅ 스와이프 대비: 즉시 draft 반영
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
      final id = i; // ✅ 0~77 통일
      final path = 'asset/cards/$file';
      final isMajor = id <= 21;
      final suit = isMajor ? MinorSuit.unknown : _guessSuitFromFilename(file);

      cards.add(_ArcanaCard(
        id: id,
        assetPath: path,
        title: ArcanaLabels.prettyEnTitleFromFilename(file),
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
  // ✅ draft cache (스와이프/이동 시 입력 보존)
  // =========================================================
  void _stashDraft() {
    final id = _selectedId;
    if (id == null) return;
    _draftById[id] = _ArcanaDraft(
      meaning: _meaningC.text,
      myNote: _myNoteC.text,
      tags: _tagsC.text,
    );
  }

  void _applyDraft(int id, _ArcanaDraft d) {
    _meaningC.text = d.meaning;
    _myNoteC.text = d.myNote;
    _tagsC.text = d.tags;
  }

  Future<void> _applyDraftOrLoad(int id) async {
    // 1) draft 있으면 draft 우선
    final draft = _draftById[id];
    if (draft != null) {
      _applyDraft(id, draft);
      return;
    }

    // 2) 없으면 DB load
    await _loadExistingNoteIfAny(id);

    // 3) 그리고 현재 상태를 draft로 한번 저장(뒤로 갔다 다시 와도 빠르게)
    _stashDraft();
  }

  Future<void> _goToCard(int nextId, {bool fromSwipe = false}) async {
    if (nextId < 0 || nextId >= _allCards.length) return;

    // ✅ 드래그 중 중복 호출 방지
    if (_isDragging && !fromSwipe) return;

    // ✅ 현재 입력을 먼저 보존
    _stashDraft();

    setState(() => _selectedId = nextId);

    // ✅ 그룹/수트 동기화 (피커 표시용)
    final card = _allCards.firstWhere((c) => c.id == nextId);
    if (card.isMajor) {
      _group = ArcanaGroup.major;
    } else {
      _group = ArcanaGroup.minor;
      _suit = card.suit == MinorSuit.unknown ? _suit : card.suit;
    }

    await _applyDraftOrLoad(nextId);
    if (mounted) setState(() {});
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
        return;
      }

      _meaningC.text = (data['meaning'] ?? '').toString();
      _myNoteC.text = (data['myNote'] ?? '').toString();
      _tagsC.text = (data['tags'] ?? '').toString();
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

    final id = selected.id;

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

      // ✅ 저장 성공 시 draft도 최신화
      _stashDraft();

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

    await _goToCard(pickedId);
  }

  // =========================================================
  // ✅ Swipe handler (상세에서 좌우로)
  // =========================================================
  void _onHorizontalDragEnd(DragEndDetails d) {
    final id = _selectedId;
    if (id == null) return;

    final vx = d.primaryVelocity ?? 0.0;
    // vx > 0 : 오른쪽으로 스와이프(이전 카드)
    // vx < 0 : 왼쪽으로 스와이프(다음 카드)
    const threshold = 520.0;

    if (vx.abs() < threshold) return;

    setState(() => _isDragging = true);

    if (vx > 0) {
      _goToCard(id - 1, fromSwipe: true).whenComplete(() {
        if (mounted) setState(() => _isDragging = false);
      });
    } else {
      _goToCard(id + 1, fromSwipe: true).whenComplete(() {
        if (mounted) setState(() => _isDragging = false);
      });
    }
  }

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final selected = _selectedCard;
    final idxText = selected == null ? '' : '${selected.id + 1} / ${_allCards.length}';

    return Scaffold(
      backgroundColor: _bg,
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
                  color: _a(AppTheme.homeInkWarm, 0.95),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('78장 아르카나 기록', style: _tsTitle),
                  if (idxText.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      idxText,
                      style: GoogleFonts.gowunDodum(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w800,
                        color: _a(AppTheme.homeInkWarm, 0.66),
                        height: 1.0,
                      ),
                    ),
                  ],
                ],
              ),
              right: const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: CenterBox(
                // ✅ 상세 영역에서 좌/우 스와이프 (단일 에디터 유지)
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 28),
                    child: Column(
                      children: [
                        // ✅ 카드 선택 + 요약 + (좌우 버튼)
                        _PickAndSummaryBox(
                          selected: selected,
                          onTap: _openPicker,
                          onPrev: (selected == null || selected.id <= 0)
                              ? null
                              : () => _goToCard(selected.id - 1),
                          onNext: (selected == null || selected.id >= _allCards.length - 1)
                              ? null
                              : () => _goToCard(selected.id + 1),
                          tagsC: _tagsC,
                          onTagsChanged: (_) {
                            setState(() {});
                            _stashDraft();
                          },
                          panel: _panelStrong,
                          panelWeak: _panel,
                          border: _border,
                          borderSoft: _borderSoft,
                          shadow: _shadowSoft,
                          ink: _ink,
                          inkDim: _inkDim,
                          field: _field,
                          fieldBorder: _fieldBorder,
                        ),
                        const SizedBox(height: 12),

                        _FieldBox(
                          title: '기본 의미',
                          hint: '이 카드가 상징하는 기본 의미를 짧게 적어봐요.',
                          controller: _meaningC,
                          isOpen: _meaningOpen,
                          onToggle: () => setState(() => _meaningOpen = !_meaningOpen),
                          onChanged: (_) {
                            setState(() {});
                            _stashDraft();
                          },
                          trailing: DallyangAskPill(
                            enabled: _canAskArcana,
                            confirmMessage: '광고 1회 시청 후, 선택한 카드의 도감용 의미를 달냥이가 정리해줄게!',
                            precheckBeforeAd: _precheckRewardBeforeAd,
                            onReward: () async {
                              try {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) {
                                  throw DalnyangKnownException('로그인이 필요해!');
                                }

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
                          // ✅ 톤 적용
                          panel: _panel,
                          border: _border,
                          shadow: _shadowSoft,
                          ink: _ink,
                          inkDim: _inkDim,
                          chipFill: _a(Colors.black, 0.10),
                          chipBorder: _border,
                          chipText: _a(AppTheme.homeInkWarm, 0.90),
                          fieldFill: _field,
                          fieldBorder: _fieldBorder,
                        ),

                        const SizedBox(height: 12),

                        _FieldBox(
                          title: '나의 해석 / 경험',
                          hint: '내 기준으로 이 카드가 어떤 의미였는지 기록해요.',
                          controller: _myNoteC,
                          isOpen: _myNoteOpen,
                          onToggle: () => setState(() => _myNoteOpen = !_myNoteOpen),
                          onChanged: (_) {
                            setState(() {});
                            _stashDraft();
                          },
                          // ✅ 톤 적용
                          panel: _panel,
                          border: _border,
                          shadow: _shadowSoft,
                          ink: _ink,
                          inkDim: _inkDim,
                          chipFill: _a(Colors.black, 0.10),
                          chipBorder: _border,
                          chipText: _a(AppTheme.homeInkWarm, 0.90),
                          fieldFill: _field,
                          fieldBorder: _fieldBorder,
                        ),
                      ],
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

class _ArcanaDraft {
  final String meaning;
  final String myNote;
  final String tags;

  const _ArcanaDraft({
    required this.meaning,
    required this.myNote,
    required this.tags,
  });
}

class _PickAndSummaryBox extends StatelessWidget {
  final _ArcanaCard? selected;
  final VoidCallback onTap;

  // ✅ 좌/우 이동 버튼(상세에서 보조 이동)
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  final TextEditingController tagsC;
  final ValueChanged<String> onTagsChanged;

  // ✅ 톤 주입
  final Color panel;
  final Color panelWeak;
  final Color border;
  final Color borderSoft;
  final List<BoxShadow> shadow;
  final Color ink;
  final Color inkDim;
  final Color field;
  final Color fieldBorder;

  const _PickAndSummaryBox({
    required this.selected,
    required this.onTap,
    required this.onPrev,
    required this.onNext,
    required this.tagsC,
    required this.onTagsChanged,
    required this.panel,
    required this.panelWeak,
    required this.border,
    required this.borderSoft,
    required this.shadow,
    required this.ink,
    required this.inkDim,
    required this.field,
    required this.fieldBorder,
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

    final titleColor = has ? ink : inkDim;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: shadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: has ? panel : panelWeak,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: has ? border : borderSoft, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ✅ 좌/우 버튼 (카드가 있을 때만 의미 있음)
                      if (has) ...[
                        _NavMiniBtn(
                          icon: Icons.chevron_left_rounded,
                          enabled: onPrev != null,
                          onTap: onPrev,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              has ? selected!.title : '카드 미선택',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.gowunDodum(
                                fontSize: 16.8,
                                fontWeight: FontWeight.w900,
                                color: titleColor,
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
                                color: _a(AppTheme.homeInkWarm, 0.78),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _a(Colors.black, has ? 0.10 : 0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _a(AppTheme.headerInk, has ? 0.18 : 0.14),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                has ? Icons.autorenew_rounded : Icons.add_rounded,
                                size: 16,
                                color: _a(AppTheme.homeInkWarm, has ? 0.90 : 0.76),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                has ? '카드 변경' : '카드 선택',
                                style: GoogleFonts.gowunDodum(
                                  fontSize: 12.4,
                                  fontWeight: FontWeight.w900,
                                  color: _a(AppTheme.homeInkWarm, has ? 0.92 : 0.80),
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (has) ...[
                        const SizedBox(width: 10),
                        _NavMiniBtn(
                          icon: Icons.chevron_right_rounded,
                          enabled: onNext != null,
                          onTap: onNext,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: _a(AppTheme.headerInk, 0.10),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: _SelectedSummaryInner(
                    card: selected,
                    tagsC: tagsC,
                    onTagsChanged: onTagsChanged,
                    field: field,
                    fieldBorder: fieldBorder,
                    ink: ink,
                    inkDim: inkDim,
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

class _NavMiniBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavMiniBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = enabled ? _a(AppTheme.homeInkWarm, 0.88) : _a(AppTheme.homeInkWarm, 0.35);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _a(Colors.black, enabled ? 0.10 : 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _a(AppTheme.headerInk, enabled ? 0.16 : 0.10),
            width: 1,
          ),
        ),
        child: Icon(icon, size: 22, color: c),
      ),
    );
  }
}

class _SelectedSummaryInner extends StatelessWidget {
  final _ArcanaCard? card;
  final TextEditingController tagsC;
  final ValueChanged<String> onTagsChanged;

  // ✅ 톤 주입
  final Color field;
  final Color fieldBorder;
  final Color ink;
  final Color inkDim;

  const _SelectedSummaryInner({
    required this.card,
    required this.tagsC,
    required this.onTagsChanged,
    required this.field,
    required this.fieldBorder,
    required this.ink,
    required this.inkDim,
  });

  @override
  Widget build(BuildContext context) {
    if (card == null) {
      return Text(
        '선택된 카드가 없어요.',
        style: GoogleFonts.gowunDodum(
          fontSize: 12.6,
          fontWeight: FontWeight.w800,
          color: _a(AppTheme.homeInkWarm, 0.82),
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
                color: _a(AppTheme.homeInkWarm, 0.92),
                height: 1.25,
              ),
              decoration: InputDecoration(
                hintText: '키워드 입력\n(예: #시작, #도전, #자유)',
                hintStyle: GoogleFonts.gowunDodum(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                  color: _a(AppTheme.homeInkWarm, 0.62),
                  height: 1.2,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
                filled: true,
                fillColor: field,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: fieldBorder, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: fieldBorder, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _a(AppTheme.headerInk, 0.20), width: 1),
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

  // ✅ 톤 주입
  final Color panel;
  final Color border;
  final List<BoxShadow> shadow;
  final Color ink;
  final Color inkDim;

  final Color chipFill;
  final Color chipBorder;
  final Color chipText;

  final Color fieldFill;
  final Color fieldBorder;

  const _FieldBox({
    required this.title,
    required this.hint,
    required this.controller,
    required this.isOpen,
    required this.onToggle,
    required this.onChanged,
    this.trailing,
    required this.panel,
    required this.border,
    required this.shadow,
    required this.ink,
    required this.inkDim,
    required this.chipFill,
    required this.chipBorder,
    required this.chipText,
    required this.fieldFill,
    required this.fieldBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더: 토글 영역과 trailing 클릭 영역 분리
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
                            color: chipFill,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: chipBorder, width: 1),
                          ),
                          child: Text(
                            title,
                            style: GoogleFonts.gowunDodum(
                              fontSize: 12.8,
                              fontWeight: FontWeight.w900,
                              color: chipText,
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
                          color: _a(AppTheme.homeInkWarm, 0.66),
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
                      color: _a(AppTheme.homeInkWarm, 0.92),
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: GoogleFonts.gowunDodum(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w600,
                        color: _a(AppTheme.homeInkWarm, 0.62),
                        height: 1.35,
                      ),
                      filled: true,
                      fillColor: fieldFill,
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: fieldBorder, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: fieldBorder, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _a(AppTheme.headerInk, 0.20), width: 1),
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