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

  /// ✅ 저장할 날짜 (안 넘기면 기본: 내일)
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

    // 기본값: "내일" (시간 00:00으로 통일)
    final now = DateTime.now();
    final tmr = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return tmr;
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

    // 카드 검증 (안전)
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

      await DiaryRepo.I.save(
        date: _saveDate,
        cardCount: cc,
        cards: cards,
        beforeText: text,
        afterText: '',
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
            const SizedBox(height: 14),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: contentW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PickedCardsStrip(
                        pickedIds: widget.pickedCardIds,
                        cardCount: widget.cardCount,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '카드 보면서 오늘의 느낌을 적어줘 ✨',
                        textAlign: TextAlign.center,
                        style: AppTheme.uiSmallLabel.copyWith(
                          fontSize: 12.4,
                          fontWeight: FontWeight.w800,
                          color: _a(AppTheme.homeInkWarm, 0.70),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _DiaryInputBox(
                          controller: _c,
                          focusNode: _focus,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SaveButton(
                        enabled: !_saving,
                        onTap: _onSave,
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
/// 선택한 카드 스트립(상단 고정)
/// ===============================
class _PickedCardsStrip extends StatelessWidget {
  final List<int> pickedIds;
  final int cardCount;

  const _PickedCardsStrip({
    required this.pickedIds,
    required this.cardCount,
  });

  @override
  Widget build(BuildContext context) {
    final w = LayoutTokens.contentW(context);

    const gap = 10.0;
    final c = cardCount.clamp(1, 3);

    const maxCardW = 86.0;
    final fitWFor3 = (w - (gap * 2)) / 3;
    final cardW = math.min(maxCardW, fitWFor3);
    final cardH = cardW * 1.55;

    return Center(
      child: SizedBox(
        width: (cardW * 3) + (gap * 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(c, (i) {
            final id = (i < pickedIds.length) ? pickedIds[i] : null;
            return Padding(
              padding: EdgeInsets.only(right: i == c - 1 ? 0 : gap),
              child: _SmallCardPreview(width: cardW, height: cardH, cardId: id),
            );
          }),
        ),
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
    const r = 10.0;

    final id = cardId;
    String? path;
    if (id != null && id >= 0 && id < ArcanaLabels.kTarotFileNames.length) {
      final fn = ArcanaLabels.kTarotFileNames[id];
      path = 'asset/cards/$fn';
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        color: _a(Colors.black, 0.06),
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.16),
            blurRadius: 18,
            offset: const Offset(0, 12),
            spreadRadius: -7,
          ),
          BoxShadow(
            color: _a(Colors.white, 0.12),
            blurRadius: 10,
            offset: const Offset(0, -6),
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: path == null
            ? Center(
          child: Icon(Icons.style_rounded, size: 18, color: _a(AppTheme.headerInk, 0.70)),
        )
            : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.2, vertical: 1.8),
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
/// 입력 박스
/// ===============================
class _DiaryInputBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const _DiaryInputBox({
    required this.controller,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final fill = _a(Colors.white, 0.78);
    final border = _a(AppTheme.panelBorder, 0.40);
    final hint = _a(const Color(0xFF3A2147), 0.42);
    final text = _a(const Color(0xFF3A2147), 0.88);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.12),
            blurRadius: 18,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: _a(Colors.white, 0.16),
            blurRadius: 10,
            offset: const Offset(0, -6),
            spreadRadius: -10,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: null,
        expands: true,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: AppTheme.uiSmallLabel.copyWith(
          fontSize: 14.2,
          height: 1.45,
          fontWeight: FontWeight.w800,
          color: text,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          hintText: '오늘의 감정, 떠오른 장면, 카드가 말해주는 것…\n짧게라도 좋아.',
          hintStyle: AppTheme.uiSmallLabel.copyWith(
            fontSize: 13.4,
            height: 1.4,
            fontWeight: FontWeight.w800,
            color: hint,
          ),
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

  const _SaveButton({
    required this.enabled,
    required this.onTap,
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

    final base = enabled ? _a(const Color(0xFFFFF2E6), 0.96) : _a(Colors.white, 0.55);
    final border = enabled ? _a(AppTheme.headerInk, 0.20) : _a(AppTheme.panelBorder, 0.22);
    final glow = enabled ? _a(AppTheme.headerInk, 0.20) : Colors.transparent;

    final text = enabled ? _a(const Color(0xFF3A2147), 0.92) : _a(const Color(0xFF3A2147), 0.45);
    final icon = enabled ? _a(AppTheme.headerInk, 0.78) : _a(AppTheme.headerInk, 0.38);

    return IgnorePointer(
      ignoring: !enabled,
      child: SizedBox(
        height: 54,
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
                  color: _a(Colors.black, enabled ? 0.20 : 0.10),
                  blurRadius: enabled ? 22 : 16,
                  offset: const Offset(0, 12),
                  spreadRadius: -2,
                ),
                if (enabled)
                  BoxShadow(
                    color: glow,
                    blurRadius: 28,
                    spreadRadius: -10,
                    offset: const Offset(0, 16),
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
