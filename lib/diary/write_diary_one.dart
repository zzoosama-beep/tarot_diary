// lib/diary/write_diary_one.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cardpicker.dart' as cp;

import '../theme/app_theme.dart';
import '../ui/layout_tokens.dart';
import '../arcana/arcana_labels.dart';

// ✅ 다음 화면
import 'write_diary_two.dart';

Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class WriteDiaryOnePage extends StatefulWidget {
  const WriteDiaryOnePage({super.key});

  @override
  State<WriteDiaryOnePage> createState() => _WriteDiaryOnePageState();
}

class _WriteDiaryOnePageState extends State<WriteDiaryOnePage> {
  int _cardCount = 1;

  /// 슬롯(0~2)에 배정된 실제 카드 id(0~77) / null이면 아직 안뽑힘
  final List<int?> _slotCardIds = <int?>[null, null, null];

  /// 뒤집힘 상태는 "슬롯 index" 기준 (한 번 뒤집히면 고정)
  final Set<int> _flipped = <int>{};

  /// ✅ 덱 중복 방지: 현재 화면에서 이미 사용된 카드 id들
  final Set<int> _usedIds = <int>{};

  final math.Random _rng = math.Random();

  bool get _hasAnyCard => _slotCardIds.any((e) => e != null);

  /// ✅ (핵심) 1~_cardCount 슬롯이 모두 "뽑힘 + 뒤집힘"이면 완료
  bool get _isSelectionComplete {
    for (int i = 0; i < _cardCount; i++) {
      if (_slotCardIds[i] == null) return false;
      if (!_flipped.contains(i)) return false;
    }
    return true;
  }

  /// ✅ 완료된 카드 id 리스트(1~3장)
  List<int> get _pickedIds {
    final out = <int>[];
    for (int i = 0; i < _cardCount; i++) {
      final id = _slotCardIds[i];
      if (id != null) out.add(id);
    }
    return out;
  }

  // -----------------------
  // 공용: 슬롯 기준으로 usedIds 재구성
  // -----------------------
  void _rebuildUsedFromSlots() {
    _usedIds
      ..clear()
      ..addAll(_slotCardIds.whereType<int>());
  }

  // -----------------------
  // 공용: 전체 리셋
  // -----------------------
  void _resetAll() {
    _flipped.clear();
    for (int i = 0; i < 3; i++) {
      _slotCardIds[i] = null;
    }
    _usedIds.clear();
  }

  // -----------------------
  // ✅ 다시뽑기(우상단 버튼)
  // -----------------------
  Future<void> _onResetCards() async {
    if (!_hasAnyCard) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _a(const Color(0xFF1E1330), 0.92),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '다시 뽑을까요?',
            style: TextStyle(
              color: _a(Colors.white, 0.92),
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            '지금 뽑은 카드를 모두 초기화하고\n새로 뽑을 수 있어요.',
            style: TextStyle(
              color: _a(Colors.white, 0.78),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                '취소',
                style: TextStyle(color: _a(Colors.white, 0.72)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                '다시 뽑기',
                style: TextStyle(color: _a(const Color(0xFFFFF2E6), 0.95)),
              ),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    setState(_resetAll);
  }

  // -----------------------
  // 1/2/3 변경: 무조건 초기화
  // -----------------------
  void _onChangeCount(int v) {
    final next = v.clamp(1, 3);
    if (next == _cardCount) return;
    setState(() {
      _cardCount = next;
      _resetAll();
    });
  }

  // -----------------------
  // ✅ 중복 없이 한 장 뽑기
  // -----------------------
  int? _drawUniqueId() {
    final total = ArcanaLabels.kTarotFileNames.length;
    if (total <= 0) return null;
    if (_usedIds.length >= total) return null;

    for (int tries = 0; tries < 200; tries++) {
      final id = _rng.nextInt(total);
      if (_usedIds.add(id)) return id;
    }
    for (int id = 0; id < total; id++) {
      if (_usedIds.add(id)) return id;
    }
    return null;
  }

  // -----------------------
  // ✅ 자동: 카드 탭하면 즉시 뽑고 즉시 뒤집힘 (중복 금지)
  // -----------------------
  void _onTapCard(int index) async {
    if (index >= _cardCount) return;
    if (_flipped.contains(index)) return;

    _rebuildUsedFromSlots();

    final id = _drawUniqueId();
    if (id == null) return;

    setState(() {
      _slotCardIds[index] = id;
    });

    await Future.delayed(const Duration(milliseconds: 40));
    if (!mounted) return;

    setState(() {
      _flipped.add(index);
    });
  }

  // -----------------------
  // ✅ 수동: picker 열기
  // -----------------------
  Future<void> _onManualPickCards() async {
    final picked = await cp.openCardPicker(
      context: context,
      maxPickCount: _cardCount,
      preselected: const <int>[],
    );

    if (!mounted) return;
    if (picked == null) return;

    final uniq = <int>[];
    final seen = <int>{};
    for (final id in picked) {
      if (id < 0 || id >= ArcanaLabels.kTarotFileNames.length) continue;
      if (seen.add(id)) uniq.add(id);
      if (uniq.length >= _cardCount) break;
    }
    if (uniq.isEmpty) return;

    setState(() {
      _resetAll();
      for (int i = 0; i < uniq.length && i < _cardCount; i++) {
        _slotCardIds[i] = uniq[i];
      }
      _rebuildUsedFromSlots();
    });

    await Future.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;

    setState(() {
      _flipped.addAll(List<int>.generate(_cardCount, (i) => i));
    });
  }

  void _goToWriteTwo() {
    if (!_isSelectionComplete) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WriteDiaryTwoPage(
          pickedCardIds: _pickedIds,
          cardCount: _cardCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = 12.0;
    const targetW = 82.0;
    final rowMaxW = math.min(
      LayoutTokens.contentW(context),
      (targetW * 3) + (gap * 2),
    );

    final contentW = LayoutTokens.contentW(context);

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
                    children: [
                      const SizedBox(height: 34),

                      _BackCardRow(
                        count: _cardCount,
                        flipped: _flipped,
                        slotCardIds: _slotCardIds,
                        onTapCard: _onTapCard,
                        showReset: _hasAnyCard,
                        onReset: _onResetCards,
                      ),

                      const SizedBox(height: 26),
                      Text(
                        '카드를 탭하면 자동으로 펼쳐져 ✨\n직접 뽑고 싶으면 아래 버튼을 눌러줘',
                        textAlign: TextAlign.center,
                        style: AppTheme.uiSmallLabel.copyWith(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w800,
                          color: _a(AppTheme.homeInkWarm, 0.70),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _CountChips(
                        value: _cardCount,
                        onChanged: _onChangeCount,
                      ),
                      const SizedBox(height: 18),

                      // ✅ 메인 CTA(1개만): 직접 카드 뽑기
                      SizedBox(
                        width: rowMaxW,
                        child: _RitualCtaButton(
                          label: '직접 카드 뽑기',
                          onTap: _onManualPickCards,
                          height: 46, // ✅ 낮춤
                          compact: true,
                        ),
                      ),

                      // ✅ 보조 액션: 작은 + 칩 + 멘트 (CTA처럼 안 보이게)
                      const SizedBox(height: 14),
                      SizedBox(
                        width: rowMaxW,
                        child: Center(
                          child: _PlusWriteInlineAction(
                            enabled: _isSelectionComplete,
                            onTap: _goToWriteTwo,
                            label: '이 카드로 내일 일기 쓰기',
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),
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
/// 카드 Row (1~3장) + 우상단 다시뽑기
/// ===============================
class _BackCardRow extends StatelessWidget {
  final int count;
  final Set<int> flipped;
  final List<int?> slotCardIds;
  final void Function(int index) onTapCard;

  final bool showReset;
  final VoidCallback onReset;

  const _BackCardRow({
    required this.count,
    required this.flipped,
    required this.slotCardIds,
    required this.onTapCard,
    required this.showReset,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final w = LayoutTokens.contentW(context);
    const gap = 12.0;
    final c = count.clamp(1, 3);

    // ✅ 항상 "3장" 기준으로 폭 계산
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

    // Row 자체 폭(카드 3장 기준)으로 Stack을 잡아서 우상단 버튼 위치 안정화
    final rowWFor3 = (cardW * 3) + (gap * 2);

    return SizedBox(
      width: rowWFor3,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(c, (i) {
              final isFlipped = flipped.contains(i);
              final int? cardId = (i < slotCardIds.length) ? slotCardIds[i] : null;

              return Padding(
                padding: EdgeInsets.only(right: i == c - 1 ? 0 : gap),
                child: Transform.translate(
                  offset: Offset(0, yOffsetFor(i)),
                  child: _FlipCard(
                    key: ValueKey('slot-$i-${cardId ?? "null"}'),
                    width: cardW,
                    height: cardH,
                    flipped: isFlipped,
                    front: _TarotFrontCard(width: cardW, height: cardH, cardId: cardId),
                    back: _TarotBackCard(width: cardW, height: cardH),
                    onTap: () => onTapCard(i),
                  ),
                ),
              );
            }),
          ),
          if (showReset)
            Positioned(
              top: -10,
              right: -10,
              child: _MiniResetButton(onTap: onReset),
            ),
        ],
      ),
    );
  }
}

/// 우상단 미니 다시뽑기 버튼
class _MiniResetButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MiniResetButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = _a(Colors.black, 0.22);
    final border = _a(Colors.white, 0.28);
    final icon = _a(Colors.white, 0.90);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: _a(Colors.black, 0.18),
                blurRadius: 14,
                offset: const Offset(0, 8),
                spreadRadius: -6,
              ),
            ],
          ),
          child: Center(
            child: Icon(Icons.refresh_rounded, size: 18, color: icon),
          ),
        ),
      ),
    );
  }
}

/// ===============================
/// ✅ 보조 액션: 작은 + 칩 + 멘트
/// ===============================
class _PlusWriteInlineAction extends StatefulWidget {
  final bool enabled;
  final VoidCallback onTap;
  final String label;

  const _PlusWriteInlineAction({
    required this.enabled,
    required this.onTap,
    required this.label,
  });

  @override
  State<_PlusWriteInlineAction> createState() => _PlusWriteInlineActionState();
}

class _PlusWriteInlineActionState extends State<_PlusWriteInlineAction> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;

    // ✅ +가 확실히 보이게 대비를 강하게
    final chipBg = enabled ? _a(const Color(0xFFFFF2E6), 0.92) : _a(Colors.white, 0.34);
    final chipBorder = enabled ? _a(AppTheme.headerInk, 0.24) : _a(AppTheme.panelBorder, 0.18);
    final plus = enabled ? _a(AppTheme.headerInk, 0.95) : _a(AppTheme.headerInk, 0.40);

    // ✅ 텍스트는 "버튼" 말고 "서브 액션" 톤
    final text = enabled ? _a(const Color(0xFFFFF2E6), 0.92) : _a(const Color(0xFFFFF2E6), 0.45);

    return IgnorePointer(
      ignoring: !enabled,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        scale: _down ? 0.985 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(999),
            onTapDown: (_) => _setDown(true),
            onTapCancel: () => _setDown(false),
            onTapUp: (_) => _setDown(false),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ 너무 크지 않게 30px
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: chipBg,
                      border: Border.all(color: chipBorder, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: _a(Colors.black, enabled ? 0.12 : 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 8),
                          spreadRadius: -8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(Icons.add_rounded, size: 20, color: plus),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: AppTheme.uiSmallLabel.copyWith(
                      fontSize: 13.4,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      color: text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ===============================
/// ✅ Flip + Press 애니메이션
/// ===============================
class _FlipCard extends StatefulWidget {
  final double width;
  final double height;
  final bool flipped;
  final Widget front;
  final Widget back;
  final VoidCallback onTap;

  const _FlipCard({
    super.key,
    required this.width,
    required this.height,
    required this.flipped,
    required this.front,
    required this.back,
    required this.onTap,
  });

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard> with TickerProviderStateMixin {
  late final AnimationController _flipC;
  late final AnimationController _pressC;

  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();

    _flipC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: widget.flipped ? 1.0 : 0.0,
    );

    _pressC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      value: 0.0,
    );

    _pressScale = Tween<double>(begin: 1.0, end: 0.985).animate(
      CurvedAnimation(parent: _pressC, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant _FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flipped == widget.flipped) return;

    if (widget.flipped) {
      _flipC.animateTo(1.0, curve: Curves.easeInOutCubic);
    } else {
      _flipC.animateTo(0.0, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    _flipC.dispose();
    _pressC.dispose();
    super.dispose();
  }

  void _tapDown(TapDownDetails _) => _pressC.forward();
  void _tapCancel() => _pressC.reverse();
  void _tapUp(TapUpDetails _) {
    _pressC.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    const cardR = 10.0;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: _tapDown,
        onTapUp: _tapUp,
        onTapCancel: _tapCancel,
        child: AnimatedBuilder(
          animation: Listenable.merge([_flipC, _pressC]),
          builder: (context, _) {
            final t = _flipC.value;
            final angle = t * math.pi;
            final showFront = angle > (math.pi / 2);

            final slide = math.sin(t * math.pi) * 6.0;

            final m = Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle);

            Widget child = showFront ? widget.front : widget.back;
            if (showFront) {
              child = Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..rotateY(math.pi),
                child: child,
              );
            }

            final scale = _pressScale.value;

            return Transform.translate(
              offset: Offset(slide, 0),
              child: Transform.scale(
                scale: scale,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(cardR),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: m,
                    child: child,
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
/// 카드 뒷면
/// ===============================
class _TarotBackCard extends StatelessWidget {
  final double width;
  final double height;

  const _TarotBackCard({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    const outerR = 9.0;
    const innerR = 7.0;

    const ivoryWarm = Color(0xFFF1E9DE);
    const top = Color(0xFF60407E);
    const bottom = Color(0xFF3F2A5B);

    final seamLine = _a(const Color(0xFF2A1636), 0.22);
    final star = _a(AppTheme.headerInk, 0.82);

    const framePad = 6.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outerR),
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.22),
            blurRadius: 22,
            offset: const Offset(0, 16),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: _a(Colors.white, 0.10),
            blurRadius: 10,
            offset: const Offset(0, -6),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(outerR),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ivoryWarm,
                  borderRadius: BorderRadius.circular(outerR),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.25, -0.35),
                      radius: 1.2,
                      colors: [
                        _a(Colors.white, 0.28),
                        _a(Colors.white, 0.0),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(framePad),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(innerR),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [top, bottom],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _a(Colors.black, 0.04),
                                  Colors.transparent,
                                  _a(const Color(0xFF20152E), 0.12),
                                ],
                                stops: const [0.0, 0.64, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Icon(Icons.auto_awesome, size: 20, color: star),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(framePad - 0.9),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(innerR + 1.2),
                      border: Border.all(color: seamLine, width: 0.9),
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

/// ===============================
/// 카드 앞면: 카드 id가 있으면 실제 이미지
/// ===============================
class _TarotFrontCard extends StatelessWidget {
  final double width;
  final double height;
  final int? cardId;

  const _TarotFrontCard({
    required this.width,
    required this.height,
    this.cardId,
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
/// 1/2/3 칩
/// ===============================
class _CountChips extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _CountChips({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedFill = _a(const Color(0xFFFFF2E6), 0.95);
    final selectedText = _a(const Color(0xFF3A2147), 0.92);
    final unselectedFill = _a(Colors.white, 0.78);
    final unselectedText = _a(const Color(0xFF3A2147), 0.70);

    const size = 52.0;

    Widget chip(int v) {
      final selected = value == v;

      return InkWell(
        onTap: () => onChanged(v),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? selectedFill : unselectedFill,
            border: selected
                ? Border.all(color: _a(AppTheme.headerInk, 0.20), width: 1.0)
                : Border.all(color: _a(AppTheme.panelBorder, 0.35), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: _a(Colors.white, selected ? 0.24 : 0.18),
                blurRadius: 10,
                spreadRadius: -6,
                offset: const Offset(0, -6),
              ),
              BoxShadow(
                color: _a(Colors.black, selected ? 0.18 : 0.12),
                blurRadius: selected ? 18 : 14,
                offset: const Offset(0, 12),
                spreadRadius: -2,
              ),
              if (selected)
                BoxShadow(
                  color: _a(AppTheme.headerInk, 0.18),
                  blurRadius: 20,
                  spreadRadius: -10,
                  offset: const Offset(0, 14),
                ),
            ],
          ),
          child: Center(
            child: Text(
              '${v}장',
              style: AppTheme.uiSmallLabel.copyWith(
                fontSize: 13.0,
                fontWeight: FontWeight.w900,
                color: selected ? selectedText : unselectedText,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        chip(1),
        const SizedBox(width: 12),
        chip(2),
        const SizedBox(width: 12),
        chip(3),
      ],
    );
  }
}

/// ===============================
/// 메인 CTA: 직접 카드 뽑기
/// ===============================
class _RitualCtaButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final double height;
  final bool compact;

  const _RitualCtaButton({
    required this.label,
    required this.onTap,
    this.height = 54,
    this.compact = false,
  });

  @override
  State<_RitualCtaButton> createState() => _RitualCtaButtonState();
}

class _RitualCtaButtonState extends State<_RitualCtaButton> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final base = _a(const Color(0xFFFFF2E6), 0.96);
    final glow = _a(AppTheme.headerInk, 0.20);
    final border = _a(AppTheme.headerInk, 0.20);

    final text = _a(const Color(0xFF3A2147), 0.92);
    final icon = _a(AppTheme.headerInk, 0.78);

    final h = widget.height;
    final iconSize = widget.compact ? 17.0 : 18.0;
    final fontSize = widget.compact ? 13.8 : 14.4;
    final radius = widget.compact ? 16.0 : 18.0;

    return SizedBox(
      height: h,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        scale: _down ? 0.985 : 1.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: base,
            border: Border.all(color: border, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: _a(Colors.black, 0.18),
                blurRadius: 20,
                offset: const Offset(0, 12),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: glow,
                blurRadius: 26,
                spreadRadius: -10,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: widget.onTap,
                onTapDown: (_) => _setDown(true),
                onTapCancel: () => _setDown(false),
                onTapUp: (_) => _setDown(false),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: iconSize, color: icon),
                      const SizedBox(width: 8),
                      Text(
                        widget.label,
                        style: AppTheme.uiSmallLabel.copyWith(
                          fontSize: fontSize,
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
    );
  }
}