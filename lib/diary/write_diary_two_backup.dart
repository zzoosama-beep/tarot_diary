import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

// ✅ 달냥이(챗GPT) 연결용
import '../error/app_error_handler.dart';
import '../backend/dalnyang_service.dart';

import '../theme/app_theme.dart';
import '../ui/layout_tokens.dart';
import '../ui/app_toast.dart';
import '../arcana/arcana_labels.dart';
import '../backend/diary_repo.dart';
import '../error/app_error_dialog.dart';

import '../diary/calander_diary.dart';

Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class WriteDiaryTwoPage extends StatefulWidget {
  final List<int> pickedCardIds; // 1~3장
  final int cardCount; // 1~3
  final DateTime? selectedDate;

  /// ✅ 기존 기록 있으면 불러온 텍스트(수정 모드 프리필)
  final String? initialBeforeText;

  const WriteDiaryTwoPage({
    super.key,
    required this.pickedCardIds,
    required this.cardCount,
    this.selectedDate,
    this.initialBeforeText,
  });

  @override
  State<WriteDiaryTwoPage> createState() => _WriteDiaryTwoPageState();
}

class _WriteDiaryTwoPageState extends State<WriteDiaryTwoPage> {
  final TextEditingController _c = TextEditingController();
  final FocusNode _focus = FocusNode();

  bool _saving = false;
  bool _asking = false;
  bool _pasting = false;

  bool get _isBusy => _saving || _asking || _pasting;
  bool get _canSave => !_isBusy;

  DateTime get _saveDate {
    final d = widget.selectedDate;
    if (d != null) return DateTime(d.year, d.month, d.day);

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  bool _hasText(String v) =>
      v.replaceAll(RegExp(r'[\s\u200B-\u200D\uFEFF]'), '').isNotEmpty;

  void _toast(String msg, {double bottom = 110}) {
    if (!mounted) return;
    AppToast.show(context, msg);
  }

  void _errorLong(String msg) {
    if (!mounted) return;
    showDalnyangErrorDialog(context, message: msg);
  }

  String _cardKoName(int id) {
    final koMajor = ArcanaLabels.majorKoName(id);
    if (koMajor != null) return koMajor;

    final fn = ArcanaLabels.kTarotFileNames[id];
    return ArcanaLabels.minorKoFromFilename(fn) ??
        ArcanaLabels.prettyEnTitleFromFilename(fn);
  }

  bool get _canAskDallyang {
    final cc = widget.cardCount.clamp(1, 3);
    final cards = widget.pickedCardIds.take(cc).toList();
    final ok = cards.length == cc;
    return ok && !_isBusy;
  }

  @override
  void initState() {
    super.initState();

    final t = widget.initialBeforeText;
    if (t != null && t.trim().isNotEmpty) {
      _c.text = t;
      _c.selection = TextSelection.collapsed(offset: _c.text.length);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _appendDalnyangToText(String answer) async {
    if (!mounted) return;

    final a = answer.trim();
    if (a.isEmpty) return;

    final current = _c.text.trimRight();
    final prefix = current.isEmpty ? '' : '$current\n\n---\n';
    final content = current.isEmpty ? a : '$a\n';

    setState(() {
      _pasting = true;
      _c.text = prefix;
      _c.selection = TextSelection.collapsed(offset: _c.text.length);
    });

    try {
      const int chunkSize = 6;
      const Duration step = Duration(milliseconds: 16);

      for (int i = 0; i < content.length; i += chunkSize) {
        if (!mounted) return;

        final end = math.min(i + chunkSize, content.length);
        final chunk = content.substring(i, end);

        _c.text += chunk;
        _c.selection = TextSelection.collapsed(offset: _c.text.length);

        setState(() {});
        await Future.delayed(step);
      }

      _toast('달냥이 해석을 적어줬어! ✍️');
    } finally {
      if (mounted) {
        setState(() => _pasting = false);
      }
    }
  }

  Future<void> _onAskDalnyang() async {
    if (_asking) {
      _toast('달냥이가 생각 중이야…');
      return;
    }

    if (_pasting) {
      _toast('달냥이가 글을 적는 중이야…');
      return;
    }

    setState(() => _asking = true);
    _toast('달냥이가 해석 중…');

    try {
      final answer = await DalnyangService.askWithCoin(
        context: context,
        pickedCardIds: widget.pickedCardIds,
        cardCount: widget.cardCount,
        cardNameBuilder: _cardKoName,
      );

      if (!mounted || answer == null) return;
      await _appendDalnyangToText(answer);
    } catch (e) {
      await handleDalnyangError(context, e);
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }


  Future<void> _onSave() async {
    if (_isBusy) return;

    final cc = widget.cardCount.clamp(1, 3);
    final cards = widget.pickedCardIds.take(cc).toList();
    if (cards.length != cc) {
      _toast('카드를 $cc장 선택 완료해줘!');
      return;
    }

    final text = _c.text.trim();
    if (!_hasText(text)) {
      _toast('텍스트를 한 줄이라도 적어줘!');
      return;
    }

    setState(() => _saving = true);

    try {
      _toast('저장 중…(로컬)');

      await DiaryRepo.I
          .save(
        date: _saveDate,
        cardCount: cc,
        cards: cards,
        beforeText: text,
        afterText: '',
      )
          .timeout(const Duration(seconds: 2));

      if (!mounted) return;

      _toast('저장 완료!');
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => CalanderDiaryPage(
            selectedDate: _saveDate,
          ),
        ),
            (route) => route.isFirst,
      );
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

  double _responsiveInputHeight({
    required double viewportHeight,
    required bool keyboardOpen,
  }) {
    final ratio = keyboardOpen ? 0.25 : 0.34;
    final minH = keyboardOpen ? 180.0 : 260.0;
    final maxH = keyboardOpen ? 260.0 : 420.0;
    return (viewportHeight * ratio).clamp(minH, maxH);
  }

  @override
  Widget build(BuildContext context) {
    final contentW = LayoutTokens.contentW(context);
    final viewInsets = MediaQuery.of(context).viewInsets;
    final keyboardInset = viewInsets.bottom;
    final keyboardOpen = keyboardInset > 0;
    final double btnW = math.min(contentW, 320.0);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportH = constraints.maxHeight;
            final inputH = _responsiveInputHeight(
              viewportHeight: viewportH,
              keyboardOpen: keyboardOpen,
            );

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentW,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(bottom: keyboardInset + 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: viewportH,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        _HeaderBar(
                          title: '내일 타로일기 쓰기',
                          onBack: () => Navigator.of(context).maybePop(),
                        ),
                        SizedBox(height: keyboardOpen ? 18 : 28),
                        _PickedCardsRowLikeOne(
                          pickedIds: widget.pickedCardIds,
                          cardCount: widget.cardCount,
                        ),
                        const SizedBox(height: 18),
                        _ThinLine(focusNode: _focus),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.center,
                          child: _DalnyangChanceChip(
                            enabled: _canAskDallyang,
                            asking: _asking || _pasting,
                            onTap: _onAskDalnyang,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: inputH,
                          child: _DiaryInputTransparent(
                            controller: _c,
                            focusNode: _focus,
                          ),
                        ),
                        SizedBox(height: keyboardOpen ? 20 : 44),
                        _ThinLine(focusNode: _focus),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: btnW,
                            child: _SaveButton(
                              enabled: _canSave,
                              busy: _isBusy,
                              onTap: _onSave,
                              compact: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ===============================
/// 헤더
/// ===============================
class _HeaderBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _HeaderBar({
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final w = LayoutTokens.contentW(context);

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: w,
        child: Row(
          children: [
            Transform.translate(
              offset: const Offset(LayoutTokens.backBtnNudgeX, 0),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: _a(AppTheme.homeInkWarm, 0.95),
                onPressed: onBack,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.title.copyWith(
                  color: _a(AppTheme.homeInkWarm, 0.96),
                ),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// 카드 Row
/// ===============================
class _PickedCardsRowLikeOne extends StatelessWidget {
  final List<int> pickedIds;
  final int cardCount;

  const _PickedCardsRowLikeOne({
    required this.pickedIds,
    required this.cardCount,
  });

  @override
  Widget build(BuildContext context) {
    final w = LayoutTokens.contentW(context);
    const gap = 12.0;
    final c = cardCount.clamp(1, 3);

    const maxCardW = 104.0;
    final fitWFor3 = (w - (gap * 2)) / 3;
    final cardW = math.min(maxCardW, fitWFor3);
    final cardH = cardW * 1.55;

    double yOffsetFor(int i) {
      if (c == 1) return 0;
      if (c == 2) return i == 0 ? 1 : -1;
      if (i == 1) return -4;
      return i == 0 ? 1 : 0;
    }

    final rowWFor3 = (cardW * 3) + (gap * 2);

    return SizedBox(
      width: rowWFor3,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(c, (i) {
          final id = (i < pickedIds.length) ? pickedIds[i] : null;

          return Padding(
            padding: EdgeInsets.only(right: i == c - 1 ? 0 : gap),
            child: Transform.translate(
              offset: Offset(0, yOffsetFor(i)),
              child: _TarotFrontCardPreview(
                width: cardW,
                height: cardH,
                cardId: id,
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// ===============================
/// 앞면 프리뷰
/// ===============================
class _TarotFrontCardPreview extends StatelessWidget {
  final double width;
  final double height;
  final int? cardId;

  const _TarotFrontCardPreview({
    required this.width,
    required this.height,
    required this.cardId,
  });

  @override
  Widget build(BuildContext context) {
    const outerR = 9.0;

    final id = cardId;
    if (id == null || id < 0 || id >= ArcanaLabels.kTarotFileNames.length) {
      final paper = _a(const Color(0xFFFFF2E6), 0.96);
      final ink = _a(const Color(0xFF3A2147), 0.84);

      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(outerR),
          boxShadow: [
            BoxShadow(
              color: _a(Colors.black, 0.10),
              blurRadius: 12,
              offset: const Offset(0, 10),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Center(child: Icon(Icons.style_rounded, size: 18, color: ink)),
      );
    }

    final fn = ArcanaLabels.kTarotFileNames[id];
    final path = 'asset/cards/$fn';

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outerR),
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.18),
            blurRadius: 16,
            offset: const Offset(0, 12),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(outerR),
        child: Container(
          color: _a(Colors.black, 0.06),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.2, vertical: 1.8),
            child: Transform.scale(
              scaleX: 1.06,
              scaleY: 1.04,
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
    );
  }
}

/// ===============================
/// 달냥이 찬스
/// ===============================
class _DalnyangChanceChip extends StatefulWidget {
  final bool enabled;
  final bool asking;
  final VoidCallback onTap;

  const _DalnyangChanceChip({
    required this.enabled,
    required this.asking,
    required this.onTap,
  });

  @override
  State<_DalnyangChanceChip> createState() => _DalnyangChanceChipState();
}

class _DalnyangChanceChipState extends State<_DalnyangChanceChip> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    const r = 18.0;

    final border = enabled ? _a(Colors.white, 0.14) : _a(Colors.white, 0.08);
    final fill = enabled ? _a(Colors.white, 0.05) : _a(Colors.white, 0.03);

    final title =
    enabled ? _a(AppTheme.homeInkWarm, 0.92) : _a(AppTheme.homeInkWarm, 0.46);
    final sub =
    enabled ? _a(AppTheme.homeInkWarm, 0.46) : _a(AppTheme.homeInkWarm, 0.28);

    return IgnorePointer(
      ignoring: !enabled,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        scale: _down ? 0.985 : 1.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: border, width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(r),
              onTap: widget.onTap,
              onTapDown: (_) => _setDown(true),
              onTapCancel: () => _setDown(false),
              onTapUp: (_) => _setDown(false),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🐱 달냥이 찬스',
                          style: AppTheme.uiSmallLabel.copyWith(
                            fontSize: 12.8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.15,
                            height: 1.0,
                            color: title,
                          ),
                        ),
                        if (widget.asking) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _a(Colors.white, 0.55),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '(카드해석 도움)',
                      style: AppTheme.uiSmallLabel.copyWith(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                        height: 1.0,
                        color: sub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ===============================
/// 얇은 라인
/// ===============================
class _ThinLine extends StatefulWidget {
  final FocusNode focusNode;
  const _ThinLine({required this.focusNode});

  @override
  State<_ThinLine> createState() => _ThinLineState();
}

class _ThinLineState extends State<_ThinLine> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  void _onFocus() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    final line = _a(Colors.white, focused ? 0.22 : 0.10);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 1,
      decoration: BoxDecoration(
        color: line,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

/// ===============================
/// 입력 박스
/// ===============================
class _DiaryInputTransparent extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const _DiaryInputTransparent({
    required this.controller,
    required this.focusNode,
  });

  @override
  State<_DiaryInputTransparent> createState() => _DiaryInputTransparentState();
}

class _DiaryInputTransparentState extends State<_DiaryInputTransparent> {
  final ScrollController _scrollC = ScrollController();

  @override
  void dispose() {
    _scrollC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint = _a(AppTheme.homeInkWarm, 0.40);
    final text = _a(AppTheme.homeInkWarm, 0.92);
    final cursor = _a(AppTheme.homeInkWarm, 0.72);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        scrollController: _scrollC,
        cursorColor: cursor,
        expands: true,
        maxLines: null,
        minLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: AppTheme.uiSmallLabel.copyWith(
          fontSize: 14.2,
          height: 1.55,
          fontWeight: FontWeight.w800,
          color: text,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          filled: false,
          hintText: '내일의 감정, 예상되는 장면, 카드가 말해주는 흐름…\n짧게라도 좋아! 여기에 기록해줘.',
          hintStyle: AppTheme.uiSmallLabel.copyWith(
            fontSize: 13.2,
            height: 1.5,
            fontWeight: FontWeight.w800,
            color: hint,
          ),
          contentPadding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
        ),
      ),
    );
  }
}

/// ===============================
/// 저장 버튼
/// ===============================
class _SaveButton extends StatefulWidget {
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;
  final bool compact;

  const _SaveButton({
    required this.enabled,
    required this.busy,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  void didUpdateWidget(covariant _SaveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _down) {
      _down = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;

    final h = widget.compact ? 46.0 : 54.0;
    final r = widget.compact ? 16.0 : 18.0;

    final base =
    enabled ? _a(const Color(0xFFFFF2E6), 0.94) : _a(Colors.white, 0.50);
    final border =
    enabled ? _a(AppTheme.headerInk, 0.18) : _a(AppTheme.panelBorder, 0.18);

    final text = enabled
        ? _a(const Color(0xFF3A2147), 0.92)
        : _a(const Color(0xFF3A2147), 0.45);
    final icon =
    enabled ? _a(AppTheme.headerInk, 0.76) : _a(AppTheme.headerInk, 0.38);

    return AbsorbPointer(
      absorbing: !enabled,
      child: SizedBox(
        height: h,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          scale: enabled && _down ? 0.985 : 1.0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r),
              color: base,
              border: Border.all(color: border, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: _a(Colors.black, enabled ? 0.16 : 0.10),
                  blurRadius: enabled ? 18 : 14,
                  offset: const Offset(0, 10),
                  spreadRadius: -6,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(r),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(r),
                  onTap: enabled ? widget.onTap : null,
                  onTapDown: enabled ? (_) => _setDown(true) : null,
                  onTapCancel: enabled ? () => _setDown(false) : null,
                  onTapUp: enabled ? (_) => _setDown(false) : null,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.busy)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(icon),
                            ),
                          )
                        else
                          Icon(Icons.save_rounded, size: 18, color: icon),
                        const SizedBox(width: 8),
                        Text(
                          widget.busy ? '처리 중...' : '저장하기',
                          style: AppTheme.uiSmallLabel.copyWith(
                            fontSize: 14.4,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}