import 'package:flutter/material.dart';

import '../backend/dalnyang_api.dart';
import 'app_error_dialog.dart';

/// ------------------------------------------------------------
/// 달냥이 공용 에러 핸들러
///
/// 역할:
/// - Exception 타입 분기 (Known / Unknown)
/// - 어떤 다이얼로그 옵션으로 띄울지 결정
/// - UI 쪽에서는 try/catch 최소화
///
/// 원칙:
/// - 여기서 "판단"
/// - app_error_dialog 는 "그리기만"
/// ------------------------------------------------------------
Future<void> handleDalnyangError(
    BuildContext context,
    Object error,
    ) async {
  // 이미 위젯이 dispose 된 경우 방어
  if (!context.mounted) return;

  // ✅ 1) 사전에 정의된 "안내용" 예외
  if (error is DalnyangKnownException) {
    await showDalnyangErrorDialog(
      context,
      exceptionMessage: error.toString(),
      showDebug: false, // ❌ 에러코드/디버그 숨김
    );
    return;
  }

  // ✅ 2) 우리가 모르는/돌발 예외
  await showDalnyangErrorDialog(
    context,
    exceptionMessage: error.toString(),
    showDebug: true, // ✅ 디버그 표시
  );
}
