import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'contact_api.dart';
import '../theme/app_theme.dart';
import '../ui/app_toast.dart';

import './../ui/layout_tokens.dart';
import './../ui/app_buttons.dart';
import '../error/error_reporter.dart';
import '../error/app_error_dialog.dart';

Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class ContactFormPage extends StatefulWidget {
  const ContactFormPage({super.key});

  @override
  State<ContactFormPage> createState() => _ContactFormPageState();
}

class _ContactFormPageState extends State<ContactFormPage> {
  final TextEditingController _emailC = TextEditingController();
  final TextEditingController _contentC = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  bool _loading = false;
  bool _initializing = true;
  bool _attachErrorReport = false;

  String _appVersion = '확인 불가';
  String _deviceInfo = '확인 불가';
  String _emailHint = '이메일';

  static const int _maxErrorReportChars = 12000;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email?.trim() ?? '';

      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      final deviceInfo = await _readDeviceInfo();

      if (!mounted) return;

      setState(() {
        _appVersion = appVersion;
        _deviceInfo = deviceInfo;

        if (email.isNotEmpty) {
          _emailC.text = email;
          _emailHint = '이메일'; // 로그인 상태
        } else {
          _emailHint = '답변 받으실 메일 주소를 입력해주세요'; // 비로그인 상태
        }

        _initializing = false;
      });
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'ContactFormPage._loadInitialData',
        error: e,
        stackTrace: st,
      );

      if (!mounted) return;
      setState(() {
        _initializing = false;
      });
    }
  }

  Future<String> _readDeviceInfo() async {
    final plugin = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final brand = info.brand.trim();
        final model = info.model.trim();
        final release = info.version.release.trim();
        return '$brand $model (Android $release)';
      }

      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        final name = info.name.trim();
        final model = info.model.trim();
        final systemVersion = info.systemVersion.trim();
        return '$name $model (iOS $systemVersion)';
      }

      if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        return 'Windows (${info.productName})';
      }

      if (Platform.isMacOS) {
        final info = await plugin.macOsInfo;
        return 'macOS (${info.model})';
      }

      if (Platform.isLinux) {
        final info = await plugin.linuxInfo;
        return 'Linux (${info.prettyName})';
      }

      return '알 수 없는 기기';
    } catch (_) {
      return '확인 불가';
    }
  }

  String _contactErrorMessage(Object error) {
    if (error is ContactApiException) {
      return error.userMessage;
    }
    return '문의 전송 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.';
  }

  String _trimForMail(String text, {required int maxChars}) {
    final normalized = text.trim();
    if (normalized.isEmpty) return normalized;
    if (normalized.length <= maxChars) return normalized;

    final head = normalized.substring(0, maxChars);
    return '$head\n\n[오류 정보가 너무 길어 일부만 첨부되었습니다.]';
  }

  Future<String> _buildAttachableErrorReport() async {
    final raw = await ErrorReporter.I.buildReportText();
    return _trimForMail(raw, maxChars: _maxErrorReportChars);
  }

  Future<void> _submit() async {
    final email = _emailC.text.trim();
    final content = _contentC.text.trim();

    if (email.isEmpty) {
      _showToast('이메일을 입력해주세요.');
      return;
    }

    if (content.isEmpty) {
      _showToast('문의 내용을 입력해주세요.');
      return;
    }

    setState(() => _loading = true);

    try {
      String? errorReport;
      if (_attachErrorReport) {
        errorReport = await _buildAttachableErrorReport();
      }

      final fullMessage = [
        '1. 사용중인 앱버전 : $_appVersion',
        '',
        '2. 사용중인 기기 : $_deviceInfo',
        '',
        '3. 문의 내용',
        content,
        if (_attachErrorReport) ...[
          '',
          '',
          '4. 오류 정보',
          errorReport ?? '최근 저장된 오류가 없습니다.',
        ],
      ].join('\n');

      const api = ContactApi();

      await api.sendContact(
        replyEmail: email,
        message: fullMessage,
        appVersion: _appVersion,
        deviceInfo: _deviceInfo,
      );

      if (!mounted) return;
      _showToast('문의가 정상적으로 전송되었습니다.');
      Navigator.of(context).pop();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'ContactFormPage._submit',
        error: e,
        stackTrace: st,
        extra: {
          'appVersion': _appVersion,
          'deviceInfo': _deviceInfo,
          'hasEmail': email.isNotEmpty,
          'contentLength': content.length,
          'attachErrorReport': _attachErrorReport,
        },
      );

      if (!mounted) return;
      await showDalnyangErrorDialog(
        context,
        message: _contactErrorMessage(e),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showToast(String text) {
    if (!mounted) return;
    AppToast.show(context, text);
  }

  Widget _buildSectionCard({
    required Widget child,
    required double radius,
    required EdgeInsetsGeometry padding,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _a(AppTheme.homeCream, 0.88),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: _a(AppTheme.headerInk, 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.12),
            blurRadius: 18,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: _a(Colors.white, 0.18),
            blurRadius: 12,
            offset: const Offset(0, -6),
            spreadRadius: -8,
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _plainFieldDecoration({
    String? hint,
    EdgeInsetsGeometry? contentPadding,
    required double radius,
    required double hintFontSize,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(
        color: _a(AppTheme.headerInk, 0.16),
        width: 1,
      ),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(
        color: _a(const Color(0xFF7A63B0), 0.55),
        width: 1.2,
      ),
    );

    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: _a(Colors.white, 0.55),
      hintStyle: AppTheme.body.copyWith(
        fontSize: hintFontSize,
        color: _a(const Color(0xFF6A5876), 0.52),
      ),
      contentPadding: contentPadding,
      enabledBorder: border,
      focusedBorder: focusedBorder,
      border: border,
    );
  }

  Widget _buildPrimaryButton({
    required double buttonHeight,
    required double radius,
    required double fontSize,
    required bool isTablet,
  }) {
    final enabled = !_loading && !_initializing;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? _submit : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: enabled
              ? _a(const Color(0xFF7A63B0), 0.88)
              : _a(const Color(0xFF7A63B0), 0.28),
          foregroundColor: _a(AppTheme.homeCream, 0.96),
          disabledBackgroundColor: _a(const Color(0xFF7A63B0), 0.28),
          disabledForegroundColor: _a(AppTheme.homeCream, 0.42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(
              color: _a(AppTheme.headerInk, enabled ? 0.18 : 0.08),
              width: 1,
            ),
          ),
          padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
          minimumSize: Size.fromHeight(buttonHeight),
        ),
        child: (_loading || _initializing)
            ? SizedBox(
          width: isTablet ? 20 : 18,
          height: isTablet ? 20 : 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(
              _a(AppTheme.homeCream, 0.96),
            ),
          ),
        )
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mail_rounded,
              size: isTablet ? 20 : 18,
              color: _a(AppTheme.homeCream, 0.96),
            ),
            const SizedBox(width: 8),
            Text(
              '전송하기',
              style: AppTheme.body.copyWith(
                fontSize: isTablet ? 14.5 : 14,
                fontWeight: FontWeight.w900,
                color: _a(AppTheme.homeCream, 0.96),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoLabel(
      String label, {
        required double fontSize,
      }) {
    return Text(
      label,
      style: AppTheme.body.copyWith(
        fontSize: fontSize,
        height: 1.45,
        color: _a(const Color(0xFF3A2147), 0.56),
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildInfoValue(
      String value, {
        required double fontSize,
      }) {
    return Text(
      value,
      softWrap: true,
      style: AppTheme.body.copyWith(
        fontSize: fontSize,
        height: 1.5,
        color: _a(const Color(0xFF3A2147), 0.78),
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildInfoBlock({
    required String label,
    required String value,
    required double labelFontSize,
    required double valueFontSize,
    required double gap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoLabel(label, fontSize: labelFontSize),
        SizedBox(height: gap),
        _buildInfoValue(value, fontSize: valueFontSize),
      ],
    );
  }

  Widget _buildAttachErrorOption({
    required bool isTablet,
  }) {
    final enabled = !_loading && !_initializing;
    const checkColor = Color(0xFF6E56A6);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled
          ? () {
        setState(() {
          _attachErrorReport = !_attachErrorReport;
        });
      }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _attachErrorReport
                    ? _a(checkColor, 0.92)
                    : _a(Colors.white, 0.92),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: _attachErrorReport
                      ? _a(checkColor, 0.98)
                      : _a(const Color(0xFF6A5876), 0.52),
                  width: 1.6,
                ),
              ),
              alignment: Alignment.center,
              child: _attachErrorReport
                  ? Icon(
                Icons.check_rounded,
                size: 15,
                color: _a(Colors.white, 0.98),
              )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '문제 해결을 위해 오류 정보를 함께 보냅니다',
                style: AppTheme.body.copyWith(
                  fontSize: isTablet ? 12.8 : 12.0,
                  height: 1.35,
                  color: _a(const Color(0xFF3A2147), 0.74),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailC.dispose();
    _contentC.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final height = mq.size.height;
    final viewInsetBottom = mq.viewInsets.bottom;

    final isTablet = mq.size.shortestSide >= 600;
    final isShort = height < 700;
    final isLargePhone = width >= 390 && !isTablet;
    final keyboardVisible = viewInsetBottom > 0;

    final double sidePad = width < 360 ? 12 : (width < 430 ? 14 : 18);

    final outerTopPad = isTablet
        ? 28.0
        : isShort
        ? 16.0
        : 24.0;

    final contentW = LayoutTokens.contentW(context);
    final cardWidth = contentW;

    final cardRadius = isTablet ? 22.0 : 18.0;
    final fieldRadius = isTablet ? 16.0 : 14.0;
    final sectionPad = isTablet
        ? const EdgeInsets.fromLTRB(22, 20, 22, 22)
        : const EdgeInsets.fromLTRB(18, 16, 18, 18);

    final bodyFontSize = isTablet
        ? 15.0
        : isLargePhone
        ? 14.2
        : 14.0;

    final hintFontSize = isTablet ? 14.0 : 13.4;
    final infoLabelFontSize = isTablet ? 13.6 : 13.0;
    final infoValueFontSize = isTablet ? 14.4 : 13.6;
    final contentLineHeight = isTablet ? 1.6 : 1.55;

    final buttonHeight = isTablet ? 52.0 : 48.0;
    final buttonRadius = isTablet ? 15.0 : 13.0;
    final buttonFontSize = isTablet ? 13.8 : 13.0;

    final emailFieldPadding = isTablet
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 15)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 14);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        left: false,
        right: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.maxHeight;

            final cardVerticalPadding =
                sectionPad.vertical + emailFieldPadding.vertical;
            final estimatedFixedHeight = cardVerticalPadding +
                buttonHeight +
                outerTopPad +
                88 +
                (isTablet ? 92 : 82);

            final availableForContent =
                viewportHeight - estimatedFixedHeight - viewInsetBottom;

            final contentBoxHeight = keyboardVisible
                ? (isTablet ? 180.0 : 160.0)
                : isTablet
                ? availableForContent.clamp(220.0, 320.0)
                : isShort
                ? availableForContent.clamp(140.0, 240.0)
                : availableForContent.clamp(200.0, 300.0);

            return SingleChildScrollView(
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                0,
                LayoutTokens.scrollTopPad,
                0,
                28 + viewInsetBottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewportHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: sidePad),
                      child: SizedBox(
                        height: 40,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Center(
                              child: Text(
                                '문의하기',
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.title.copyWith(
                                  color: _a(AppTheme.homeInkWarm, 0.96),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Transform.translate(
                                offset: const Offset(
                                  LayoutTokens.backBtnNudgeX,
                                  0,
                                ),
                                child: AppPressButton(
                                  onTap: () => Navigator.of(context).maybePop(),
                                  borderRadius: BorderRadius.circular(12),
                                  normalColor: Colors.transparent,
                                  pressedColor: _a(Colors.white, 0.08),
                                  scaleDown: 0.96,
                                  animDuration:
                                  const Duration(milliseconds: 110),
                                  child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: Center(
                                      child: Icon(
                                        Icons.arrow_back_rounded,
                                        color:
                                        _a(AppTheme.homeInkWarm, 0.96),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Transform.translate(
                                offset: const Offset(0, 2),
                                child: AppHeaderHomeIconButton(
                                  onTap: () => Navigator.of(context)
                                      .pushNamedAndRemoveUntil('/', (r) => false),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: sidePad),
                      child: Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: cardWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSectionCard(
                                radius: cardRadius,
                                padding: sectionPad,
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _emailC,
                                      keyboardType:
                                      TextInputType.emailAddress,
                                      style: AppTheme.body.copyWith(
                                        fontSize: bodyFontSize,
                                        color:
                                        _a(const Color(0xFF3A2147), 0.92),
                                        fontWeight: FontWeight.w700,
                                      ),
                                      decoration: _plainFieldDecoration(
                                        hint: _emailHint,
                                        radius: fieldRadius,
                                        hintFontSize: hintFontSize,
                                        contentPadding: emailFieldPadding,
                                      ),
                                    ),
                                    SizedBox(height: isTablet ? 16 : 14),
                                    GestureDetector(
                                      behavior:
                                      HitTestBehavior.translucent,
                                      onTap: () {
                                        FocusScope.of(context)
                                            .requestFocus(_contentFocusNode);
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        padding: isTablet
                                            ? const EdgeInsets.fromLTRB(
                                            16, 16, 16, 16)
                                            : const EdgeInsets.fromLTRB(
                                            14, 14, 14, 14),
                                        decoration: BoxDecoration(
                                          color: _a(Colors.white, 0.55),
                                          borderRadius: BorderRadius.circular(
                                              fieldRadius),
                                          border: Border.all(
                                            color:
                                            _a(AppTheme.headerInk, 0.16),
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            _buildInfoBlock(
                                              label: '1. 사용중인 앱버전',
                                              value: _appVersion,
                                              labelFontSize:
                                              infoLabelFontSize,
                                              valueFontSize:
                                              infoValueFontSize,
                                              gap: isTablet ? 4 : 3,
                                            ),
                                            SizedBox(
                                                height: isTablet ? 14 : 12),
                                            _buildInfoBlock(
                                              label: '2. 사용중인 기기',
                                              value: _deviceInfo,
                                              labelFontSize:
                                              infoLabelFontSize,
                                              valueFontSize:
                                              infoValueFontSize,
                                              gap: isTablet ? 4 : 3,
                                            ),
                                            SizedBox(
                                                height: isTablet ? 18 : 16),
                                            Container(
                                              width: double.infinity,
                                              height: 1,
                                              color: _a(
                                                  AppTheme.headerInk, 0.10),
                                            ),
                                            SizedBox(
                                                height: isTablet ? 16 : 14),
                                            Text(
                                              '3. 문의 내용을 입력해주세요',
                                              style: AppTheme.body.copyWith(
                                                fontSize: bodyFontSize,
                                                height: 1.5,
                                                color: _a(
                                                  const Color(0xFF3A2147),
                                                  0.92,
                                                ),
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            SizedBox(
                                                height: isTablet ? 12 : 10),
                                            SizedBox(
                                              width: double.infinity,
                                              height: contentBoxHeight,
                                              child: TextField(
                                                controller: _contentC,
                                                focusNode:
                                                _contentFocusNode,
                                                maxLines: null,
                                                expands: true,
                                                textAlignVertical:
                                                TextAlignVertical.top,
                                                style:
                                                AppTheme.body.copyWith(
                                                  fontSize: bodyFontSize,
                                                  height: contentLineHeight,
                                                  color: _a(
                                                    const Color(0xFF3A2147),
                                                    0.92,
                                                  ),
                                                  fontWeight:
                                                  FontWeight.w700,
                                                ),
                                                decoration: InputDecoration(
                                                  isCollapsed: true,
                                                  border: InputBorder.none,
                                                  hintText: '여기에 입력해주세요',
                                                  hintStyle:
                                                  AppTheme.body.copyWith(
                                                    fontSize: hintFontSize,
                                                    height: 1.5,
                                                    color: _a(
                                                      const Color(0xFF6A5876),
                                                      0.52,
                                                    ),
                                                    fontWeight:
                                                    FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                                height: isTablet ? 14 : 12),
                                            _buildAttachErrorOption(
                                              isTablet: isTablet,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: isTablet ? 18 : 16),
                              SizedBox(
                                width: double.infinity,
                                child: _buildPrimaryButton(
                                  buttonHeight: buttonHeight,
                                  radius: buttonRadius,
                                  fontSize: buttonFontSize,
                                  isTablet: isTablet,
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
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
      ),
    );
  }
}