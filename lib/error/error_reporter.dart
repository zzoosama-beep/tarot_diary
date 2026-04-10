import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ErrorReporter {
  ErrorReporter._();
  static final ErrorReporter I = ErrorReporter._();

  static const _kKeyRecentErrors = 'recent_error_reports_v1';
  static const int _maxItems = 10;
  static const int _maxStackLines = 5;
  static const int _maxErrorTextChars = 500;
  static const int _maxExtraChars = 800;

  Future<void> record({
    required String source,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) async {
    final item = <String, dynamic>{
      'time': DateTime.now().toIso8601String(),
      'errorType': error.runtimeType.toString(),
      'source': source,
      'error': error.toString(),
      'stackTrace': stackTrace?.toString() ?? '',
      'extra': extra ?? <String, dynamic>{},
    };

    if (kDebugMode) {
      debugPrint('[ERROR][$source][${error.runtimeType}] $error');
      if (stackTrace != null) {
        debugPrint('$stackTrace');
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKeyRecentErrors);

      List<dynamic> list = [];

      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          list = decoded;
        }
      }

      list.insert(0, item);

      if (list.length > _maxItems) {
        list = list.sublist(0, _maxItems);
      }

      await prefs.setString(_kKeyRecentErrors, jsonEncode(list));
    } catch (_) {
      // 오류 기록 실패는 무시합니다.
    }
  }

  Future<List<Map<String, dynamic>>> readAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKeyRecentErrors);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _trimText(String text, {required int maxChars}) {
    final normalized = text.trim();
    if (normalized.isEmpty) return normalized;
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars)}...';
  }

  String _shortStackTrace(String stackTrace) {
    final normalized = stackTrace.trim();
    if (normalized.isEmpty) return '';

    final lines = normalized
        .split('\n')
        .map((e) => e.trimRight())
        .where((e) => e.isNotEmpty)
        .take(_maxStackLines)
        .toList();

    return lines.join('\n');
  }

  Future<String> buildReportText() async {
    final items = await readAll();
    if (items.isEmpty) {
      return '최근 저장된 오류가 없습니다.';
    }

    final buffer = StringBuffer();
    buffer.writeln('최근 오류 기록');
    buffer.writeln('====================');

    for (final item in items) {
      buffer.writeln('시간: ${item['time'] ?? ''}');
      buffer.writeln('위치: ${item['source'] ?? ''}');
      buffer.writeln('오류 타입: ${item['errorType'] ?? ''}');
      buffer.writeln(
        '오류 내용: ${_trimText((item['error'] ?? '').toString(), maxChars: _maxErrorTextChars)}',
      );

      final extra = item['extra'];
      if (extra is Map && extra.isNotEmpty) {
        final extraText = _trimText(
          jsonEncode(extra),
          maxChars: _maxExtraChars,
        );
        buffer.writeln('추가 정보: $extraText');
      }

      final st = _shortStackTrace((item['stackTrace'] ?? '').toString());
      if (st.isNotEmpty) {
        buffer.writeln('스택 정보:');
        buffer.writeln(st);
      }

      buffer.writeln('--------------------');
    }

    return buffer.toString();
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kKeyRecentErrors);
    } catch (_) {}
  }
}