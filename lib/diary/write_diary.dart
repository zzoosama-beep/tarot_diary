// write_diary.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../backend/diary_repo.dart';
import '../cardpicker.dart' as cp;

// ✅ 레이아웃 규격 토큰 (TopBox/CenterBox/BottomBox 포함)
import '../ui/layout_tokens.dart';
// ✅ 공용 CTA 버튼 (저장/수정/삭제)
import '../ui/app_buttons.dart';

// ✅ 공통 테마
import '../theme/app_theme.dart';

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

  void _markTouched() {
    if (_hydrating) return;
    if (_touched) return;
    setState(() => _touched = true);
  }

  // ================== HELPERS ==================
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

  // ================== TYPO (AppTheme 기반) ==================
  TextStyle get _tsSectionTitle => AppTheme.month.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w900,
    color: _a(AppTheme.gold, 0.80),
  );

  TextStyle get _tsBody => AppTheme.body.copyWith(
    fontSize: 15, // ✅ 기존 write_diary 가독성 유지
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

  // ================== TOAST (box-width) ==================
  OverlayEntry? _toastEntry;

  void _toast(String msg) {
    if (!mounted) return;

    FocusScope.of(context).unfocus();

    _toastEntry?.remove();
    _toastEntry = null;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    // ✅ 센터 컨텐츠 폭에 맞추기: left/right = pageHPad + (센터 패널 내부 padding 14)
    const double side = LayoutTokens.pageHPad + 14;

    _toastEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: side,
        right: side,
        bottom: 110,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _a(Colors.black, 0.78),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              msg,
              textAlign: TextAlign.center,
              style: AppTheme.uiSmallLabel.copyWith(
                color: _a(AppTheme.tPrimary, 0.92),
                fontSize: 12.5,
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_toastEntry!);

    Future.delayed(const Duration(seconds: 2), () {
      _toastEntry?.remove();
      _toastEntry = null;
    });
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

  // ================== LIFECYCLE ==================
  @override
  void initState() {
    super.initState();

    _selectedDate =
        widget.selectedDate ?? widget.initialDate ?? DateTime.now().add(const Duration(days: 1));

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
    _toastEntry?.remove();
    _beforeCtrl.dispose();
    _afterCtrl.dispose();
    super.dispose();
  }

  // ================== LOAD ==================
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
          _afterUnlocked = _canUnlockAfter; // ✅ 오늘/과거면 바로 작성 가능

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

        _touched = false;
      });

      _hydrating = false;
    } catch (e) {
      if (mounted) _toast('불러오기 실패: $e');
    } finally {
      _hydrating = false;
      if (mounted) setState(() => _loading = false);
    }
  }


  // ================== SAVE ==================
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
      _toast('저장 실패: $e');
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
    });
  }

  void _resetPick() {
    _markTouched();
    setState(() {
      _pickedCards = [];
      _isRevealed = false;
    });
  }

  // ================== BG ==================
  Widget _bg({required Widget child}) {
    return Container(color: AppTheme.bgSolid, child: child);
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    // ✅ 플로팅 버튼 높이 + 바닥 여백
    const double floatH = 44.0;
    const double floatBottomGap = 14.0;

    final viewInsetB = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: _bg(
        child: SafeArea(
          child: Stack(
            children: [
              // =========================
              // MAIN (스크롤 영역)
              // =========================
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    LayoutTokens.scrollTopPad,
                    0,
                    LayoutTokens.scrollBottomBase +
                        viewInsetB +
                        floatH +
                        floatBottomGap +
                        10,
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

              // =========================
              // FLOATING CTA (저장하기)
              // =========================
              Positioned(
                left: LayoutTokens.pageHPad,
                right: LayoutTokens.pageHPad,
                bottom: floatBottomGap + viewInsetB,
                child: IgnorePointer(
                  ignoring: _saving,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    opacity: viewInsetB > 0 ? 0.96 : 1.0,
                    child: _buildSaveButton(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ✅ TopBox 우측 슬롯: 날짜 pill
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
      decoration: glassPanelDecoration(), // ✅ 그림자 포함 패널 데코
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

      // ✅ 앞/뒷면 경로
      final String path = has
          ? 'asset/cards/${cp.kTarotFileNames[_pickedCards[i]]}'
          : 'asset/cards/back.png';

      // ✅ 앞/뒷면 글로우 전략
      // - back: 은은한 골드 헤일로 + 살짝 라인 느낌
      // - front: 글로우 거의 제거(카드 내용 선명)
      final List<BoxShadow> shadows = [
        // 공통: 기본 깊이감(블랙)
        BoxShadow(
          color: _a(Colors.black, has ? 0.18 : 0.16),
          blurRadius: has ? 8 : 6,
          offset: const Offset(0, 6),
        ),

        if (!has) ...[
          // ✅ back 전용: 퍼지는 골드 빛(은은하게)
          BoxShadow(
            color: _a(AppTheme.gold, 0.22),
            blurRadius: 22,
            spreadRadius: 1.2,
            offset: const Offset(0, 0),
          ),
          // ✅ back 전용: 바깥 가장자리 라인 느낌(아주 약하게)
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
                // ✅ back은 살짝 어둡게 받쳐주면 글로우가 더 고급스럽게 보임
                color: _a(Colors.black, has ? 0.08 : 0.12),
                alignment: Alignment.center,
                child: Transform.scale(
                  // ✅ 앞면은 살짝만(기존 느낌 유지), 뒷면은 확대 X
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
          icon: Icon(
            Icons.refresh,
            size: 16,
            color: _a(AppTheme.tSecondary, 0.85),
          ),
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

  Widget _buildDiaryInputs() => _combinedDiaryBox();

  Widget _combinedDiaryBox() {
    final canUnlock = _canUnlockAfter;

    Widget inputPanel({
      required TextEditingController controller,
      required String hint,
      required bool enabled,
      required double height,
      Widget? overlay,
    }) {
      final radius = BorderRadius.circular(AppTheme.innerRadius);

      return ClipRRect(
        borderRadius: radius,
        child: Container(
          height: height,
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
                  child: TextField(
                    controller: controller,
                    enabled: true,
                    expands: true,
                    maxLines: null,
                    minLines: null,
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
              if (overlay != null) Positioned.fill(child: overlay),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: glassPanelDecoration(), // ✅ 그림자 포함 패널 데코
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('예상 기록 (Before)', style: _tsSectionTitle),
          const SizedBox(height: 8),
          inputPanel(
            controller: _beforeCtrl,
            hint: '카드를 뽑고, 내일은 어떤 하루가 될지 적어봐.',
            enabled: true,
            height: 145,
          ),
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
              height: 140,
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

  Widget _buildSaveButton() {
    final can = _canSave && !_saving;

    return AppCtaButton(
      label: _saving ? '저장 중…' : '저장하기',
      icon: Icons.save_rounded,
      onPressed: can ? _trySave : null,
      emphasis: true,
      danger: false,
      height: 44,
      fontSize: 14.0,
      radius: _btnRadius.toDouble(),
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
