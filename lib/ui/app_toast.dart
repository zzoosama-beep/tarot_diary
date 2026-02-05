// lib/ui/app_toast.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class AppToast {
  static OverlayEntry? _entry;

  static void show(
      BuildContext context,
      String message, {
        Duration duration = const Duration(seconds: 2),
        double bottom = 0, // ✅ 완전 하단 바
      }) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    // 기존 토스트 제거
    _entry?.remove();
    _entry = null;

    _entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        right: 0,
        bottom: bottom,
        child: Material(
          color: Colors.transparent,
          child: Container(
            // ❌ SafeArea 제거 (좌우 여백 원인)
            // ✅ 내부 패딩만 유지
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _a(Colors.black, 0.85),
              // ✅ 진짜 바 느낌 → 라운드 아예 없애거나 위만 살짝
              borderRadius: BorderRadius.zero,
              // 만약 위만 둥글게 하고 싶으면 ↓
              // borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.uiSmallLabel.copyWith(
                color: _a(AppTheme.tPrimary, 0.95),
                fontSize: 12.8,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_entry!);

    Future.delayed(duration, () {
      _entry?.remove();
      _entry = null;
    });
  }
}
