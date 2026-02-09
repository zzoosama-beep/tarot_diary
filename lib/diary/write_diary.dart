// lib/write_diary.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tarot_diary/cardpicker.dart' as cp;

import '../arcana/arcana_labels.dart';
import '../backend/diary_repo.dart';

// ✅ 레이아웃 규격 토큰 (TopBox/CenterBox/BottomBox 포함)
import '../ui/layout_tokens.dart';
// ✅ 공용 CTA 버튼 + 달냥이 버튼
import '../ui/app_buttons.dart';
// ✅ 공용 toast
import '../ui/app_toast.dart';
// ✅ 공통 테마
import '../theme/app_theme.dart';
// id체크
import '../backend/device_id_service.dart';
// 챗지피티 api
import '../backend/dalnyang_api.dart';
// ✅ 달냥이 공용 에러(롱에러/기타)
import '../error/app_error_dialog.dart';
// ✅ 공용 에러 핸들러(known/unknown 분기)
import '../error/app_error_handler.dart';

class WriteDiaryPage extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime? selectedDate;

  const WriteDiaryPage({
    super.key,
    this.initialDate,
    this.selectedDate,
  });

  @override
  State<WriteDiaryPage> createState() => _WriteDiaryPageState();
}

class _WriteDiaryPageState extends State<WriteDiaryPage> {
  // ================== UI CONST ==================
  static const double _actionBtnH = 34.0; // 자동/수동/리셋 버튼 높이
  static const double _btnRadius = 14.0;

  // ✅ withOpacity 대체: 알파 정밀도/워닝 회피용
  static Color _a(Color c, double o) => c.withAlpha((o * 255).round());

  // ✅ 스크롤 제어(달냥 답변이 생기면 자동으로 보여주기)
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _hintKey = GlobalKey();

  // ================== STATE ==================
  DateTime _selectedDate = DateTime.now();

  int _cardCount = 1;
  List<int> _pickedCards = [];
  bool _isRevealed = false;

  bool _saving = false;
  bool _loading = false;

  bool _afterUnlocked = false;

  final TextEditingController _beforeCtrl = TextEditingController();
  final TextEditingController _afterCtrl = TextEditingController();

  bool _touched = false;
  bool _hydrating = false;

  // ✅ 달냥이 힌트 상태
  bool _asking = false;
  String? _dallyangHint; // 생성/응답 저장

  // ================== HELPERS ==================
  String _cardKoName(int id) {
    final koMajor = ArcanaLabels.majorKoName(id);
    if (koMajor != null) return koMajor;

    final fn = ArcanaLabels.kTarotFileNames[id];
    return ArcanaLabels.minorKoFromFilename(fn) ??
        ArcanaLabels.prettyEnTitleFromFilename(fn);
  }

  void _markTouched() {
    if (_hydrating) return;
    if (_touched) return;
    setState(() => _touched = true);
  }

  bool _hasText(String v) =>
      v.replaceAll(RegExp(r'[\s\u200B-\u200D\uFEFF]'), '').isNotEmpty;

  String _formatKoreanDate(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';

  bool get _canUnlockAfter {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return !d.isAfter(today);
  }

  bool get _canSave {
    if (_saving) return false;
    final cardOk = _pickedCards.length == _cardCount;
    final textOk =
        _hasText(_beforeCtrl.text) || (_afterUnlocked && _hasText(_afterCtrl.text));
    return cardOk && textOk;
  }

  bool get _canAskDallyang {
    final cardOk = _isRevealed && _pickedCards.length == _cardCount;
    return cardOk && !_asking;
  }

  String _cardTitle(int id) {
    final fn = ArcanaLabels.kTarotFileNames[id];
    final en = ArcanaLabels.prettyEnTitleFromFilename(fn);

    final koMajor = ArcanaLabels.majorKoName(id);
    final koMinor = ArcanaLabels.minorKoFromFilename(fn);

    final ko = koMajor ?? koMinor;
    return ko == null ? en : '$en ($ko)';
  }

  String _cardsSummaryLine() {
    final ids = _pickedCards.take(_cardCount).toList();
    return ids.map(_cardTitle).join(', ');
  }

  /// ✅ 광고 보기 전 사전 체크(남은 보상 횟수)
  /// - 성공: 그냥 return
  /// - 실패: DalnyangKnownException throw
  Future<void> _precheckRewardBeforeAd() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw DalnyangKnownException('로그인이 필요해!');

    final idToken = (await user.getIdToken(true)) ?? '';
    if (idToken.isEmpty) {
      throw DalnyangKnownException('로그인 토큰을 가져오지 못했어. 다시 로그인해줘!');
    }

    final deviceId = await DeviceIdService.getOrCreate();

    // ✅ 문구/판단을 API 레이어로 위임
    await DalnyangApi.precheckRewardOrThrow(
      idToken: idToken,
      deviceId: deviceId,
    );
  }

  // ================== TYPO (AppTheme 기반) ==================
  TextStyle get _tsSectionTitle => AppTheme.month.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w900,
    color: _a(AppTheme.gold, 0.80),
  );

  TextStyle get _tsBody => AppTheme.body.copyWith(
    fontSize: 15,
    height: 1.45,
    color: _a(AppTheme.tPrimary, 0.85),
  );

  TextStyle get _tsHint => AppTheme.hint.copyWith(
    fontSize: 14,
    height: 1.35,
    color: _a(AppTheme.tMuted, 0.92),
    fontWeight: FontWeight.w500,
  );

  TextStyle get _tsMeta => AppTheme.uiSmallLabel.copyWith(
    fontSize: 12.5,
    fontWeight: FontWeight.w800,
    color: _a(AppTheme.tSecondary, 0.85),
  );

  // ================== TOAST (공용) ==================
  void _toast(String msg, {double bottom = 110}) {
    if (!mounted) return;
    AppToast.show(context, msg, bottom: bottom);
  }

  void _trySave() {
    if (_saving) return;

    final cardOk = _pickedCards.length == _cardCount;
    if (!cardOk) {
      _toast('카드를 $_cardCount장 선택(또는 뽑기) 완료해줘!');
      return;
    }

    final textOk =
        _hasText(_beforeCtrl.text) || (_afterUnlocked && _hasText(_afterCtrl.text));
    if (!textOk) {
      _toast('텍스트를 한 줄이라도 적어줘!');
      return;
    }

    _save();
  }

  // ✅ 달냥이 답변을 Before에 붙이기
  void _applyHintToBefore() {
    final hint = _dallyangHint;
    if (hint == null || hint.trim().isEmpty) return;

    final add = '\n\n---\n${hint.trim()}\n';
    _markTouched();

    setState(() {
      _beforeCtrl.text = (_beforeCtrl.text.trimRight()) + add;
      _beforeCtrl.selection =
          TextSelection.collapsed(offset: _beforeCtrl.text.length);
      _dallyangHint = null;
    });

    _toast('Before에 달냥이 답을 붙였어!');
  }

  void _scrollToHintBox() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _hintKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        alignment: 0.20,
      );
    });
  }

  // ================== 달냥이(광고 보상 후) ==================
  Future<void> _askDallyang() async {
    if (_asking) {
      _toast('달냥이가 생각 중이야…');
      return;
    }

    final cardOk = _isRevealed && _pickedCards.length == _cardCount;
    if (!cardOk) {
      _toast('카드를 먼저 $_cardCount장 뽑아줘!');
      return;
    }

    setState(() {
      _dallyangHint = null;
      _asking = true;
    });
    _toast('달냥이가 생각 중…');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw DalnyangKnownException('로그인이 필요해!');

      final String idToken = (await user.getIdToken(true)) ?? '';
      if (idToken.isEmpty) {
        throw DalnyangKnownException('로그인 토큰을 가져오지 못했어. 다시 로그인해줘!');
      }

      final deviceId = await DeviceIdService.getOrCreate();

      final ids = _pickedCards.take(_cardCount).toList();
      final koCards = ids.map(_cardKoName).toList();

      final String question = '오늘의 카드 $_cardCount장을 해석해줘.';

      final answer = await DalnyangApi.ask(
        idToken: idToken,
        deviceId: deviceId,
        question: question,
        context: {'cards_ko': koCards},
      );

      if (!mounted) return;

      setState(() => _dallyangHint = answer);
      _toast('달냥이가 답을 줬어!');
      _scrollToHintBox();
    } catch (e) {
      await handleDalnyangError(context, e);
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  // ================== LIFECYCLE ==================
  @override
  void initState() {
    super.initState();

    _selectedDate = widget.selectedDate ??
        widget.initialDate ??
        DateTime.now().add(const Duration(days: 1));

    _beforeCtrl.addListener(() {
      _markTouched();
      setState(() {});
    });
    _afterCtrl.addListener(() {
      _markTouched();
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDiary();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _beforeCtrl.dispose();
    _afterCtrl.dispose();
    super.dispose();
  }

  // ================== LOAD ==================
  Future<void> _loadDiary() async {
    setState(() => _loading = true);
    try {
      final data = await DiaryRepo.I.read(date: _selectedDate);
      if (!mounted) return;

      _hydrating = true;

      if (data == null) {
        setState(() {
          _cardCount = 1;
          _pickedCards = [];
          _isRevealed = false;

          _beforeCtrl.text = '';
          _afterCtrl.text = '';
          _afterUnlocked = _canUnlockAfter;

          _dallyangHint = null;
          _asking = false;

          _touched = false;
        });
        _hydrating = false;
        return;
      }

      final int cc = (data['cardCount'] as int?) ?? 1;
      final List<int> cards = (data['cards'] as List).cast<int>();

      final beforeText = (data['beforeText'] ?? '').toString();
      final afterText = (data['afterText'] ?? '').toString();

      setState(() {
        _cardCount = cc.clamp(1, 3);
        _pickedCards = cards.take(_cardCount).toList();
        _isRevealed = _pickedCards.length == _cardCount;

        _beforeCtrl.text = beforeText;
        _afterCtrl.text = afterText;
        _afterUnlocked = _canUnlockAfter || _hasText(_afterCtrl.text);

        _dallyangHint = null;
        _asking = false;

        _touched = false;
      });

      _hydrating = false;
    } catch (e) {
      if (!mounted) return;
      _errorLong('불러오기 실패:\n$e');
    } finally {
      _hydrating = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  // ================== SAVE ==================
  Future<void> _save() async {
    if (_saving) {
      _toast('이미 저장 중…');
      return;
    }

    final cardOk = _pickedCards.length == _cardCount;
    if (!cardOk) {
      _toast('카드를 $_cardCount장 선택(또는 뽑기) 완료해줘!');
      return;
    }

    final textOk =
        _hasText(_beforeCtrl.text) || (_afterUnlocked && _hasText(_afterCtrl.text));
    if (!textOk) {
      _toast('텍스트를 한 줄이라도 적어줘!');
      return;
    }

    setState(() => _saving = true);

    try {
      _toast('저장 중…(로컬)');

      await DiaryRepo.I.save(
        date: _selectedDate,
        cardCount: _cardCount,
        cards: _pickedCards,
        beforeText: _beforeCtrl.text.trim(),
        afterText: _afterUnlocked ? _afterCtrl.text.trim() : '',
      ).timeout(const Duration(seconds: 2));

      if (!mounted) return;

      _toast('저장 완료!');
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on TimeoutException {
      if (!mounted) return;
      _toast('저장이 너무 오래 걸려서 중단했어. (기기 저장소 확인)');
    } catch (e) {
      if (!mounted) return;
      _errorLong('저장 실패:\n$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ================== CARD PICK ==================
  void _autoPick() {
    _markTouched();

    final r = math.Random();
    final set = <int>{};
    while (set.length < _cardCount) set.add(r.nextInt(78));
    setState(() {
      _pickedCards = set.toList();
      _isRevealed = true;
      _dallyangHint = null;
    });
  }

  Future<void> _manualPick() async {
    final pickedIds = await cp.openCardPicker(
      context: context,
      maxPickCount: _cardCount,
      preselected: _pickedCards,
    );

    if (!mounted || pickedIds == null) return;

    if (pickedIds.length != _cardCount) {
      _toast('$_cardCount장을 선택해줘!');
      return;
    }

    _markTouched();
    setState(() {
      _pickedCards = pickedIds;
      _isRevealed = true;
      _dallyangHint = null;
    });
  }

  void _resetPick() {
    _markTouched();
    setState(() {
      _pickedCards = [];
      _isRevealed = false;
      _dallyangHint = null;
    });
  }

  // ================== BG ==================
  Widget _bg({required Widget child}) {
    return Container(color: AppTheme.bgSolid, child: child);
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    const double fabH = 120.0;
    final viewInsetB = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 6),
        child: Column(
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
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: _bg(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: EdgeInsets.fromLTRB(
                    0,
                    LayoutTokens.scrollTopPad,
                    0,
                    LayoutTokens.scrollBottomBase + viewInsetB + fabH,
                  ),
                  child: Column(
                    children: [
                      TopBox(
                        left: Transform.translate(
                          offset: const Offset(LayoutTokens.backBtnNudgeX, 0),
                          child: _TightIconButton(
                            icon: Icons.arrow_back_rounded,
                            color: AppTheme.headerInk,
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                        title: Text('내일의 타로일기', style: AppTheme.title),
                        right: _buildTopRightDatePill(),
                      ),
                      const SizedBox(height: 14),
                      CenterBox(
                        child: Column(
                          children: [
                            if (_loading)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  '불러오는 중…',
                                  style: AppTheme.uiSmallLabel.copyWith(
                                    color: _a(AppTheme.tSecondary, 0.75),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            _buildCardSection(),
                            const SizedBox(height: 16),
                            _buildDiaryInputs(),
                            const SizedBox(height: 12),
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
      ),
    );
  }

  Widget _buildTopRightDatePill() {
    final accent = _a(AppTheme.gold, 0.75);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.glassBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _a(accent, 0.45), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month, size: 13, color: accent),
          const SizedBox(width: 6),
          Text(
            _formatKoreanDate(_selectedDate),
            style: AppTheme.uiSmallLabel.copyWith(
              color: _a(AppTheme.headerInk, 0.9),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: glassPanelDecoration(),
      child: Column(
        children: [
          _buildCardList(),
          const SizedBox(height: 12),
          _buildCardCountRow(),
          const SizedBox(height: 18),
          _buildPickButtons(),
        ],
      ),
    );
  }

  Widget _buildCardCountRow() {
    final disabled = _isRevealed;

    BorderRadius _radiusForIndex(int index, bool selected) {
      if (selected) return BorderRadius.circular(8);

      switch (index) {
        case 0:
          return const BorderRadius.horizontal(left: Radius.circular(10));
        case 2:
          return const BorderRadius.horizontal(right: Radius.circular(10));
        default:
          return BorderRadius.zero;
      }
    }

    Widget segItem(int v, int index) {
      final selected = _cardCount == v;

      return Expanded(
        child: InkWell(
          onTap: disabled
              ? null
              : () {
            _markTouched();
            setState(() {
              _cardCount = v;
              _pickedCards = [];
              _isRevealed = false;
              _dallyangHint = null;
            });
          },
          borderRadius: _radiusForIndex(index, selected),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? _a(AppTheme.gold, 0.18) : Colors.transparent,
              borderRadius: _radiusForIndex(index, selected),
              border: selected
                  ? Border.all(color: _a(AppTheme.gold, 0.55), width: 1)
                  : null,
            ),
            child: Opacity(
              opacity: (disabled && !selected) ? 0.35 : 1.0,
              child: Text(
                '${v}장',
                style: AppTheme.uiSmallLabel.copyWith(
                  color: selected
                      ? _a(AppTheme.tPrimary, 0.85)
                      : _a(AppTheme.tSecondary, 0.80),
                  fontSize: 12.2,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '카드 장수  ',
          style: _tsMeta.copyWith(color: _a(AppTheme.tSecondary, 0.70)),
        ),
        const SizedBox(width: 16),
        Container(
          height: 32,
          width: 160,
          padding: const EdgeInsets.all(0.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _a(Colors.white, 0.03),
            border: Border.all(color: AppTheme.panelBorder, width: 1),
          ),
          child: Row(
            children: [
              segItem(1, 0),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: _a(AppTheme.gold, 0.12),
              ),
              segItem(2, 1),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: _a(AppTheme.gold, 0.12),
              ),
              segItem(3, 2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardList() {
    const double targetCardW = 92.0;
    const double gap = 6.0;
    const double cardR = 10.0;

    Widget cardItem(int i, double cardW) {
      final has = _isRevealed && _pickedCards.length > i;

      final String path = has
          ? 'asset/cards/${ArcanaLabels.kTarotFileNames[_pickedCards[i]]}'
          : 'asset/cards/back.png';

      final List<BoxShadow> shadows = [
        BoxShadow(
          color: _a(Colors.black, has ? 0.18 : 0.16),
          blurRadius: has ? 8 : 6,
          offset: const Offset(0, 6),
        ),
        if (!has) ...[
          BoxShadow(
            color: _a(AppTheme.gold, 0.22),
            blurRadius: 22,
            spreadRadius: 1.2,
            offset: const Offset(0, 0),
          ),
          BoxShadow(
            color: _a(AppTheme.gold, 0.10),
            blurRadius: 6,
            spreadRadius: 0.2,
            offset: const Offset(0, 0),
          ),
        ],
      ];

      return SizedBox(
        width: cardW,
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cardR),
              boxShadow: shadows,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(cardR),
              child: Container(
                color: _a(Colors.black, has ? 0.08 : 0.12),
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: has ? 1.03 : 1.00,
                  child: Image.asset(
                    path,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final count = _cardCount.clamp(1, 3);
        final fitW = (maxW - gap * (count - 1)) / count;
        final cardW = math.min(targetCardW, fitW);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (i) {
            return Padding(
              padding: EdgeInsets.only(right: i == count - 1 ? 0 : gap),
              child: cardItem(i, cardW),
            );
          }),
        );
      },
    );
  }

  Widget _buildPickButtons() {
    if (_isRevealed) {
      return SizedBox(
        height: _actionBtnH,
        child: OutlinedButton.icon(
          onPressed: _resetPick,
          icon: Icon(Icons.refresh, size: 16, color: _a(AppTheme.tSecondary, 0.85)),
          label: Text(
            '카드 다시 뽑기',
            style: AppTheme.uiSmallLabel.copyWith(
              color: _a(AppTheme.tSecondary, 0.85),
              fontSize: 12.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: _a(Colors.white, 0.02),
            side: BorderSide(color: _a(AppTheme.gold, 0.28), width: 0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_btnRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 132,
          child: _primaryPickBtn(
            label: '자동 뽑기',
            icon: Icons.auto_awesome,
            onTap: _autoPick,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: _secondaryPickBtn(
            label: '수동 뽑기',
            icon: Icons.touch_app,
            onTap: () async => await _manualPick(),
          ),
        ),
      ],
    );
  }

  Widget _primaryPickBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: _actionBtnH,
      child: ElevatedButton.icon(
        onPressed: () {
          _markTouched();
          onTap();
        },
        icon: Icon(icon, size: 15, color: _a(AppTheme.tPrimary, 0.95)),
        label: Text(
          label,
          style: AppTheme.uiSmallLabel.copyWith(
            color: _a(AppTheme.tPrimary, 0.90),
            fontWeight: FontWeight.w700,
            fontSize: 12.0,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _a(AppTheme.gold, 0.18),
          foregroundColor: AppTheme.tPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _a(AppTheme.gold, 0.55), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        ),
      ),
    );
  }

  Widget _secondaryPickBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: _actionBtnH,
      child: OutlinedButton.icon(
        onPressed: () {
          _markTouched();
          onTap();
        },
        icon: Icon(icon, color: _a(AppTheme.tSecondary, 0.90), size: 15),
        label: Text(
          label,
          style: AppTheme.uiSmallLabel.copyWith(
            color: _a(AppTheme.tSecondary, 0.90),
            fontWeight: FontWeight.w700,
            fontSize: 12.0,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: _a(AppTheme.tSecondary, 0.45), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        ),
      ),
    );
  }

  void _errorLong(String msg) {
    if (!mounted) return;
    showDalnyangErrorDialog(context, exceptionMessage: msg);
  }

  Widget _buildDiaryInputs() => _combinedDiaryBox();

  Widget _combinedDiaryBox() {
    final canUnlock = _canUnlockAfter;

    Widget inputPanel({
      required TextEditingController controller,
      required String hint,
      required bool enabled,
      int minLines = 6,
      Widget? overlay,
    }) {
      final radius = BorderRadius.circular(AppTheme.innerRadius);

      return ClipRRect(
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            color: _a(AppTheme.panelFill, 0.58),
            border: Border.all(color: AppTheme.panelBorderSoft),
            borderRadius: radius,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: AbsorbPointer(
                  absorbing: !enabled,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 140),
                    child: TextField(
                      controller: controller,
                      enabled: true,
                      minLines: minLines,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      style: _tsBody,
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: _tsHint,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ),
              if (overlay != null) Positioned.fill(child: overlay),
            ],
          ),
        ),
      );
    }

    final confirmMsg = '''
뽑힌 카드: ${_isRevealed && _pickedCards.length == _cardCount ? _cardsSummaryLine() : '아직 없음'}

Before 내용(요약): ${_hasText(_beforeCtrl.text)
        ? (_beforeCtrl.text.trim().length > 60
        ? '${_beforeCtrl.text.trim().substring(0, 60)}…'
        : _beforeCtrl.text.trim())
        : '아직 없음'}

광고 1회 시청 후 달냥이가 힌트를 줄게!
'''.trim();

    Widget hintBox() {
      if (_asking) {
        return Container(
          key: _hintKey,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: _a(AppTheme.panelFill, 0.46),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _a(AppTheme.gold, 0.14), width: 1),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_a(AppTheme.gold, 0.85)),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '달냥이가 답변 작성 중…',
                style: AppTheme.uiSmallLabel.copyWith(
                  color: _a(AppTheme.tSecondary, 0.92),
                  fontSize: 12.6,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      }

      final hint = _dallyangHint;
      if (hint == null || hint.trim().isEmpty) return const SizedBox.shrink();

      return Container(
        key: _hintKey,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _a(AppTheme.panelFill, 0.46),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _a(AppTheme.gold, 0.14), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pets_rounded, size: 16, color: _a(AppTheme.gold, 0.85)),
                const SizedBox(width: 6),
                Text(
                  '달냥이 답변',
                  style: AppTheme.uiSmallLabel.copyWith(
                    color: _a(AppTheme.tPrimary, 0.88),
                    fontSize: 12.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 30,
                  child: OutlinedButton(
                    onPressed: _applyHintToBefore,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _a(AppTheme.gold, 0.30), width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity:
                      const VisualDensity(horizontal: -2, vertical: -2),
                      backgroundColor: _a(Colors.white, 0.02),
                    ),
                    child: Text(
                      'Before에 적용',
                      style: AppTheme.uiSmallLabel.copyWith(
                        color: _a(AppTheme.tSecondary, 0.90),
                        fontSize: 11.6,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hint.trim(),
              style: AppTheme.body.copyWith(
                fontSize: 13.2,
                height: 1.35,
                color: _a(AppTheme.tSecondary, 0.92),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: glassPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('예상 기록 (Before)', style: _tsSectionTitle),
              const Spacer(),
              DallyangAskPill(
                enabled: _canAskDallyang,
                confirmMessage: confirmMsg,
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

                    await _askDallyang();
                  } catch (e) {
                    await handleDalnyangError(context, e);
                  }
                },
                onDisabledTap: () {
                  if (!_isRevealed || _pickedCards.length != _cardCount) {
                    _toast('카드를 먼저 $_cardCount장 뽑아줘!');
                    return;
                  }
                  if (_asking) _toast('달냥이가 생각 중이야…');
                },
                onNotReady: () => _toast('광고 준비 중이야. 잠깐만 다시 눌러줘!'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          inputPanel(
            controller: _beforeCtrl,
            hint: '카드를 뽑고, 내일은 어떤 하루가 될지 적어봐.',
            enabled: true,
            minLines: 7,
          ),
          hintBox(),
          const SizedBox(height: 12),
          Container(height: 1, color: _a(AppTheme.gold, 0.13)),
          const SizedBox(height: 12),
          Text('실제 기록 (After)', style: _tsSectionTitle),
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_afterUnlocked) return;
              if (!canUnlock) {
                _toast('당일(또는 그 이후)부터 기록할 수 있어!');
                return;
              }
              _markTouched();
              setState(() => _afterUnlocked = true);
            },
            child: inputPanel(
              controller: _afterCtrl,
              hint: '오늘을 실제로 겪어보니 어떤 하루였어?',
              enabled: _afterUnlocked,
              minLines: 7,
              overlay: !_afterUnlocked
                  ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _a(const Color(0xFFB8B2A6), 0.12),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: _a(const Color(0xFFB9B4A8), 0.65),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canUnlock ? '탭해서 실제 기록을 열어줘!' : '내일이 되면 쓸 수 있어!',
                      textAlign: TextAlign.center,
                      style: AppTheme.uiSmallLabel.copyWith(
                        color: _a(AppTheme.headerInk, 0.68),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ 상단 아이콘 타이트 버튼
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
