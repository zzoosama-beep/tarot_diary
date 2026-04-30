import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../backend/auth_service.dart';
import '../ads/rewarded_gate.dart';

// UI
import '../theme/app_theme.dart';
import '../ui/layout_tokens.dart';
import '../ui/app_toast.dart';
import '../ui/app_buttons.dart';

// Card
import 'arcana_labels.dart';
import '../ui/tarot_card_preview.dart';

// Left Float Tab
import 'lefttab_arcana_sheet.dart';

// DB
import '../backend/arcana_repo.dart';

// Dalnyang
import '../backend/dalnyang_service.dart';

// Error
import '../error/error_reporter.dart';

import '../setting.dart';


Color _a(Color c, double o) => c.withAlpha((o * 255).round());

enum _ArcanaContentTab { meaning, myNote }

class WriteArcanaPage extends StatefulWidget {
  final int? cardId;

  const WriteArcanaPage({
    super.key,
    this.cardId,
  });

  @override
  State<WriteArcanaPage> createState() => _WriteArcanaPageState();
}

class _WriteArcanaPageState extends State<WriteArcanaPage> {
  Color get _bg => AppTheme.bgColor;
  Color get _ink => _a(AppTheme.homeInkWarm, 0.94);
  Color get _inkDim => _a(AppTheme.homeInkWarm, 0.70);

  Color get _panel => _a(Colors.black, 0.08);
  Color get _panelStrong => _a(Colors.black, 0.11);

  Color get _border => _a(AppTheme.headerInk, 0.14);
  Color get _borderSoft => _a(AppTheme.headerInk, 0.10);

  Color get _field => _a(Colors.black, 0.10);
  Color get _fieldBorder => _a(AppTheme.headerInk, 0.12);

  List<BoxShadow> get _shadowSoft => [
    BoxShadow(
      color: _a(Colors.black, 0.10),
      blurRadius: 10,
      offset: const Offset(0, 6),
      spreadRadius: -6,
    ),
  ];

  late final TextStyle _tsTitle = AppTheme.title.copyWith(
    fontSize: 16.5,
    fontWeight: FontWeight.w900,
    color: _a(AppTheme.homeInkWarm, 0.96),
    letterSpacing: -0.2,
  );

  TextStyle get _tsCardTitle => GoogleFonts.gowunDodum(
    fontSize: 16.4,
    fontWeight: FontWeight.w900,
    color: _ink,
    letterSpacing: -0.2,
  );

  TextStyle get _tsSub => GoogleFonts.gowunDodum(
    fontSize: 12.6,
    fontWeight: FontWeight.w700,
    color: _a(AppTheme.homeInkWarm, 0.82),
    height: 1.2,
  );

  ArcanaGroup _group = ArcanaGroup.major;
  MinorSuit _suit = MinorSuit.wands;

  int? _selectedId;

  final TextEditingController _meaningC = TextEditingController();
  final TextEditingController _myNoteC = TextEditingController();
  final TextEditingController _tagsC = TextEditingController();

  final FocusNode _meaningFocus = FocusNode();
  final FocusNode _myNoteFocus = FocusNode();
  final FocusNode _tagsFocus = FocusNode();

  late final List<_ArcanaCard> _allCards = _buildAllCards();

  bool _saving = false;
  bool _askingArcana = false;
  _ArcanaContentTab _contentTab = _ArcanaContentTab.meaning;

  bool get _canAskArcana => _selectedCard != null && !_askingArcana;

  final Map<int, _ArcanaDraft> _draftById = {};
  final Map<int, bool> _savedExistsById = {};
  bool _isDragging = false;

  TextEditingController get _activeContentController =>
      _contentTab == _ArcanaContentTab.meaning ? _meaningC : _myNoteC;

  FocusNode get _activeContentFocus =>
      _contentTab == _ArcanaContentTab.meaning ? _meaningFocus : _myNoteFocus;

  String get _activeHint {
    return _contentTab == _ArcanaContentTab.meaning
        ? ''
        : '내 기준으로 이 카드가 어떤 의미였는지, 어떤 경험으로 남았는지 적어봐요.';
  }


  @override
  void initState() {
    super.initState();

    if (widget.cardId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPickDialogOrRoute();
      });
      return;
    }

    final id = widget.cardId!;
    _selectedId = id;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _applyDraftOrLoad(id);
      if (mounted) setState(() {});
    });

    // ✅ 여기서만 warm-up
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      RewardedGate.warmUpOnce().catchError((_) {});
    });
  }

  void _openPickDialogOrRoute() {
    Navigator.of(context).pushReplacementNamed('/list_arcana');
  }

  Future<void> _askArcanaMeaning() async {
    if (_askingArcana) return;

    final selected = _selectedCard;
    if (selected == null) {
      _toast('카드를 먼저 선택해주세요.');
      return;
    }

    FocusScope.of(context).unfocus();

    // ✅ 1. 즉시 로딩 상태로 변경하여 유저가 '멈춤'으로 느끼지 않게 합니다.
    setState(() => _askingArcana = true);

    try {
      final cardKoName = _cardKoName(selected.id);
      final cardEnName = selected.title;

      // DalnyangService 호출
      final answer = await DalnyangService.askArcanaWithCoin(
        context: context,
        cardId: selected.id,
        cardKoName: cardKoName,
        cardEnName: cardEnName,
        onThinkingStart: () {
          // 로직 진입 시 다시 한번 상태 확인
          if (mounted) setState(() => _askingArcana = true);
        },
        onThinkingEnd: () {
          if (mounted) setState(() => _askingArcana = false);
        },
      );

      if (!mounted || answer == null) return;

      final trimmed = answer.trim();
      if (trimmed.isEmpty) {
        _toast('달냥이 답변이 비어 있습니다. 다시 시도해주세요.');
        return;
      }

      final current = _meaningC.text.trim();
      final next = current.isEmpty ? trimmed : '$current\n\n---\n$trimmed';

      setState(() {
        _meaningC.text = next;
        _meaningC.selection = TextSelection.collapsed(offset: _meaningC.text.length);
        _contentTab = _ArcanaContentTab.meaning;
      });

      _stashDraft();
      _toast('기본 의미에 달냥이 답변을 추가했습니다.');
    } catch (e, st) {
      // 에러 발생 시 상태 초기화 필수
      if (mounted) setState(() => _askingArcana = false);

      await ErrorReporter.I.record(
        source: 'WriteArcanaPage._askArcanaMeaning',
        error: e,
        stackTrace: st,
        extra: {'cardId': selected.id},
      );

      _toast('달냥이를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      // 최종적으로 한 번 더 확인
      if (mounted && _askingArcana) {
        setState(() => _askingArcana = false);
      }
    }
  }

  String _cardKoName(int id) {
    if (id >= 0 && id <= 21) {
      return ArcanaLabels.majorKoName(id) ?? '알 수 없는 카드';
    }

    final file = ArcanaLabels.kTarotFileNames[id];
    return ArcanaLabels.minorKoFromFilename(file) ?? '알 수 없는 카드';
  }

  String _buildExternalPrompt() {
    final selected = _selectedCard;
    if (selected == null) return '';

    final cardKoName = _cardKoName(selected.id);
    final cardEnName = selected.title;
    final keywords = _tagsC.text.trim();

    final buffer = StringBuffer()
      ..writeln('당신은 타로 해석 전문가입니다.')
      ..writeln('카드: $cardKoName${cardEnName.isNotEmpty ? ' ($cardEnName)' : ''}')
      ..writeln('이 카드의 기본 의미와 흐름을 자연스럽게 설명해주세요.')
      ..writeln('정방향과 역방향의 가능성을 함께 반영해주세요.')
      ..writeln('좋은 흐름과 주의할 흐름이 함께 드러나게 써주세요.')
      ..writeln('존댓말로, 설명문처럼 딱딱하지 않게 작성해주세요.');

    if (keywords.isNotEmpty) {
      buffer.writeln('참고 키워드: $keywords');
    }

    return buffer.toString().trim();
  }

  Future<void> _copyPromptOnly() async {
    final selected = _selectedCard;
    if (selected == null) {
      _toast('카드를 먼저 선택해주세요.');
      return;
    }

    final prompt = _buildExternalPrompt();
    if (prompt.isEmpty) {
      _toast('복사할 프롬프트를 만들지 못했습니다.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: prompt));
  }

  Future<bool> _openUri(Uri uri) async {
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _askChatGPT() async {
    final selected = _selectedCard;
    if (selected == null) {
      _toast('카드를 먼저 선택해주세요.');
      return;
    }

    try {
      final prompt = _buildExternalPrompt();
      if (prompt.isEmpty) {
        _toast('프롬프트를 만들지 못했습니다.');
        return;
      }

      final encoded = Uri.encodeComponent(prompt);

      await Clipboard.setData(ClipboardData(text: prompt));

      final ok = await _openUri(
        Uri.parse('https://chat.openai.com/?q=$encoded'),
      );

      if (!mounted) return;

      if (ok) {
        _toast('프롬프트를 복사하고 챗지피티를 열었습니다.');
      } else {
        _toast('챗지피티를 열지 못했습니다. 직접 브라우저를 열어 붙여넣어주세요.');
      }
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'WriteArcanaPage._askChatGPT',
        error: e,
        stackTrace: st,
        extra: {
          'cardId': selected.id,
        },
      );
      if (!mounted) return;
      _toast('챗지피티를 열지 못했습니다. 잠시 후 다시 시도해주세요.');
    }
  }

  Future<void> _askGemini() async {
    final selected = _selectedCard;
    if (selected == null) {
      _toast('카드를 먼저 선택해주세요.');
      return;
    }

    try {
      await _copyPromptOnly();

      if (!mounted) return;

      _toast('프롬프트를 복사했습니다. 제미나이에 붙여넣어주세요.');

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
        _toast('제미나이를 열지 못했습니다. 직접 열어서 붙여넣어주세요.');
      }
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'WriteArcanaPage._askGemini',
        error: e,
        stackTrace: st,
        extra: {
          'cardId': selected.id,
        },
      );
      if (!mounted) return;
      _toast('제미나이를 열지 못했습니다. 잠시 후 다시 시도해주세요.');
    }
  }

  Future<void> _showAiActionSheet() async {
    // ✅ 탭이 '나의 해석'일 때는 아예 시트를 열지 않도록 방어 로직 추가
    if (_contentTab == _ArcanaContentTab.myNote) return;

    final selected = _selectedCard;
    if (selected == null) {
      _toast('카드를 먼저 선택해주세요.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) {
        return _AiActionBottomSheet(
          asking: _askingArcana,
          onGptTap: () async {
            Navigator.of(ctx).pop();
            await _askChatGPT();
          },
          onGeminiTap: () async {
            Navigator.of(ctx).pop();
            await _askGemini();
          },
          onDalnyangTap: () async {
            Navigator.of(ctx).pop();

            if (_selectedCard == null) {
              _toast('카드를 먼저 선택해주세요.');
              return;
            }

            if (_askingArcana) {
              _toast('달냥이가 답변을 준비하고 있습니다.');
              return;
            }

            if (!AuthService.isSignedIn) {
              await _showLoginRequiredDialog();
              return;
            }

            await _askArcanaMeaning();
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _meaningC.dispose();
    _myNoteC.dispose();
    _tagsC.dispose();

    _meaningFocus.dispose();
    _myNoteFocus.dispose();
    _tagsFocus.dispose();

    super.dispose();
  }

  List<_ArcanaCard> _buildAllCards() {
    final names = ArcanaLabels.kTarotFileNames;

    final cards = <_ArcanaCard>[];
    for (int i = 0; i < names.length; i++) {
      final file = names[i];
      final id = i;
      final path = 'asset/cards/$file';
      final isMajor = id <= 21;
      final suit = isMajor ? MinorSuit.unknown : _guessSuitFromFilename(file);

      cards.add(_ArcanaCard(
        id: id,
        assetPath: path,
        title: ArcanaLabels.prettyEnTitleFromFilename(file),
        isMajor: isMajor,
        suit: suit,
      ));
    }

    return cards;
  }

  MinorSuit _guessSuitFromFilename(String file) {
    final f = file.toLowerCase();
    if (f.contains('wands') || f.contains('wand')) return MinorSuit.wands;
    if (f.contains('cups') || f.contains('cup')) return MinorSuit.cups;
    if (f.contains('swords') || f.contains('sword')) return MinorSuit.swords;
    if (f.contains('pentacles') ||
        f.contains('pentacle') ||
        f.contains('coins') ||
        f.contains('coin')) {
      return MinorSuit.pentacles;
    }
    return MinorSuit.unknown;
  }

  String _suitLabel(MinorSuit s) {
    switch (s) {
      case MinorSuit.wands:
        return '완즈';
      case MinorSuit.cups:
        return '컵';
      case MinorSuit.swords:
        return '소드';
      case MinorSuit.pentacles:
        return '펜타클';
      case MinorSuit.unknown:
        return '전체';
    }
  }

  String _groupLabel(ArcanaGroup g) =>
      g == ArcanaGroup.major ? '메이저' : '마이너';

  List<_ArcanaCard> _filteredCards({
    required ArcanaGroup group,
    required MinorSuit suit,
  }) {
    final list = _allCards.where((c) {
      if (group == ArcanaGroup.major) return c.isMajor;

      if (!c.isMajor) {
        if (suit == MinorSuit.unknown) return true;
        return c.suit == suit || c.suit == MinorSuit.unknown;
      }
      return false;
    }).toList();

    list.sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  _ArcanaCard? get _selectedCard {
    final id = _selectedId;
    if (id == null) return null;
    try {
      return _allCards.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  bool get _canSave {
    if (_selectedId == null) return false;
    return _meaningC.text.trim().isNotEmpty ||
        _myNoteC.text.trim().isNotEmpty ||
        _tagsC.text.trim().isNotEmpty;
  }

  bool get _hasSavedRecord {
    final id = _selectedId;
    if (id == null) return false;
    return _savedExistsById[id] ?? false;
  }

  Future<void> _clearArcanaRecord() async {
    if (_saving || _askingArcana) return;

    final selected = _selectedCard;
    if (selected == null) {
      _toast('카드를 먼저 선택해주세요.');
      return;
    }

    setState(() => _saving = true);

    try {
      await ArcanaRepo.I.save(
        cardId: selected.id,
        title: selected.title,
        meaning: '',
        myNote: '',
        tags: '',
      );

      _meaningC.clear();
      _myNoteC.clear();
      _tagsC.clear();
      _savedExistsById[selected.id] = false;

      _stashDraft();

      if (mounted) {
        setState(() {
          _contentTab = _ArcanaContentTab.meaning;
        });
      }

      _toast('기록을 초기화했습니다.');

      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/list_arcana', (r) => false);
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'WriteArcanaPage._clearArcanaRecord',
        error: e,
        stackTrace: st,
        extra: {
          'cardId': selected.id,
        },
      );
      _toast('기록을 초기화하지 못했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showLoginRequiredDialog() async {
    final goSetting = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A1A3A),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: _a(AppTheme.headerInk, 0.14), width: 1),
          ),
          title: Text(
            '로그인이 필요한 서비스예요',
            style: GoogleFonts.gowunDodum(
              fontSize: 15.2,
              fontWeight: FontWeight.w900,
              color: _a(AppTheme.homeCream, 0.96),
            ),
          ),
          content: Text(
            '달냥이 찬스는 구글 로그인 후 사용할 수 있어요.\n\n설정 페이지로 이동해서 로그인하시겠어요?',
            style: GoogleFonts.gowunDodum(
              fontSize: 13.0,
              fontWeight: FontWeight.w700,
              height: 1.5,
              color: _a(AppTheme.homeCream, 0.90),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                '닫기',
                style: GoogleFonts.gowunDodum(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w800,
                  color: _a(AppTheme.homeCream, 0.72),
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: _a(const Color(0xFF866FBE), 0.92),
                foregroundColor: _a(AppTheme.homeCream, 0.98),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '설정으로 이동',
                style: GoogleFonts.gowunDodum(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (goSetting != true || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingPage(),
      ),
    );
  }

  Future<void> _confirmClearArcanaRecord() async {
    if (_askingArcana) return;

    const Color danger = Color(0xFFB45A64);

    final selected = _selectedCard;
    final rawCardLabel = selected == null
        ? '이 카드'
        : (selected.isMajor
        ? '${selected.id}. ${ArcanaLabels.majorKoName(selected.id) ?? selected.title}'
        : (ArcanaLabels.minorKoFromFilename(
        ArcanaLabels.kTarotFileNames[selected.id]) ??
        selected.title));

    final cardLabel = '< $rawCardLabel >';

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            dialogBackgroundColor: const Color(0xFF3A2F63),
          ),
          child: AlertDialog(
            insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            backgroundColor: const Color(0xFF3A2F63),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: _border, width: 1),
            ),
            titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 22,
                  color: _a(danger, 0.92),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '이 기록을 초기화할까요?',
                    style: GoogleFonts.gowunDodum(
                      fontSize: 14.2,
                      fontWeight: FontWeight.w900,
                      color: _a(AppTheme.homeInkWarm, 0.92),
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _a(danger, 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _a(danger, 0.45), width: 1),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.gowunDodum(
                        fontSize: 12.6,
                        fontWeight: FontWeight.w800,
                        color: _a(AppTheme.homeInkWarm, 0.86),
                        height: 1.6,
                      ),
                      children: [
                        TextSpan(
                          text: cardLabel,
                          style: TextStyle(
                            color: _a(AppTheme.homeInkWarm, 0.96),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const TextSpan(
                          text: ' 의 작성 기록이 초기화됩니다.\n\n',
                        ),
                        const TextSpan(
                          text: '카드 선택은 유지되고, 작성한 텍스트만 비워집니다.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
            actions: [
              Row(
                children: [
                  const Spacer(),
                  SizedBox(
                    height: 30,
                    child: FilledButton(
                      autofocus: true,
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: FilledButton.styleFrom(
                        backgroundColor: _a(AppTheme.accent, 0.10),
                        foregroundColor: _a(AppTheme.homeInkWarm, 0.90),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity:
                        const VisualDensity(horizontal: -1, vertical: -2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: _border, width: 1),
                        ),
                        textStyle: GoogleFonts.gowunDodum(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 30,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: _a(danger, 0.90),
                        foregroundColor: _a(Colors.white, 0.96),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity:
                        const VisualDensity(horizontal: -1, vertical: -2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: GoogleFonts.gowunDodum(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: const Text('초기화'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (ok == true) {
      await _clearArcanaRecord();
    }
  }

  Widget _buildRecordButtons() {
    final bool disabled = _saving || _askingArcana;

    if (!_hasSavedRecord) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 140),
          child: _MiniActionChip(
            icon: Icons.save_rounded,
            label: _askingArcana ? '달냥이가 답변을 준비하고 있습니다.' : '기록 저장',
            minWidth: 140,
            enabled: !disabled,
            onTap: _trySave,
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        _MiniActionChip(
          icon: Icons.edit_rounded,
          label: '기록 수정',
          enabled: !disabled,
          onTap: _trySave,
        ),
        _MiniActionChip(
          icon: Icons.delete_outline_rounded,
          label: '기록 초기화',
          enabled: !disabled,
          onTap: _confirmClearArcanaRecord,
          danger: true,
        ),
      ],
    );
  }

  void _toast(String msg, {double bottom = 110}) {
    if (!mounted) return;
    AppToast.show(context, msg);
  }

  void _stashDraft() {
    final id = _selectedId;
    if (id == null) return;
    _draftById[id] = _ArcanaDraft(
      meaning: _meaningC.text,
      myNote: _myNoteC.text,
      tags: _tagsC.text,
    );
  }

  void _applyDraft(int id, _ArcanaDraft d) {
    _meaningC.text = d.meaning;
    _myNoteC.text = d.myNote;
    _tagsC.text = d.tags;
  }

  Future<void> _applyDraftOrLoad(int id) async {
    final draft = _draftById[id];
    if (draft != null) {
      _applyDraft(id, draft);
      return;
    }

    await _loadExistingNoteIfAny(id);
    _stashDraft();
  }

  Future<void> _goToCard(int nextId, {bool fromSwipe = false}) async {
    if (_askingArcana) return;
    if (nextId < 0 || nextId >= _allCards.length) return;
    if (_isDragging && !fromSwipe) return;

    _stashDraft();

    setState(() => _selectedId = nextId);

    final card = _allCards.firstWhere((c) => c.id == nextId);
    if (card.isMajor) {
      _group = ArcanaGroup.major;
    } else {
      _group = ArcanaGroup.minor;
      _suit = card.suit == MinorSuit.unknown ? _suit : card.suit;
    }

    await _applyDraftOrLoad(nextId);
    if (mounted) setState(() {});
  }

  Future<void> _loadExistingNoteIfAny(int cardId) async {
    try {
      final repo = ArcanaRepo.I as dynamic;
      final data = await repo.read(cardId: cardId);

      if (!mounted) return;

      if (data == null) {
        _meaningC.text = '';
        _myNoteC.text = '';
        _tagsC.text = '';
        _savedExistsById[cardId] = false;
        return;
      }

      final meaning = (data['meaning'] ?? '').toString();
      final myNote = (data['myNote'] ?? '').toString();
      final tags = (data['tags'] ?? '').toString();

      _meaningC.text = meaning;
      _myNoteC.text = myNote;
      _tagsC.text = tags;

      _savedExistsById[cardId] = meaning.trim().isNotEmpty ||
          myNote.trim().isNotEmpty ||
          tags.trim().isNotEmpty;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'WriteArcanaPage._loadExistingNoteIfAny',
        error: e,
        stackTrace: st,
        extra: {
          'cardId': cardId,
        },
      );
    }
  }

  void _trySave() async {
    if (_saving || _askingArcana) return;

    final selected = _selectedCard;
    if (selected == null) {
      _toast('카드를 먼저 선택해주세요.');
      return;
    }

    final id = selected.id;

    if (!_canSave) {
      _toast('내용을 한 줄 이상 입력해주세요.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ArcanaRepo.I.save(
        cardId: id,
        title: selected.title,
        meaning: _meaningC.text.trim(),
        myNote: _myNoteC.text.trim(),
        tags: _tagsC.text.trim(),
      );

      _stashDraft();

      _toast('저장되었습니다.');

      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/list_arcana', (r) => false);
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'WriteArcanaPage._trySave',
        error: e,
        stackTrace: st,
        extra: {
          'cardId': id,
        },
      );
      _toast('저장하지 못했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPicker() async {
    if (_askingArcana) return;

    final items = _allCards
        .map(
          (c) => ArcanaCardItem(
        id: c.id,
        title: c.title,
        assetPath: c.assetPath,
        isMajor: c.isMajor,
        suit: c.suit,
      ),
    )
        .toList();

    final pickedId = await LeftTabArcanaSheet.open(
      context,
      title: '카드 선택',
      initialGroup: _group,
      initialSuit: _suit,
      initialSelectedId: _selectedId,
      allCards: items,
      suitLabel: _suitLabel,
      groupLabel: _groupLabel,
      filter: ({required group, required suit}) {
        final filtered = _filteredCards(group: group, suit: suit);
        return filtered
            .map(
              (c) => ArcanaCardItem(
            id: c.id,
            title: c.title,
            assetPath: c.assetPath,
            isMajor: c.isMajor,
            suit: c.suit,
          ),
        )
            .toList();
      },
    );

    if (pickedId == null) return;

    await _goToCard(pickedId);
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    if (_askingArcana) return;

    final id = _selectedId;
    if (id == null) return;

    final vx = d.primaryVelocity ?? 0.0;
    const threshold = 520.0;

    if (vx.abs() < threshold) return;

    setState(() => _isDragging = true);

    if (vx > 0) {
      _goToCard(id - 1, fromSwipe: true).whenComplete(() {
        if (mounted) setState(() => _isDragging = false);
      });
    } else {
      _goToCard(id + 1, fromSwipe: true).whenComplete(() {
        if (mounted) setState(() => _isDragging = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedCard;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final keyboardInset = viewInsets.bottom;
    final keyboardOpen = keyboardInset > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _bg,
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportH = constraints.maxHeight;

                return AbsorbPointer(
                  absorbing: _askingArcana,
                  child: Column(
                    children: [
                      Builder(
                        builder: (context) {
                          final double sidePad =
                          MediaQuery.of(context).size.width < 360
                              ? 12
                              : (MediaQuery.of(context).size.width < 430
                              ? 14
                              : 18);

                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              sidePad,
                              LayoutTokens.scrollTopPad,
                              sidePad,
                              0,
                            ),
                            child: SizedBox(
                              height: 40,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 56,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Transform.translate(
                                        offset: const Offset(2, 0),
                                        child: AppHeaderBackIconButton(
                                          onTap: () => Navigator.of(context).pop(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        '78장 아르카나 기록',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: _tsTitle,
                                        textAlign: TextAlign.center,
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
                                              .pushNamedAndRemoveUntil('/', (route) => false),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: CenterBox(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => FocusScope.of(context).unfocus(),
                            onHorizontalDragEnd:
                            _askingArcana ? null : _onHorizontalDragEnd,
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.fromLTRB(
                                0,
                                12,
                                0,
                                keyboardInset + (keyboardOpen ? 120 : 44),
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: math.max(0, viewportH - 24),
                                ),
                                child: Column(
                                  children: [
                                    _PickAndSummaryBox(
                                      selected: selected,
                                      onTap: _askingArcana ? () {} : _openPicker,
                                      onPrev: (selected == null ||
                                          selected.id <= 0 ||
                                          _askingArcana)
                                          ? null
                                          : () => _goToCard(selected.id - 1),
                                      onNext: (selected == null ||
                                          selected.id >= _allCards.length - 1 ||
                                          _askingArcana)
                                          ? null
                                          : () => _goToCard(selected.id + 1),
                                      tagsC: _tagsC,
                                      tagsFocus: _tagsFocus,
                                      keyboardOpen: keyboardOpen,
                                      onTagsChanged: (_) {
                                        setState(() {});
                                        _stashDraft();
                                      },
                                      panel: _panelStrong,
                                      panelWeak: _panel,
                                      border: _border,
                                      borderSoft: _borderSoft,
                                      shadow: _shadowSoft,
                                      ink: _ink,
                                      inkDim: _inkDim,
                                      field: _field,
                                      fieldBorder: _fieldBorder,
                                    ),
                                    const SizedBox(height: 12),
                                    _TabbedContentBox(
                                      activeTab: _contentTab,
                                      onTabChanged: _askingArcana
                                          ? (_) {}
                                          : (tab) {
                                        setState(() => _contentTab = tab);
                                      },
                                      controller: _activeContentController,
                                      focusNode: _activeContentFocus,
                                      hint: _activeHint,
                                      keyboardOpen: keyboardOpen,
                                      onChanged: (_) {
                                        setState(() {});
                                        _stashDraft();
                                      },
                                      onAiTap:
                                      _askingArcana ? () {} : _showAiActionSheet,
                                      panel: _panel,
                                      border: _border,
                                      shadow: _shadowSoft,
                                      fieldFill: _field,
                                      fieldBorder: _fieldBorder,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildRecordButtons(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_askingArcana) const Positioned.fill(child: _DalnyangThinkingOverlay()),
        ],
      ),
    );
  }
}

// =========================================================
// Widgets
// =========================================================

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

class _AiActionBottomSheet extends StatelessWidget {
  final bool asking;
  final VoidCallback onGptTap;
  final VoidCallback onGeminiTap;
  final VoidCallback onDalnyangTap;

  const _AiActionBottomSheet({
    required this.asking,
    required this.onGptTap,
    required this.onGeminiTap,
    required this.onDalnyangTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = _a(AppTheme.bgColor, 0.98);
    final panel = _a(Colors.black, 0.12);
    final border = _a(AppTheme.headerInk, 0.14);
    final text = _a(AppTheme.homeInkWarm, 0.94);
    final sub = _a(AppTheme.homeInkWarm, 0.70);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border, width: 1),
            boxShadow: [
              BoxShadow(
                color: _a(Colors.black, 0.22),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _a(AppTheme.homeInkWarm, 0.24),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'AI에게 물어보기',
                    style: GoogleFonts.gowunDodum(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w900,
                      color: text,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '선택한 방식으로 아르카나 설명을 확인할 수 있습니다.',
                    style: GoogleFonts.gowunDodum(
                      fontSize: 12.6,
                      fontWeight: FontWeight.w700,
                      color: sub,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _AiSheetButton(
                  label: '챗지피티 열기',
                  icon: Icons.auto_awesome_outlined,
                  panel: panel,
                  border: border,
                  text: text,
                  onTap: onGptTap,
                ),
                const SizedBox(height: 10),
                _AiSheetButton(
                  label: '제미나이 열기',
                  icon: Icons.bolt_rounded,
                  panel: panel,
                  border: border,
                  text: text,
                  onTap: onGeminiTap,
                ),
                const SizedBox(height: 10),
                _AiSheetButton(
                  label: asking
                      ? '달냥이가 답변을 준비하고 있습니다.'
                      : '달냥이 찬스 (광고 시 AI 입력)',
                  icon: Icons.pets_rounded,
                  panel: _a(Colors.amber, 0.10),
                  border: _a(Colors.amber, 0.24),
                  text: text,
                  onTap: asking ? () {} : onDalnyangTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiSheetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color panel;
  final Color border;
  final Color text;
  final VoidCallback onTap;

  const _AiSheetButton({
    required this.label,
    required this.icon,
    required this.panel,
    required this.border,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 18, color: _a(text, 0.92)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.gowunDodum(
                      fontSize: 13.4,
                      fontWeight: FontWeight.w900,
                      color: text,
                      height: 1.0,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: _a(text, 0.56),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcanaCard {
  final int id;
  final String title;
  final String assetPath;
  final bool isMajor;
  final MinorSuit suit;

  const _ArcanaCard({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.isMajor,
    required this.suit,
  });
}

class _ArcanaDraft {
  final String meaning;
  final String myNote;
  final String tags;

  const _ArcanaDraft({
    required this.meaning,
    required this.myNote,
    required this.tags,
  });
}

// 아래 위젯들은 원본 구조를 유지했습니다.
class _PickAndSummaryBox extends StatelessWidget {
  final _ArcanaCard? selected;
  final VoidCallback onTap;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final TextEditingController tagsC;
  final FocusNode tagsFocus;
  final bool keyboardOpen;
  final ValueChanged<String> onTagsChanged;
  final Color panel;
  final Color panelWeak;
  final Color border;
  final Color borderSoft;
  final List<BoxShadow> shadow;
  final Color ink;
  final Color inkDim;
  final Color field;
  final Color fieldBorder;

  const _PickAndSummaryBox({
    required this.selected,
    required this.onTap,
    required this.onPrev,
    required this.onNext,
    required this.tagsC,
    required this.tagsFocus,
    required this.keyboardOpen,
    required this.onTagsChanged,
    required this.panel,
    required this.panelWeak,
    required this.border,
    required this.borderSoft,
    required this.shadow,
    required this.ink,
    required this.inkDim,
    required this.field,
    required this.fieldBorder,
  });

  @override
  Widget build(BuildContext context) {
    final has = selected != null;

    String koTitle() {
      if (!has) return '카드 미선택';

      if (selected!.isMajor) {
        final ko = ArcanaLabels.majorKoName(selected!.id) ?? selected!.title;
        return '${selected!.id}. $ko';
      }

      final fn = ArcanaLabels.kTarotFileNames[selected!.id];
      return ArcanaLabels.minorKoFromFilename(fn) ?? selected!.title;
    }

    String headerTitle() {
      if (!has) return '카드 미선택';
      return '${koTitle()} (${selected!.title})';
    }

    final titleColor = has ? ink : inkDim;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: shadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: has ? panel : panelWeak,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: has ? border : borderSoft, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _NavMiniBtn(
                            icon: Icons.chevron_left_rounded,
                            enabled: has && onPrev != null,
                            onTap: has ? onPrev : null,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: SizedBox(
                                height: 24,
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      headerTitle(),
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.gowunDodum(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.w900,
                                        color: titleColor,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _NavMiniBtn(
                            icon: Icons.chevron_right_rounded,
                            enabled: has && onNext != null,
                            onTap: has ? onNext : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _a(Colors.black, has ? 0.10 : 0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _a(
                                  AppTheme.headerInk,
                                  has ? 0.18 : 0.14,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  has
                                      ? Icons.autorenew_rounded
                                      : Icons.add_rounded,
                                  size: 13,
                                  color: _a(
                                    AppTheme.homeInkWarm,
                                    has ? 0.90 : 0.76,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  has ? '카드 변경' : '카드 선택',
                                  style: GoogleFonts.gowunDodum(
                                    fontSize: 11.2,
                                    fontWeight: FontWeight.w900,
                                    color: _a(
                                      AppTheme.homeInkWarm,
                                      has ? 0.92 : 0.80,
                                    ),
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: _a(AppTheme.headerInk, 0.10),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: _SelectedSummaryInner(
                    card: selected,
                    tagsC: tagsC,
                    tagsFocus: tagsFocus,
                    keyboardOpen: keyboardOpen,
                    onTagsChanged: onTagsChanged,
                    field: field,
                    fieldBorder: fieldBorder,
                    ink: ink,
                    inkDim: inkDim,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavMiniBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavMiniBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = enabled
        ? _a(AppTheme.homeInkWarm, 0.88)
        : _a(AppTheme.homeInkWarm, 0.35);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _a(Colors.black, enabled ? 0.10 : 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _a(AppTheme.headerInk, enabled ? 0.16 : 0.10),
            width: 1,
          ),
        ),
        child: Icon(icon, size: 22, color: c),
      ),
    );
  }
}

class _SelectedSummaryInner extends StatelessWidget {
  final _ArcanaCard? card;
  final TextEditingController tagsC;
  final FocusNode tagsFocus;
  final bool keyboardOpen;
  final ValueChanged<String> onTagsChanged;
  final Color field;
  final Color fieldBorder;
  final Color ink;
  final Color inkDim;

  const _SelectedSummaryInner({
    required this.card,
    required this.tagsC,
    required this.tagsFocus,
    required this.keyboardOpen,
    required this.onTagsChanged,
    required this.field,
    required this.fieldBorder,
    required this.ink,
    required this.inkDim,
  });

  @override
  Widget build(BuildContext context) {
    if (card == null) {
      return Text(
        '선택된 카드가 없습니다.',
        style: GoogleFonts.gowunDodum(
          fontSize: 12.6,
          fontWeight: FontWeight.w800,
          color: _a(AppTheme.homeInkWarm, 0.82),
        ),
      );
    }

    final compact = MediaQuery.of(context).size.width < 340;
    final imageW = compact ? 76.0 : (keyboardOpen ? 84.0 : 98.0);
    final imageH = compact ? 132.0 : (keyboardOpen ? 148.0 : 172.0);
    final textH = compact ? 130.0 : (keyboardOpen ? 146.0 : 170.0);
    final gap = compact ? 8.0 : 12.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              TarotCardPreview.open(
                context,
                assetPath: card!.assetPath,
                heroTag: 'arcana_${card!.id}',
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: imageW,
                height: imageH,
                color: _a(Colors.black, 0.12),
                child: Image.asset(
                  card!.assetPath,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: SizedBox(
            height: textH,
            child: TextField(
              controller: tagsC,
              focusNode: tagsFocus,
              onChanged: onTagsChanged,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: GoogleFonts.gowunDodum(
                fontSize: compact ? 12.8 : 13.6,
                fontWeight: FontWeight.w700,
                color: _a(AppTheme.homeInkWarm, 0.92),
                height: 1.25,
              ),
              decoration: InputDecoration(
                hintText: '키워드 입력\n(예: #시작 #도전 #자유)',
                hintStyle: GoogleFonts.gowunDodum(
                  fontSize: compact ? 12.2 : 13.0,
                  fontWeight: FontWeight.w600,
                  color: _a(AppTheme.homeInkWarm, 0.62),
                  height: 1.2,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
                filled: true,
                fillColor: field,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: fieldBorder, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: fieldBorder, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _a(AppTheme.headerInk, 0.20),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabbedContentBox extends StatelessWidget {
  final _ArcanaContentTab activeTab;
  final ValueChanged<_ArcanaContentTab> onTabChanged;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool keyboardOpen;
  final ValueChanged<String> onChanged;
  final VoidCallback onAiTap;
  final Color panel;
  final Color border;
  final List<BoxShadow> shadow;
  final Color fieldFill;
  final Color fieldBorder;

  const _TabbedContentBox({
    required this.activeTab,
    required this.onTabChanged,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.keyboardOpen,
    required this.onChanged,
    required this.onAiTap,
    required this.panel,
    required this.border,
    required this.shadow,
    required this.fieldFill,
    required this.fieldBorder,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ '기본 의미' 탭일 때만 AI 버튼을 활성화 상태로 설정
    final bool isAiEnabled = activeTab == _ArcanaContentTab.meaning;

    const boxRadius = BorderRadius.only(
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FolderTabs(
          activeTab: activeTab,
          onTabChanged: onTabChanged,
        ),
        Transform.translate(
          offset: const Offset(0, -1),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: boxRadius,
              boxShadow: shadow,
            ),
            child: ClipRRect(
              borderRadius: boxRadius,
              child: Container(
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: boxRadius,
                  border: Border(
                    left: BorderSide(color: border, width: 1),
                    right: BorderSide(color: border, width: 1),
                    bottom: BorderSide(color: border, width: 1),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ 버튼은 항상 유지하되 enabled 상태만 동적으로 변함
                      Center(
                        child: _AiUtilButton(
                          onTap: onAiTap,
                          enabled: isAiEnabled,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: keyboardOpen ? 220 : 270,
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onChanged: onChanged,
                          expands: true,
                          minLines: null,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          textAlignVertical: TextAlignVertical.top,
                          style: GoogleFonts.gowunDodum(
                            fontSize: 13.2,
                            fontWeight: FontWeight.w700,
                            color: _a(AppTheme.homeInkWarm, 0.92),
                            height: 1.45,
                          ),
                          decoration: InputDecoration(
                            hintText: hint,
                            hintStyle: GoogleFonts.gowunDodum(
                              fontSize: 12.8,
                              fontWeight: FontWeight.w600,
                              color: _a(AppTheme.homeInkWarm, 0.62),
                              height: 1.35,
                            ),
                            filled: true,
                            fillColor: fieldFill,
                            alignLabelWithHint: true,
                            contentPadding:
                            const EdgeInsets.fromLTRB(12, 14, 12, 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: fieldBorder, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: fieldBorder, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _a(AppTheme.headerInk, 0.20),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FolderTabs extends StatelessWidget {
  final _ArcanaContentTab activeTab;
  final ValueChanged<_ArcanaContentTab> onTabChanged;

  const _FolderTabs({
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FolderTab(
          label: '기본 의미',
          active: activeTab == _ArcanaContentTab.meaning,
          onTap: () => onTabChanged(_ArcanaContentTab.meaning),
        ),
        const SizedBox(width: 1),
        _FolderTab(
          label: '나의 해석 / 경험',
          active: activeTab == _ArcanaContentTab.myNote,
          onTap: () => onTabChanged(_ArcanaContentTab.myNote),
        ),
      ],
    );
  }
}

class _FolderTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FolderTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = _a(AppTheme.headerInk, 0.12);
    final activeBg = _a(Colors.black, 0.08);
    final inactiveBg = _a(Colors.black, 0.16);
    final bg = active ? activeBg : inactiveBg;
    final text = active
        ? _a(AppTheme.homeInkWarm, 0.98)
        : _a(AppTheme.homeInkWarm, 0.60);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(
              top: BorderSide(color: borderColor, width: 1),
              left: BorderSide(color: borderColor, width: 1),
              right: BorderSide(color: borderColor, width: 1),
              bottom: active
                  ? BorderSide.none
                  : BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.gowunDodum(
              fontSize: 12.8,
              fontWeight: FontWeight.w900,
              color: text,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final double? minWidth;
  final bool enabled;

  const _MiniActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.minWidth,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color base = danger ? const Color(0xFFB45A64) : AppTheme.accent;
    final bool isNarrow = MediaQuery.of(context).size.width < 360;

    final Color bgColor =
    enabled ? _a(base, danger ? 0.10 : 0.08) : _a(base, 0.05);
    final Color borderColor = enabled ? _a(base, 0.22) : _a(base, 0.10);
    final Color iconColor =
    enabled ? _a(AppTheme.tPrimary, 0.90) : _a(AppTheme.tPrimary, 0.42);
    final Color textColor =
    enabled ? _a(AppTheme.tPrimary, 0.92) : _a(AppTheme.tPrimary, 0.46);

    return Opacity(
      opacity: enabled ? 1.0 : 0.68,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          splashColor: enabled ? _a(base, 0.10) : Colors.transparent,
          highlightColor: enabled ? _a(base, 0.05) : Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth ?? 0),
            child: Ink(
              height: isNarrow ? 34 : 36,
              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: isNarrow ? 15 : 16, color: iconColor),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.gowunDodum(
                      fontSize: isNarrow ? 12.0 : 12.4,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      height: 1.0,
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

class _AiUtilButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool enabled; // ✅ 탭 상태에 따른 활성화 여부

  const _AiUtilButton({
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<_AiUtilButton> createState() => _AiUtilButtonState();
}

class _AiUtilButtonState extends State<_AiUtilButton> {
  bool _down = false;

  void _setDown(bool v) {
    // ✅ 비활성화 상태거나 값이 같으면 무시
    if (!widget.enabled || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 활성화 상태에 따라 색상과 투명도를 다르게 적용
    final iconBg = widget.enabled
        ? _a(AppTheme.homeInkWarm, _down ? 0.22 : 0.16)
        : _a(AppTheme.homeInkWarm, 0.05); // 비활성화 시 연하게

    final iconBorder = widget.enabled
        ? _a(AppTheme.headerInk, _down ? 0.24 : 0.16)
        : _a(AppTheme.headerInk, 0.08);

    final iconFg = widget.enabled
        ? _a(AppTheme.homeInkWarm, 0.96)
        : _a(AppTheme.homeInkWarm, 0.30); // 아이콘 흐릿하게

    final textColor = widget.enabled
        ? _a(AppTheme.homeInkWarm, 0.92)
        : _a(AppTheme.homeInkWarm, 0.40); // 텍스트 흐릿하게

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // ✅ 비활성화(나의 해석 탭) 시에는 클릭 이벤트 자체를 null로 설정
        onTap: widget.enabled ? widget.onTap : null,
        borderRadius: BorderRadius.circular(999),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTapDown: (_) => _setDown(true),
        onTapCancel: () => _setDown(false),
        onTapUp: (_) => _setDown(false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: iconBorder, width: 1),
                ),
                child: Text(
                  '?',
                  style: GoogleFonts.gowunDodum(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w900,
                    color: iconFg,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'AI에게 물어보기',
                style: GoogleFonts.gowunDodum(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DalnyangThinkingOverlay extends StatefulWidget {
  const _DalnyangThinkingOverlay();

  @override
  State<_DalnyangThinkingOverlay> createState() =>
      _DalnyangThinkingOverlayState();
}

class _DalnyangThinkingOverlayState extends State<_DalnyangThinkingOverlay> {
  Timer? _timer;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) return;
      setState(() {
        _dotCount = (_dotCount + 1) % 4;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String dots = '.' * _dotCount;
    final Color barrier = Colors.black.withAlpha((0.18 * 255).round());
    final Color panel = _a(AppTheme.bgColor, 0.96);
    final Color border = _a(AppTheme.headerInk, 0.16);
    final Color text = _a(AppTheme.homeInkWarm, 0.96);
    final Color sub = _a(AppTheme.homeInkWarm, 0.72);

    return IgnorePointer(
      ignoring: false,
      child: Container(
        color: barrier,
        alignment: Alignment.center,
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 1),
            boxShadow: [
              BoxShadow(
                color: _a(Colors.black, 0.20),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pets_rounded,
                size: 28,
                color: _a(AppTheme.homeInkWarm, 0.92),
              ),
              const SizedBox(height: 10),
              Text(
                '달냥이가 생각 중입니다$dots',
                textAlign: TextAlign.center,
                style: GoogleFonts.gowunDodum(
                  fontSize: 14.2,
                  fontWeight: FontWeight.w900,
                  color: text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '잠시만 기다려주세요.',
                textAlign: TextAlign.center,
                style: GoogleFonts.gowunDodum(
                  fontSize: 12.4,
                  fontWeight: FontWeight.w700,
                  color: sub,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}