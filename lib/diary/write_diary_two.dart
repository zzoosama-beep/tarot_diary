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

Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class WriteDiaryTwoPage extends StatefulWidget {
  final List<int> pickedCardIds; // 1~3장
  final int cardCount; // 1~3
  final DateTime? selectedDate;

  const WriteDiaryTwoPage({
    super.key,
    required this.pickedCardIds,
    required this.cardCount,
    this.selectedDate,
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
    if (d != null) return d;

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

  @override
  Widget build(BuildContext context) {
    final contentW = LayoutTokens.contentW(context);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            _HeaderBar(
              title: '일기 쓰기',
              onBack: () => Navigator.of(context).maybePop(),
            ),

            // ✅ 카드가 센터로 내려오게
            const SizedBox(height: 26),

            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: contentW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ✅ 카드 크기 키움 + 전단계 느낌 유지(부채꼴X, 정렬만 살짝 깨기)
                      _PickedCardsStaggered(
                        pickedIds: widget.pickedCardIds,
                        cardCount: widget.cardCount,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        '카드 보면서 오늘의 느낌을 적어줘 ✨',
                        textAlign: TextAlign.center,
                        style: AppTheme.uiSmallLabel.copyWith(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w900,
                          color: _a(AppTheme.homeInkWarm, 0.70),
                          height: 1.35,
                        ),
                      ),

                      const SizedBox(height: 10),

                      _DiaryInputTransparent(
                        controller: _c,
                        focusNode: _focus,
                        maxHeight: 180,
                        showLine: true,
                      ),

                      const SizedBox(height: 14),

                      _SaveButton(
                        enabled: !_saving,
                        onTap: _onSave,
                        compact: true,
                      ),

                      const SizedBox(height: 14),
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
/// ✅ 카드 배치 (부채꼴 X)
/// - "가로 일렬" 유지
/// - 각 카드: 아주 약한 rotation + y오프셋으로 정렬만 살짝 깨기
/// - ✅ 카드 크기 업: maxCardW 86 -> 104 (체감 확 커짐)
/// ===============================
class _PickedCardsStaggered extends StatelessWidget {
  final List<int> pickedIds;
  final int cardCount;

  const _PickedCardsStaggered({
    required this.pickedIds,
    required this.cardCount,
  });

  @override
  Widget build(BuildContext context) {
    final w = LayoutTokens.contentW(context);
    final c = cardCount.clamp(1, 3);

    const gap = 10.0;

    // ✅ 여기만 조절하면 됨: 카드 "기준 크기"
    const maxCardW = 104.0;

    final fitWFor3 = (w - (gap * 2)) / 3;
    final cardW = math.min(maxCardW, fitWFor3);
    final cardH = cardW * 1.55;

    const rots = <double>[-0.03, 0.0, 0.03]; // rad (약하게)
    const dy = <double>[6, 0, 6];

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(c, (i) {
          final id = (i < pickedIds.length) ? pickedIds[i] : null;
          return Padding(
            padding: EdgeInsets.only(right: i == c - 1 ? 0 : gap),
            child: Transform.translate(
              offset: Offset(0, dy[i]),
              child: Transform.rotate(
                angle: rots[i],
                child: _SmallCardPreview(
                  width: cardW,
                  height: cardH,
                  cardId: id,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SmallCardPreview extends StatelessWidget {
  final double width;
  final double height;
  final int? cardId;

  const _SmallCardPreview({
    required this.width,
    required this.height,
    required this.cardId,
  });

  @override
  Widget build(BuildContext context) {
    const r = 12.0;

    final id = cardId;
    String? path;
    if (id != null && id >= 0 && id < ArcanaLabels.kTarotFileNames.length) {
      final fn = ArcanaLabels.kTarotFileNames[id];
      path = 'asset/cards/$fn';
    }

    final bg = _a(Colors.black, 0.045);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        color: bg,
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.14),
            blurRadius: 18,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: _a(Colors.white, 0.10),
            blurRadius: 10,
            offset: const Offset(0, -6),
            spreadRadius: -10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: path == null
            ? Center(
          child: Icon(Icons.style_rounded,
              size: 18, color: _a(AppTheme.headerInk, 0.70)),
        )
            : Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 2.2, vertical: 1.8),
          child: Transform.scale(
            scaleX: 1.05,
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
    );
  }
}

/// ===============================
/// ✅ 입력 박스 (진짜 투명)
/// ===============================
class _DiaryInputTransparent extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final double maxHeight;
  final bool showLine;

  const _DiaryInputTransparent({
    required this.controller,
    required this.focusNode,
    this.maxHeight = 180,
    this.showLine = true,
  });

  @override
  State<_DiaryInputTransparent> createState() => _DiaryInputTransparentState();
}

class _DiaryInputTransparentState extends State<_DiaryInputTransparent> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
    _focused = widget.focusNode.hasFocus;
  }

  void _onFocus() {
    if (!mounted) return;
    setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint = _a(AppTheme.homeInkWarm, 0.40);
    final text = _a(AppTheme.homeInkWarm, 0.92);
    final cursor = _a(AppTheme.homeInkWarm, 0.72);
    final line = _a(Colors.white, _focused ? 0.18 : 0.10);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                cursorColor: cursor,
                maxLines: null,
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
                  hintText: '오늘의 감정, 떠오른 장면, 카드가 말해주는 것…\n짧게라도 좋아.',
                  hintStyle: AppTheme.uiSmallLabel.copyWith(
                    fontSize: 13.2,
                    height: 1.5,
                    fontWeight: FontWeight.w800,
                    color: hint,
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                ),
              ),
            ),
          ),
          if (widget.showLine)
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 1,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
        ],
      ),
    );
  }
}

/// ===============================
/// 저장 버튼 (기존 유지)
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
    final h = widget.compact ? 52.0 : 54.0;

    final base =
    enabled ? _a(const Color(0xFFFFF2E6), 0.94) : _a(Colors.white, 0.50);
    final border = enabled
        ? _a(AppTheme.headerInk, 0.18)
        : _a(AppTheme.panelBorder, 0.18);

    final text = enabled
        ? _a(const Color(0xFF3A2147), 0.92)
        : _a(const Color(0xFF3A2147), 0.45);
    final icon =
    enabled ? _a(AppTheme.headerInk, 0.76) : _a(AppTheme.headerInk, 0.38);

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
              borderRadius: BorderRadius.circular(18),
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
              borderRadius: BorderRadius.circular(18),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
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