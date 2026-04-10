// lib/card_picker.dart
import 'dart:math';

import 'package:flutter/material.dart';

import 'arcana/arcana_labels.dart';
import 'theme/app_theme.dart';

Color _a(Color c, double o) => c.withAlpha((o * 255).round());

const Color _bgTop = Color(0xFF1B132E);
const Color _bgMid = Color(0xFF3A2B5F);
const Color _bgBot = Color(0xFF5A3F86);

Color get _ink => _a(AppTheme.homeInkWarm, 0.96);
Color get _inkSub => _a(AppTheme.homeInkWarm, 0.72);

Color get _pickRing => _a(AppTheme.headerInk, 0.22);
Color get _pickRingStrong => _a(AppTheme.headerInk, 0.34);

Future<List<int>?> openCardPicker({
  required BuildContext context,
  required int maxPickCount,
  List<int> preselected = const [],
}) {
  return showDialog<List<int>>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _CardPickerDialog(
      maxPickCount: maxPickCount.clamp(1, 3),
      preselected: preselected,
    ),
  );
}

class _CardPickerDialog extends StatefulWidget {
  final int maxPickCount;
  final List<int> preselected;

  const _CardPickerDialog({
    required this.maxPickCount,
    required this.preselected,
  });

  @override
  State<_CardPickerDialog> createState() => _CardPickerDialogState();
}

class _CardPickerDialogState extends State<_CardPickerDialog>
    with SingleTickerProviderStateMixin {
  static const int _crossAxisCount = 4;
  static const double _gridPad = 14.0;
  static const double _gridGap = 10.0;
  static const double _cardAspect = 1 / 1.64;
  static const Duration _shuffleDuration = Duration(milliseconds: 720);

  final Random _rng = Random(DateTime.now().millisecondsSinceEpoch);

  late final List<int> _deck;
  late Map<int, int> _currentIndexMap;

  final List<int> _picked = [];
  final Set<int> _pickedSet = <int>{};

  late final AnimationController _shuffleC;
  late final Animation<double> _shuffleAnim;

  bool _isShuffling = false;

  Map<int, int>? _fromIndexById;
  Map<int, int>? _toIndexById;

  @override
  void initState() {
    super.initState();

    _deck = List<int>.generate(ArcanaLabels.kTarotFileNames.length, (i) => i)
      ..shuffle(_rng);
    _currentIndexMap = _indexMapFromDeck(_deck);

    for (final id in widget.preselected) {
      if (_picked.length >= widget.maxPickCount) break;
      if (id < 0 || id >= ArcanaLabels.kTarotFileNames.length) continue;
      if (_pickedSet.contains(id)) continue;

      _picked.add(id);
      _pickedSet.add(id);
    }

    _shuffleC = AnimationController(
      vsync: this,
      duration: _shuffleDuration,
    );

    _shuffleAnim = CurvedAnimation(
      parent: _shuffleC,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _shuffleC.dispose();
    super.dispose();
  }

  Widget _bg({required Widget child}) {
    return Container(
      color: const Color(0xFF2A1E44),
      child: child,
    );
  }

  bool _isPicked(int id) => _pickedSet.contains(id);

  void _select(int id) {
    if (_isShuffling) return;

    setState(() {
      if (_pickedSet.contains(id)) return;
      if (_picked.length >= widget.maxPickCount) return;

      _picked.add(id);
      _pickedSet.add(id);
    });
  }

  void _resetPicks() {
    if (_isShuffling) return;
    if (_picked.isEmpty) return;

    setState(() {
      _picked.clear();
      _pickedSet.clear();
    });
  }

  Map<int, int> _indexMapFromDeck(List<int> deck) {
    final map = <int, int>{};
    for (int i = 0; i < deck.length; i++) {
      map[deck[i]] = i;
    }
    return map;
  }

  Future<void> _shuffleDeck() async {
    if (_picked.isNotEmpty) return;
    if (_isShuffling || _shuffleC.isAnimating) return;

    final currentDeck = List<int>.from(_deck);
    final nextDeck = List<int>.from(_deck)..shuffle(_rng);

    final fromMap = _indexMapFromDeck(currentDeck);
    final toMap = _indexMapFromDeck(nextDeck);

    setState(() {
      _isShuffling = true;
      _picked.clear();
      _pickedSet.clear();
      _fromIndexById = fromMap;
      _toIndexById = toMap;

      _deck
        ..clear()
        ..addAll(nextDeck);

      _currentIndexMap = _indexMapFromDeck(_deck);
    });

    await _shuffleC.forward(from: 0);

    if (!mounted) return;
    setState(() {
      _isShuffling = false;
      _fromIndexById = null;
      _toIndexById = null;
    });
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  _CardLayout _layoutFor(double maxWidth) {
    final usableWidth = maxWidth - (_gridPad * 2);
    final cardWidth =
        (usableWidth - (_gridGap * (_crossAxisCount - 1))) / _crossAxisCount;
    final cardHeight = cardWidth / _cardAspect;
    final rowCount =
    (ArcanaLabels.kTarotFileNames.length / _crossAxisCount).ceil();
    final contentHeight =
        (rowCount * cardHeight) + ((rowCount - 1) * _gridGap) + (_gridPad * 2);

    return _CardLayout(
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      contentHeight: contentHeight,
    );
  }

  Offset _offsetForIndex(int index, _CardLayout layout) {
    final col = index % _crossAxisCount;
    final row = index ~/ _crossAxisCount;

    final left = _gridPad + (col * (layout.cardWidth + _gridGap));
    final top = _gridPad + (row * (layout.cardHeight + _gridGap));
    return Offset(left, top);
  }

  double _shuffleProgress(int id, double t) {
    final delay = (id % 9) * 0.018;
    if (t <= delay) return 0.0;
    return ((t - delay) / (1.0 - delay)).clamp(0.0, 1.0);
  }

  Offset _shufflePosition({
    required int id,
    required Offset from,
    required Offset to,
    required double t,
  }) {
    final p = Curves.easeInOutCubic.transform(_shuffleProgress(id, t));

    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final dist = sqrt((dx * dx) + (dy * dy));

    if (dist < 0.001) {
      return from;
    }

    final nx = -dy / dist;
    final ny = dx / dist;
    final dir = (id % 2 == 0) ? 1.0 : -1.0;

    final arcAmp = (dist * 0.16).clamp(10.0, 26.0) * dir;
    final arc = sin(pi * p) * arcAmp;
    final lift = -sin(pi * p) * (4.0 + (id % 3) * 1.5);

    return Offset(
      _lerp(from.dx, to.dx, p) + (nx * arc),
      _lerp(from.dy, to.dy, p) + (ny * arc) + lift,
    );
  }

  double _flowRot(int id, double t) {
    final p = _shuffleProgress(id, t);
    final phase = sin(pi * p);
    final dir = (id % 2 == 0) ? 1.0 : -1.0;
    return dir * (0.018 + (id % 4) * 0.004) * phase;
  }

  double _flowScale(double t) {
    return 1.0;
  }

  List<int> _paintOrderForBuild() {
    final ids = List<int>.from(_deck);

    if (!_isShuffling || _toIndexById == null) {
      return ids;
    }

    ids.sort((a, b) {
      final ai = _toIndexById![a] ?? 0;
      final bi = _toIndexById![b] ?? 0;
      return ai.compareTo(bi);
    });
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _picked.length == widget.maxPickCount;
    final hasPicked = _picked.isNotEmpty;
    final canShuffle = !_isShuffling && _picked.isEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: _bg(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A1E44),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _a(Colors.white, 0.12)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _TightIconButton(
                      icon: Icons.close,
                      color: _ink,
                      enabled: !_isShuffling,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "카드 선택",
                        style: AppTheme.title.copyWith(
                          fontSize: 18,
                          color: _ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    _HeaderActionButton(
                      label: '초기화',
                      enabled: hasPicked && !_isShuffling,
                      onTap: _resetPicks,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${_picked.length}/${widget.maxPickCount}",
                      style: AppTheme.uiSmallLabel.copyWith(
                        color: _inkSub,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _isShuffling
                        ? "카드를 섞는 중..."
                        : "카드를 선택해주세요",
                    style: AppTheme.uiSmallLabel.copyWith(
                      color: _a(AppTheme.headerInk, 0.62),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final layout = _layoutFor(constraints.maxWidth);
                    final ids = _paintOrderForBuild();

                    return Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: layout.contentHeight,
                          child: AnimatedBuilder(
                            animation: _shuffleAnim,
                            builder: (context, _) {
                              final t = _shuffleAnim.value;
                              final scale = _flowScale(t);

                              return Stack(
                                children: [
                                  for (final id in ids)
                                    _buildStackCard(
                                      id: id,
                                      layout: layout,
                                      t: t,
                                      scale: scale,
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                child: Row(
                  children: [
                    _BottomIconActionButton(
                      onTap: _shuffleDeck,
                      icon: Icons.all_inclusive,
                      enabled: canShuffle,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: (isComplete && !_isShuffling)
                              ? () => Navigator.pop(
                            context,
                            List<int>.from(_picked),
                          )
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            _a(Colors.white, isComplete ? 0.16 : 0.10),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: _a(Colors.white, 0.08),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: _a(Colors.white, 0.18)),
                            ),
                          ),
                          child: Text(
                            _isShuffling
                                ? "카드를 섞고 있어"
                                : isComplete
                                ? "선택 완료"
                                : "카드를 ${widget.maxPickCount}장 선택해주세요",
                            style: AppTheme.uiSmallLabel.copyWith(
                              color: _a(
                                _ink,
                                (isComplete && !_isShuffling) ? 0.98 : 0.55,
                              ),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStackCard({
    required int id,
    required _CardLayout layout,
    required double t,
    required double scale,
  }) {
    final fn = ArcanaLabels.kTarotFileNames[id];

    final picked = _isPicked(id);
    final limitReached = _picked.length >= widget.maxPickCount;
    final shouldLock = !_isShuffling && limitReached && !picked;

    final currentIndex = _currentIndexMap[id] ?? 0;
    final fromIndex = _fromIndexById?[id] ?? currentIndex;
    final toIndex = _toIndexById?[id] ?? currentIndex;

    final fromOffset = _offsetForIndex(fromIndex, layout);
    final toOffset = _offsetForIndex(toIndex, layout);

    final pos = _shufflePosition(
      id: id,
      from: fromOffset,
      to: toOffset,
      t: t,
    );

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: layout.cardWidth,
      height: layout.cardHeight,
      child: IgnorePointer(
        ignoring: _isShuffling,
        child: Transform.rotate(
          angle: _flowRot(id, t),
          child: Transform.scale(
            scale: scale,
            child: FlipTarotCard(
              key: ValueKey("card-$id"),
              frontImage: 'asset/cards/$fn',
              isLocked: shouldLock || _isShuffling,
              isFlipped: picked,
              orderBadge: picked ? (_picked.indexOf(id) + 1) : null,
              onFlippedToFront: () => _select(id),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardLayout {
  final double cardWidth;
  final double cardHeight;
  final double contentHeight;

  const _CardLayout({
    required this.cardWidth,
    required this.cardHeight,
    required this.contentHeight,
  });
}

class _HeaderActionButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _HeaderActionButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? _a(Colors.white, 0.10) : _a(Colors.white, 0.05);
    final border = enabled ? _a(Colors.white, 0.18) : _a(Colors.white, 0.08);
    final text =
    enabled ? _a(AppTheme.homeCream, 0.84) : _a(AppTheme.homeCream, 0.32);

    return SizedBox(
      height: 30,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: 1),
            ),
            child: Center(
              child: Text(
                label,
                style: AppTheme.uiSmallLabel.copyWith(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w900,
                  color: text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomIconActionButton extends StatelessWidget {
  final Future<void> Function() onTap;
  final IconData icon;
  final bool enabled;

  const _BottomIconActionButton({
    required this.onTap,
    required this.icon,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? _a(Colors.white, 0.10) : _a(Colors.white, 0.06);
    final border = enabled ? _a(Colors.white, 0.18) : _a(Colors.white, 0.08);
    final iconColor = enabled ? _a(_ink, 0.94) : _a(_ink, 0.34);

    return SizedBox(
      width: 46,
      height: 46,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => onTap() : null,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 1),
            ),
            child: Center(
              child: Icon(icon, size: 21, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _TightIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _TightIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: enabled ? onTap : null,
      radius: 22,
      splashColor: _a(Colors.white, 0.06),
      highlightColor: _a(Colors.white, 0.04),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Icon(
            icon,
            size: 22,
            color: enabled ? color : _a(color, 0.35),
          ),
        ),
      ),
    );
  }
}

class _PickerBackCard extends StatelessWidget {
  final bool dimmed;
  final bool highlighted;

  const _PickerBackCard({
    this.dimmed = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    const outerR = 7.0;
    const innerR = 5.6;

    const ivoryWarm = Color(0xFFF1E9DE);
    const top = Color(0xFF60407E);
    const bottom = Color(0xFF3F2A5B);

    final seamLine = _a(const Color(0xFF2A1636), 0.22);
    final star = _a(AppTheme.headerInk, 0.82);

    const framePad = 4.6;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outerR),
        border:
        highlighted ? Border.all(color: _pickRingStrong, width: 1.2) : null,
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.20),
            blurRadius: 18,
            offset: const Offset(0, 12),
            spreadRadius: -3,
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
                        _a(Colors.white, 0.26),
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
                        child: Icon(Icons.auto_awesome, size: 18, color: star),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(framePad - 0.8),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(innerR + 1.2),
                      border: Border.all(color: seamLine, width: 0.9),
                    ),
                  ),
                ),
              ),
            ),
            if (dimmed)
              Positioned.fill(
                child: Container(color: _a(Colors.black, 0.18)),
              ),
          ],
        ),
      ),
    );
  }
}

class FlipTarotCard extends StatefulWidget {
  final String frontImage;
  final bool isLocked;
  final bool isFlipped;
  final int? orderBadge;
  final VoidCallback onFlippedToFront;

  const FlipTarotCard({
    super.key,
    required this.frontImage,
    required this.onFlippedToFront,
    this.isLocked = false,
    this.isFlipped = false,
    this.orderBadge,
  });

  @override
  State<FlipTarotCard> createState() => _FlipTarotCardState();
}

class _FlipTarotCardState extends State<FlipTarotCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _anim = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.value = widget.isFlipped ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(covariant FlipTarotCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isFlipped != widget.isFlipped && !_controller.isAnimating) {
      _controller.value = widget.isFlipped ? 1.0 : 0.0;
    }
  }

  Future<void> _flipToFrontOnce() async {
    if (widget.isLocked) return;
    if (_controller.isAnimating) return;
    if (widget.isFlipped) return;

    await _controller.forward();
    widget.onFlippedToFront();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.orderBadge;
    const double cardR = 7;

    return GestureDetector(
      onTap: _flipToFrontOnce,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (context, child) {
              final angle = _anim.value;
              final showFront = angle > (pi / 2);
              final showPickBorder = widget.isLocked || badge != null;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(cardR),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform(
                        alignment: Alignment.center,
                        transform: showFront
                            ? (Matrix4.identity()..rotateY(pi))
                            : Matrix4.identity(),
                        child: showFront
                            ? Container(
                          color: _a(Colors.black, 0.08),
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: ClipRRect(
                              borderRadius:
                              BorderRadius.circular(cardR - 1),
                              child: Transform.scale(
                                scaleX: 1.06,
                                scaleY: 1.03,
                                child: Image.asset(
                                  widget.frontImage,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                          ),
                        )
                            : _PickerBackCard(
                          dimmed: widget.isLocked,
                          highlighted: badge != null,
                        ),
                      ),
                      if (showPickBorder)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(cardR),
                            border: Border.all(
                              color: _a(AppTheme.headerInk, 0.55),
                              width: 1.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (badge != null)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: _a(Colors.black, 0.40),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _pickRing, width: 1.0),
                ),
                child: Text(
                  "$badge",
                  style: AppTheme.uiSmallLabel.copyWith(
                    color: _a(AppTheme.homeInkWarm, 0.92),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}