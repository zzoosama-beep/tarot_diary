import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../ui/layout_tokens.dart';
import '../ui/app_toast.dart';
import '../ui/app_buttons.dart';
import '../arcana/arcana_labels.dart';
import '../backend/diary_repo.dart';
import '../error/app_error_dialog.dart';
import '../error/error_reporter.dart';

Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class EditDiaryPage extends StatefulWidget {
  final List<int> pickedCardIds; // 1~3장
  final int cardCount; // 1~3
  final DateTime? selectedDate;

  final String? initialBeforeText;
  final String? initialAfterText;
  final bool initialShowBeforeTab;

  const EditDiaryPage({
    super.key,
    required this.pickedCardIds,
    required this.cardCount,
    this.selectedDate,
    this.initialBeforeText,
    this.initialAfterText,
    this.initialShowBeforeTab = true,
  });

  @override
  State<EditDiaryPage> createState() => _EditDiaryPageState();
}

class _EditDiaryPageState extends State<EditDiaryPage> {
  final TextEditingController _beforeCtrl = TextEditingController();
  final TextEditingController _afterCtrl = TextEditingController();

  final FocusNode _beforeFocus = FocusNode();
  final FocusNode _afterFocus = FocusNode();

  bool _saving = false;
  bool _showBeforeTab = true;

  bool get _isBusy => _saving;
  bool get _canSave => !_isBusy;

  DateTime get _saveDate {
    final d = widget.selectedDate;
    if (d != null) return DateTime(d.year, d.month, d.day);

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  bool get _canWriteAfter {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = _saveDate;
    return !d.isAfter(today);
  }

  FocusNode get _activeFocus => _showBeforeTab ? _beforeFocus : _afterFocus;

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

  Future<void> _copyPromptOnly() async {
    final prompt = _buildAiPrompt();
    await Clipboard.setData(ClipboardData(text: prompt));
  }

  Future<bool> _openUri(Uri uri) async {
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'EditDiaryPage._openUri',
        error: e,
        stackTrace: st,
        extra: {
          'uri': uri.toString(),
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
      );

      if (!mounted) return;

      if (ok) {
        _toast('프롬프트를 복사했고 챗지피티를 열었습니다.');
      } else {
        _toast('챗지피티를 열지 못했습니다.\n브라우저를 직접 열어 붙여넣어주세요.');
      }
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'EditDiaryPage._askChatGPT',
        error: e,
        stackTrace: st,
      );

      if (!mounted) return;
      _showErrorMessage('챗지피티를 여는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.');
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
        opened = await _openUri(uri);
        if (opened) break;
      }

      if (!mounted) return;

      if (!opened) {
        _toast('제미나이를 열지 못했습니다.\n직접 열어서 붙여넣어주세요.');
      }
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'EditDiaryPage._askGemini',
        error: e,
        stackTrace: st,
      );

      if (!mounted) return;
      _showErrorMessage('제미나이를 여는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.');
    }
  }

  @override
  void initState() {
    super.initState();

    final before = widget.initialBeforeText;
    if (before != null && before.trim().isNotEmpty) {
      _beforeCtrl.text = before;
      _beforeCtrl.selection =
          TextSelection.collapsed(offset: _beforeCtrl.text.length);
    }

    final after = widget.initialAfterText;
    if (after != null && after.trim().isNotEmpty) {
      _afterCtrl.text = after;
      _afterCtrl.selection =
          TextSelection.collapsed(offset: _afterCtrl.text.length);
    }

    _showBeforeTab = widget.initialShowBeforeTab;

    if (!_showBeforeTab && !_canWriteAfter) {
      _showBeforeTab = true;
    }
  }

  @override
  void dispose() {
    _beforeCtrl.dispose();
    _afterCtrl.dispose();
    _beforeFocus.dispose();
    _afterFocus.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_isBusy) return;

    final cc = widget.cardCount.clamp(1, 3);
    final cards = widget.pickedCardIds.take(cc).toList();
    if (cards.length != cc) {
      _toast('카드를 $cc장 모두 선택해주세요.');
      return;
    }

    final beforeText = _beforeCtrl.text.trim();
    final afterText = _afterCtrl.text.trim();

    if (!_hasText(beforeText) && !(_canWriteAfter && _hasText(afterText))) {
      _toast('예상이나 실제 중 하나는 작성해주세요.');
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
        beforeText: beforeText,
        afterText: _canWriteAfter ? afterText : '',
      )
          .timeout(const Duration(seconds: 2));

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on TimeoutException catch (e, st) {
      await ErrorReporter.I.record(
        source: 'EditDiaryPage._onSave.TimeoutException',
        error: e,
        stackTrace: st,
        extra: {
          'saveDate': _saveDate.toIso8601String(),
          'cardCount': cc,
        },
      );

      if (!mounted) return;
      _toast('저장이 오래 걸려 중단되었습니다.\n기기 저장소 상태를 확인한 뒤 다시 시도해주세요.');
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'EditDiaryPage._onSave',
        error: e,
        stackTrace: st,
        extra: {
          'saveDate': _saveDate.toIso8601String(),
          'cardCount': cc,
        },
      );

      if (!mounted) return;
      _showErrorMessage('일기를 저장하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                constraints: BoxConstraints(minHeight: viewportH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TopBox(
                      left: Transform.translate(
                        offset: const Offset(LayoutTokens.backBtnNudgeX - 8, 0),
                        child: AppPressButton(
                          onTap: () => Navigator.of(context).maybePop(),
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
                      title: Text(
                        '내일 타로일기 수정',
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.title.copyWith(
                          color: _a(AppTheme.homeInkWarm, 0.96),
                        ),
                      ),
                      right: AppHeaderHomeButton(
                        onTap: () => Navigator.of(context)
                            .pushNamedAndRemoveUntil('/', (r) => false),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _PickedCardsRowLikeOne(
                      pickedIds: widget.pickedCardIds,
                      cardCount: widget.cardCount,
                    ),

                    const SizedBox(height: 18),

                    Align(
                      alignment: Alignment.center,
                      child: _AskAiSection(
                        onTapChatGPT: _askChatGPT,
                        onTapGemini: _askGemini,
                      ),
                    ),

                    const SizedBox(height: 20),

                    _FolderIndexTabs(
                      showBefore: _showBeforeTab,
                      canWriteAfter: _canWriteAfter,
                      onTapBefore: () {
                        if (_showBeforeTab) return;
                        setState(() => _showBeforeTab = true);
                      },
                      onTapAfter: () {
                        if (!_canWriteAfter) {
                          _toast('해당 날짜가 되어야 실제 기록을 열 수 있습니다.');
                          return;
                        }
                        if (!_showBeforeTab) return;
                        setState(() => _showBeforeTab = false);
                      },
                    ),

                    _TopContentLine(),

                    SizedBox(
                      height: inputH,
                      child: _DiaryInputTransparent(
                        controller:
                        _showBeforeTab ? _beforeCtrl : _afterCtrl,
                        focusNode:
                        _showBeforeTab ? _beforeFocus : _afterFocus,
                        enabled: _showBeforeTab ? true : _canWriteAfter,
                        locked: _showBeforeTab ? false : !_canWriteAfter,
                        hintText: _showBeforeTab
                            ? '내일의 감정, 예상되는 장면, 카드가 말해주는 흐름…\n여기에 기록해주세요.\n카드뜻을 잘 모르겠으면 AI에게 물어보세요!'
                            : (_canWriteAfter
                            ? '오늘 실제로 겪어보니 어떤 하루였는지 적어주세요.'
                            : '해당 날짜가 되어야 실제 기록을 열 수 있어요.'),
                      ),
                    ),

                    SizedBox(height: keyboardOpen ? 10 : 14),

                    _BottomContentLine(focusNode: _activeFocus),

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

/// ===============================
/// 헤더
/// ===============================
class _HeaderBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onHome;

  const _HeaderBar({
    required this.title,
    required this.onBack,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final w = LayoutTokens.contentW(context);

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: w,
        height: LayoutTokens.topBarH,
        child: Row(
          children: [
            Transform.translate(
              offset: const Offset(LayoutTokens.backBtnNudgeX, 0),
              child: AppPressButton(
                onTap: onBack,
                borderRadius: BorderRadius.circular(12),
                normalColor: Colors.transparent,
                pressedColor: _a(Colors.white, 0.12),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Icon(
                      Icons.arrow_back,
                      color: _a(AppTheme.homeInkWarm, 0.95),
                    ),
                  ),
                ),
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
            AppHeaderHomeButton(
              onTap: onHome,
            ),
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

    final rowW = (cardW * c) + (gap * math.max(0, c - 1));

    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: rowW,
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
/// AI 물어보기 섹션
/// ===============================
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

    final normalFill = _a(Colors.white, 0.08);
    final pressedFill = _a(Colors.white, 0.18);

    final normalBorder = _a(Colors.white, 0.14);
    final pressedBorder = _a(Colors.white, 0.24);

    final fill = _down ? pressedFill : normalFill;
    final border = _down ? pressedBorder : normalBorder;
    final text = _a(AppTheme.homeInkWarm, 0.92);

    return AnimatedScale(
      duration: const Duration(milliseconds: 70),
      curve: Curves.easeOut,
      scale: _down ? 0.985 : 1.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: border, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: _a(Colors.black, _down ? 0.03 : 0.06),
              blurRadius: _down ? 4 : 8,
              offset: Offset(0, _down ? 1 : 3),
              spreadRadius: -3,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(r),
            onTap: widget.onTap,
            onTapDown: (_) => _setDown(true),
            onTapCancel: () => _setDown(false),
            onTapUp: (_) async {
              await Future.delayed(const Duration(milliseconds: 300));
              if (!mounted) return;
              _setDown(false);
            },
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
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
      ),
    );
  }
}

/// ===============================
/// 폴더 인덱스 탭
/// ===============================
class _FolderIndexTabs extends StatelessWidget {
  final bool showBefore;
  final bool canWriteAfter;
  final VoidCallback onTapBefore;
  final VoidCallback onTapAfter;

  const _FolderIndexTabs({
    required this.showBefore,
    required this.canWriteAfter,
    required this.onTapBefore,
    required this.onTapAfter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FolderIndexTab(
            label: '나의 예상',
            selected: showBefore,
            locked: false,
            onTap: onTapBefore,
          ),
          const SizedBox(width: 1),
          _FolderIndexTab(
            label: '실제 하루',
            selected: !showBefore,
            locked: !canWriteAfter,
            onTap: onTapAfter,
          ),
        ],
      ),
    );
  }
}

class _FolderIndexTab extends StatefulWidget {
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _FolderIndexTab({
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  State<_FolderIndexTab> createState() => _FolderIndexTabState();
}

class _FolderIndexTabState extends State<_FolderIndexTab> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.selected
        ? _a(const Color(0xFFB46AA0), _down ? 0.24 : 0.18)
        : (_down ? _a(Colors.white, 0.06) : Colors.transparent);

    final border =
    widget.selected ? _a(Colors.white, 0.30) : _a(Colors.white, 0.22);

    final text = widget.locked
        ? _a(AppTheme.homeInkWarm, 0.42)
        : widget.selected
        ? _a(AppTheme.homeInkWarm, 0.96)
        : _a(AppTheme.homeInkWarm, 0.76);

    final icon = widget.locked
        ? _a(AppTheme.homeInkWarm, 0.40)
        : _a(AppTheme.homeInkWarm, 0.62);

    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      scale: _down ? 0.975 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => _setDown(true),
          onTapUp: (_) => _setDown(false),
          onTapCancel: () => _setDown(false),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              border: Border(
                top: BorderSide(color: border, width: 1),
                left: BorderSide(color: border, width: 1),
                right: BorderSide(color: border, width: 1),
                bottom: BorderSide.none,
              ),
            ),
            child: widget.locked
                ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, size: 12, color: icon),
                const SizedBox(width: 4),
                Text(
                  widget.label,
                  style: AppTheme.uiSmallLabel.copyWith(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    color: text,
                  ),
                ),
              ],
            )
                : Text(
              widget.label,
              style: AppTheme.uiSmallLabel.copyWith(
                fontSize: 14.0,
                fontWeight: FontWeight.w900,
                height: 1.0,
                color: text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ===============================
/// 상단 보더 라인
/// ===============================
class _TopContentLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        height: 1,
        color: _a(Colors.white, 0.22),
      ),
    );
  }
}

/// ===============================
/// 하단 보더 라인
/// ===============================
class _BottomContentLine extends StatefulWidget {
  final FocusNode focusNode;

  const _BottomContentLine({
    required this.focusNode,
  });

  @override
  State<_BottomContentLine> createState() => _BottomContentLineState();
}

class _BottomContentLineState extends State<_BottomContentLine> {
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
    final color = _a(Colors.white, focused ? 0.30 : 0.22);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 1,
        color: color,
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
  final String hintText;
  final bool enabled;
  final bool locked;

  const _DiaryInputTransparent({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.enabled = true,
    this.locked = false,
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

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 12, 0),
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            scrollController: _scrollC,
            cursorColor: cursor,
            expands: true,
            maxLines: null,
            minLines: null,
            enabled: widget.enabled,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: AppTheme.uiSmallLabel.copyWith(
              fontSize: 14.2,
              height: 1.62,
              fontWeight: FontWeight.w800,
              color: text,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
              hintText: widget.hintText,
              hintStyle: AppTheme.uiSmallLabel.copyWith(
                fontSize: 13.2,
                height: 1.55,
                fontWeight: FontWeight.w800,
                color: hint,
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (widget.locked)
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 20,
                      color: _a(AppTheme.tMuted, 0.76),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '해당 날짜가 되면 실제 기록을 열 수 있어',
                      style: AppTheme.uiSmallLabel.copyWith(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w800,
                        color: _a(AppTheme.tMuted, 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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
    final icon = text;

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