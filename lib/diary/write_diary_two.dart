// lib/diary/write_diary_two.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

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
    AppToast.show(context, msg, bottom: bottom);
  }

  void _errorLong(String msg) {
    if (!mounted) return;
    showDalnyangErrorDialog(context, exceptionMessage: msg);
  }

  @override
  void initState() {
    super.initState();

    // ✅ 기존 텍스트 프리필은 여기서!
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

  Future<void> _onSave() async {
    if (_saving) return;

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

      // ✅ 저장 후 캘린더로 이동 (작성화면은 스택에서 정리)
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

  @override
  Widget build(BuildContext context) {
    final contentW = LayoutTokens.contentW(context);

    // ✅ 텍스트 박스 높이: 넉넉 + 과하지 않게 clamp
    final vh = MediaQuery.of(context).size.height;
    final inputH = (vh * 0.28).clamp(220.0, 320.0);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            _HeaderBar(
              title: '내일 타로일기 쓰기',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 14),

            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: contentW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 1),

                      _PickedCardsRowLikeOne(
                        pickedIds: widget.pickedCardIds,
                        cardCount: widget.cardCount,
                      ),

                      const SizedBox(height: 26),

                      SizedBox(
                        height: inputH,
                        child: _DiaryInputTransparent(
                          controller: _c,
                          focusNode: _focus,
                        ),
                      ),

                      const SizedBox(height: 44),

                      _ThinLine(focusNode: _focus),

                      const SizedBox(height: 18),

                      _SaveButton(
                        enabled: !_saving,
                        onTap: _onSave,
                        compact: true,
                      ),

                      const Spacer(flex: 3),
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
/// ✅ write_diary_one 카드 Row 느낌 그대로
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
/// ✅ 앞면 프리뷰
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
/// ✅ 얇은 라인 (텍스트박스 밖으로 분리)
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
    final line = _a(Colors.white, focused ? 0.18 : 0.10);

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
/// ✅ 입력 박스: 고정 높이 안에서 스크롤(TextField 자체 스크롤)
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
          hintText: '내일의 감정, 예상되는 장면, 카드가 말해주는 흐름…\n짧게라도 좋아.',
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
  final VoidCallback onTap;
  final bool compact;

  const _SaveButton({
    required this.enabled,
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
  Widget build(BuildContext context) {
    final enabled = widget.enabled;

    final h = widget.compact ? 46.0 : 54.0;
    final r = widget.compact ? 16.0 : 18.0;

    final base = enabled ? _a(const Color(0xFFFFF2E6), 0.94) : _a(Colors.white, 0.50);
    final border = enabled ? _a(AppTheme.headerInk, 0.18) : _a(AppTheme.panelBorder, 0.18);

    final text = enabled ? _a(const Color(0xFF3A2147), 0.92) : _a(const Color(0xFF3A2147), 0.45);
    final icon = enabled ? _a(AppTheme.headerInk, 0.76) : _a(AppTheme.headerInk, 0.38);

    return IgnorePointer(
      ignoring: !enabled,
      child: SizedBox(
        height: h,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          scale: _down ? 0.985 : 1.0,
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
                  onTap: widget.onTap,
                  onTapDown: (_) => _setDown(true),
                  onTapCancel: () => _setDown(false),
                  onTapUp: (_) => _setDown(false),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save_rounded, size: 18, color: icon),
                        const SizedBox(width: 8),
                        Text(
                          '저장하기',
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