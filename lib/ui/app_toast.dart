import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'layout_tokens.dart';

Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class AppToast {
  static OverlayEntry? _entry;
  static int _toastToken = 0;

  static const Duration _displayDuration = Duration(seconds: 2);
  static const Duration _fadeDuration = Duration(milliseconds: 180);
  static const Duration _slideDuration = Duration(milliseconds: 180);

  static void show(
      BuildContext context,
      String message, {
        /// 호출부 호환용으로만 남김
        double? actionAreaHeight,
      }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final overlayContext = overlay.context;
    final media = MediaQuery.of(overlayContext);
    final size = media.size;

    final double width = size.width;
    final double height = size.height;
    final double shortest = size.shortestSide;

    final double safeBottom = media.padding.bottom;
    final double viewInsetBottom = media.viewInsets.bottom;

    final bool isTablet = shortest >= 600;
    final bool isSmallPhone = width < 360;
    final bool isShortScreen = height < 700;
    final bool isLargePhone = width >= 390 && !isTablet;

    /// ✅ 가로폭은 항상 본문 박스 기준
    final double contentW = LayoutTokens.contentW(overlayContext);

    /// ✅ 반응형은 폭이 아니라 패딩/폰트/높이만 조절
    final double toastHorizontalPadding = isTablet
        ? 18
        : isSmallPhone
        ? 14
        : 16;

    final double toastVerticalPadding = isTablet
        ? 10
        : isSmallPhone
        ? 7
        : 8;

    final double fontSize = isTablet
        ? 14.2
        : isSmallPhone
        ? 12.2
        : isLargePhone
        ? 13.4
        : 13.0;

    final double minHeight = isTablet
        ? 44
        : isSmallPhone
        ? 36
        : 38;

    final double borderRadius = 4;

    final double fixedBottomGap = isTablet
        ? 30
        : isShortScreen
        ? 20
        : isSmallPhone
        ? 18
        : 24;

    const double keyboardGap = 16;

    final double resolvedBottom = viewInsetBottom > 0
        ? viewInsetBottom + keyboardGap
        : safeBottom + fixedBottomGap;

    _entry?.remove();
    _entry = null;

    final int currentToken = ++_toastToken;
    bool visible = false;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        right: 0,
        bottom: resolvedBottom,
        child: IgnorePointer(
          ignoring: true,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: SizedBox(
                width: contentW,
                child: AnimatedSlide(
                  offset: visible ? Offset.zero : const Offset(0, 0.10),
                  duration: _slideDuration,
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: _fadeDuration,
                    curve: Curves.easeOut,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: minHeight,
                        maxWidth: contentW,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _a(Colors.black, 0.78),
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: toastHorizontalPadding,
                            vertical: toastVerticalPadding,
                          ),
                          child: Text(
                            message.trim(),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.uiSmallLabel.copyWith(
                              color: _a(Colors.white, 0.96),
                              fontSize: fontSize,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    _entry = entry;
    overlay.insert(entry);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_toastToken != currentToken) return;
      visible = true;
      entry.markNeedsBuild();
    });

    Future.delayed(_displayDuration, () async {
      if (_toastToken != currentToken) return;

      visible = false;
      entry.markNeedsBuild();

      await Future.delayed(
        _fadeDuration > _slideDuration ? _fadeDuration : _slideDuration,
      );

      if (_toastToken != currentToken) return;
      _entry?.remove();
      _entry = null;
    });
  }

  static void hide() {
    _toastToken++;
    _entry?.remove();
    _entry = null;
  }
}