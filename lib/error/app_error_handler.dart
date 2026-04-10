import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../backend/dalnyang_api.dart';
import 'app_error_dialog.dart';
import 'error_reporter.dart';

/// ------------------------------------------------------------
/// 달냥이 공용 에러 핸들러
///
/// 역할:
/// - Exception 타입 분기 (Known / Unknown)
/// - 사용자에게 보여줄 안내 문구 결정
/// - 실제 에러 원문은 ErrorReporter 로만 전송
/// - UI 쪽에서는 try/catch 최소화
///
/// 원칙:
/// - 여기서 "판단"
/// - app_error_dialog 는 "그리기만"
/// ------------------------------------------------------------
Future<void> handleDalnyangError(
    BuildContext context,
    Object error, {
      StackTrace? stackTrace,
      String source = 'handleDalnyangError',
      Map<String, Object?>? extra,
    }) async {
  if (!context.mounted) return;

  await ErrorReporter.I.record(
    source: source,
    error: error,
    stackTrace: stackTrace,
    extra: extra,
  );

  final message = _toUserMessage(error);

  if (!context.mounted) return;
  await showDalnyangErrorDialog(
    context,
    message: message,
  );
}

String _toUserMessage(Object error) {
  // 1) 이미 사용자 안내용으로 정의된 예외
  if (error is DalnyangKnownException) {
    return error.userMessage.trim();
  }

  // 2) 네트워크/타임아웃
  if (error is SocketException) {
    return '인터넷 연결이 원활하지 않습니다.\n네트워크 상태를 확인한 뒤 다시 시도해주세요.';
  }

  if (error is TimeoutException) {
    return '응답이 지연되고 있습니다.\n잠시 후 다시 시도해주세요.';
  }

  // 3) 달냥 Unknown 예외
  if (error is DalnyangUnknownException) {
    final raw = '${error.message}\n${error.debugText}'.toUpperCase();

    if (raw.contains('NO_CREDITS')) {
      return '코인이 부족합니다.\n광고를 보고 다시 시도해주세요.';
    }

    if (raw.contains('DAILY_LIMIT')) {
      return '오늘 사용 가능한 횟수를 모두 사용하셨습니다.\n내일 다시 시도해주세요.';
    }

    if (raw.contains('STATUS')) {
      return '사용 가능 횟수를 확인하지 못했습니다.\n잠시 후 다시 시도해주세요.';
    }

    if (raw.contains('REWARD_CREDIT')) {
      return '광고 보상 처리에 실패했습니다.\n잠시 후 다시 시도해주세요.';
    }

    if (raw.contains('JSON')) {
      return '서버 응답이 올바르지 않습니다.\n잠시 후 다시 시도해주세요.';
    }

    return error.message.trim().isNotEmpty
        ? error.message.trim()
        : '달냥이 요청을 처리하지 못했습니다.\n잠시 후 다시 시도해주세요.';
  }

  // 4) 그 외
  return '달냥이 요청을 처리하지 못했습니다.\n잠시 후 다시 시도해주세요.';
}