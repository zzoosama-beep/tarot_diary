import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../ui/layout_tokens.dart';
import '../ui/app_toast.dart';
import '../arcana/arcana_labels.dart';
import '../backend/diary_repo.dart';
import '../error/app_error_dialog.dart';
import '../error/error_reporter.dart';

import '../ui/app_buttons.dart';
import '../diary/calander_diary.dart';

Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class WriteDiaryTwoPage extends StatefulWidget {
  final List<int> pickedCardIds; // 1~3장
  final int cardCount; // 1~3
  final DateTime? selectedDate;

  /// 기존 기록 있으면 불러온 텍스트(수정 모드 프리필)
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

  bool get _isBusy => _saving;
  bool get _canSave => !_isBusy;

  DateTime get _saveDate {
    final d = widget.selectedDate;
    if (d != null) return DateTime(d.year, d.month, d.day);

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  bool _hasText(String v) =>
      v.replaceAll(RegExp(r'[\s\u200B-\u200D\uFEFF]'), '').isNotEmpty;

  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg);
  }

  void _showErrorMessage(String msg) {
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

  String _buildAiPrompt() {
    final cc = widget.cardCount.clamp(1, 3);
    final cards = widget.pickedCardIds.take(cc).map(_cardKoName).join(', ');

    return [
      '당신은 타로 해석 전문가입니다.',
      '카드: $cards',
      '타로카드를 뽑아서 내일 하루의 흐름이 어떨지 미리 예상해볼 거예요.',
      '카드를 한장씩 해석하지 말고, 전체의 흐름으로 묶어서 자연스럽게 해석해주세요',
      '마지막 문장은 조언을 작성해주세요.',
    ].join('\n');
  }

  String _openChatGptErrorMessage() {
    return '챗지피티를 열지 못했습니다.\n잠시 후 다시 시도해주세요.';
  }

  String _openGeminiErrorMessage() {
    return '제미나이를 열지 못했습니다.\n잠시 후 다시 시도해주세요.';
  }

  String _saveDiaryErrorMessage() {
    return '기록을 저장하지 못했습니다.\n잠시 후 다시 시도해주세요.';
  }

  String _saveDiaryTimeoutMessage() {
    return '기록 저장이 지연되고 있습니다.\n기기 상태를 확인한 뒤 다시 시도해주세요.';
  }

  Future<void> _copyPromptOnly() async {
    final prompt = _buildAiPrompt();
    await Clipboard.setData(ClipboardData(text: prompt));
  }

  Future<bool> _openUri(
      Uri uri, {
        required String source,
        required Map<String, Object?> extra,
      }) async {
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: source,
        error: e,
        stackTrace: st,
        extra: {
          'uri': uri.toString(),
          ...extra,
        },
      );
      return false;
    }
  }

  Future<void> _askChatGPT() async {
    try {
      final prompt = _buildAiPrompt();
      final encoded = Uri.encodeComponent(prompt);

      await Clipboard.setData(ClipboardData(text: prompt));

      final ok = await _openUri(
        Uri.parse('https://chat.openai.com/?q=$encoded'),
        source: 'WriteDiaryTwoPage._askChatGPT.openUri',
        extra: {
          'cardCount': widget.cardCount,
          'pickedCount': widget.pickedCardIds.length,
        },
      );

      if (!mounted) return;

      if (ok) {
        _toast('프롬프트를 복사했고 챗지피티를 열었습니다.');
      } else {
        _toast('챗지피티를 열지 못했습니다.\n브라우저를 직접 열어 붙여넣어주세요.');
      }
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'WriteDiaryTwoPage._askChatGPT',
        error: e,
        stackTrace: st,
        extra: {
          'cardCount': widget.cardCount,
          'pickedCount': widget.pickedCardIds.length,
        },
      );

      if (!mounted) return;
      _showErrorMessage(_openChatGptErrorMessage());
    }
  }

  Future<void> _askGemini() async {
    try {
      await _copyPromptOnly();

      if (!mounted) return;

      _toast('프롬프트를 복사했습니다.\n제미나이에 붙여넣어주세요.');

      await Future.delayed(const Duration(milliseconds: 800));

      final candidates = <Uri>[
        Uri.parse('https://gemini.google.com/'),
        Uri.parse('https://gemini.google.com/app'),
        Uri.parse('https://www.google.com/'),
      ];

      bool opened = false;
      for (final uri in candidates) {
        opened = await _openUri(
          uri,
          source: 'WriteDiaryTwoPage._askGemini.openUri',
          extra: {
            'candidate': uri.toString(),
            'cardCount': widget.cardCount,
            'pickedCount': widget.pickedCardIds.length,
          },
        );
        if (opened) break;
      }

      if (!mounted) return;

      if (!opened) {
        _toast('제미나이를 열지 못했습니다.\n직접 열어서 붙여넣어주세요.');
      }
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'WriteDiaryTwoPage._askGemini',
        error: e,
        stackTrace: st,
        extra: {
          'cardCount': widget.cardCount,
          'pickedCount': widget.pickedCardIds.length,
        },
      );

      if (!mounted) return;
      _showErrorMessage(_openGeminiErrorMessage());
    }
  }

  Future<void> _onSave() async {
    if (_isBusy) return;

    final cc = widget.cardCount.clamp(1, 3);
    final cards = widget.pickedCardIds.take(cc).toList();
    if (cards.length != cc) {
      _toast('카드를 $cc장 모두 선택해주세요.');
      return;
    }

    final text = _c.text.trim();
    if (!_hasText(text)) {
      _toast('텍스트를 한 줄 이상 작성해주세요.');
      return;
    }

    setState(() => _saving = true);

    try {
      _toast('저장 중입니다…');

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

      _toast('저장이 완료되었습니다.');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => CalanderDiaryPage(
            selectedDate: _saveDate,
          ),
        ),
            (route) => route.isFirst,
      );
    } on TimeoutException catch (e, st) {
      await ErrorReporter.I.record(
        source: 'WriteDiaryTwoPage._onSave.TimeoutException',
        error: e,
        stackTrace: st,
        extra: {
          'saveDate': _saveDate.toIso8601String(),
          'cardCount': cc,
          'pickedCount': cards.length,
          'textLength': text.length,
        },
      );

      if (!mounted) return;
      _showErrorMessage(_saveDiaryTimeoutMessage());
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'WriteDiaryTwoPage._onSave',
        error: e,
        stackTrace: st,
        extra: {
          'saveDate': _saveDate.toIso8601String(),
          'cardCount': cc,
          'pickedCount': cards.length,
          'textLength': text.length,
        },
      );

      if (!mounted) return;
      _showErrorMessage(_saveDiaryErrorMessage());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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



  double _responsiveInputHeight({
    required double viewportHeight,
    required bool keyboardOpen,
  }) {
    final ratio = keyboardOpen ? 0.28 : 0.40;
    final minH = keyboardOpen ? 200.0 : 300.0;
    final maxH = keyboardOpen ? 300.0 : 480.0;
    return (viewportHeight * ratio).clamp(minH, maxH);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final keyboardInset = viewInsets.bottom;
    final keyboardOpen = keyboardInset > 0;

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

            final double sidePad = MediaQuery.of(context).size.width < 360
                ? 12
                : (MediaQuery.of(context).size.width < 430 ? 14 : 18);

            final contentW = LayoutTokens.contentW(context);
            final double btnW = math.min(contentW, 320.0);

            return SingleChildScrollView(
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                sidePad,
                LayoutTokens.scrollTopPad,
                sidePad,
                keyboardInset + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewportH,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Transform.translate(
                                offset: const Offset(LayoutTokens.backBtnNudgeX, 0),
                                child: AppPressButton(
                                  onTap: () {
                                    final nav = Navigator.of(context);
                                    if (nav.canPop()) {
                                      nav.pop();
                                    } else {
                                      nav.pushNamedAndRemoveUntil('/', (route) => false);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  normalColor: Colors.transparent,
                                  pressedColor: _a(Colors.white, 0.12),
                                  child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: Center(
                                      child: Icon(
                                        Icons.arrow_back_rounded,
                                        color: _a(AppTheme.homeInkWarm, 0.96),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '내일 타로일기 쓰기',
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AppTheme.title.copyWith(
                                  color: _a(AppTheme.homeInkWarm, 0.96),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Transform.translate(
                                offset: const Offset(4, 1),
                                child: AppHeaderHomeIconButton(
                                  onTap: () => Navigator.of(context)
                                      .pushNamedAndRemoveUntil('/', (r) => false),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PickedCardsRowLikeOne(
                      pickedIds: widget.pickedCardIds,
                      cardCount: widget.cardCount,
                    ),
                    const SizedBox(height: 18),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.center,
                      child: _AskAiSection(
                        onTapChatGPT: _askChatGPT,
                        onTapGemini: _askGemini,
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
                    SizedBox(height: keyboardOpen ? 14 : 22),
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
            );
          },
        ),
      ),
    );
  }
}

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

class _AskAiSection extends StatelessWidget {
  final VoidCallback onTapChatGPT;
  final VoidCallback onTapGemini;

  const _AskAiSection({
    required this.onTapChatGPT,
    required this.onTapGemini,
  });

  @override
  Widget build(BuildContext context) {
    final title = _a(AppTheme.homeInkWarm, 0.74);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'AI에게 물어보기 (프롬프트)',
          style: AppTheme.uiSmallLabel.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
            color: title,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            _AskButton(
              label: '챗지피티',
              onTap: onTapChatGPT,
            ),
            _AskButton(
              label: '제미나이',
              onTap: onTapGemini,
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _AskButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _AskButton({
    required this.label,
    required this.onTap,
  });

  @override
  State<_AskButton> createState() => _AskButtonState();
}

class _AskButtonState extends State<_AskButton> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    const r = 12.0;

    final normalFill = _a(Colors.white, 0.06);
    final pressedFill = _a(Colors.white, 0.11);

    final normalBorder = _a(Colors.white, 0.12);
    final pressedBorder = _a(Colors.white, 0.18);

    final fill = _down ? pressedFill : normalFill;
    final border = _down ? pressedBorder : normalBorder;
    final text = _a(AppTheme.homeInkWarm, 0.92);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setDown(true),
      onTapCancel: () => _setDown(false),
      onTapUp: (_) => _setDown(false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        scale: _down ? 0.97 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: border, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: _a(Colors.black, _down ? 0.025 : 0.05),
                blurRadius: _down ? 4 : 8,
                offset: Offset(0, _down ? 1 : 3),
                spreadRadius: -3,
              ),
            ],
          ),
          child: SizedBox(
            width: 112,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: AppTheme.uiSmallLabel.copyWith(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
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
          hintText:
          '내일의 감정, 예상되는 장면, 카드가 말해주는 흐름…\n여기에 기록해주세요.\n카드 뜻을 잘 모르겠다면 AI에게 물어보세요.',
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
    final pressedBase =
    enabled ? _a(const Color(0xFFFFF2E6), 0.88) : _a(Colors.white, 0.50);

    final border =
    enabled ? _a(AppTheme.headerInk, 0.18) : _a(AppTheme.panelBorder, 0.18);
    final pressedBorder =
    enabled ? _a(AppTheme.headerInk, 0.24) : _a(AppTheme.panelBorder, 0.18);

    final text = enabled
        ? _a(const Color(0xFF3A2147), 0.92)
        : _a(const Color(0xFF3A2147), 0.45);
    final icon = text;

    return AbsorbPointer(
      absorbing: !enabled,
      child: SizedBox(
        height: h,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? widget.onTap : null,
          onTapDown: enabled ? (_) => _setDown(true) : null,
          onTapCancel: enabled ? () => _setDown(false) : null,
          onTapUp: enabled ? (_) => _setDown(false) : null,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            scale: enabled && _down ? 0.97 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r),
                color: _down ? pressedBase : base,
                border: Border.all(
                  color: _down ? pressedBorder : border,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _a(Colors.black, enabled ? (_down ? 0.10 : 0.16) : 0.10),
                    blurRadius: enabled ? (_down ? 12 : 18) : 14,
                    offset: Offset(0, _down ? 6 : 10),
                    spreadRadius: -6,
                  ),
                ],
              ),
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
                      widget.busy ? '저장 중...' : '저장하기',
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
    );
  }
}