import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../error/error_reporter.dart';

class DalnyangKnownException implements Exception {
  final String userMessage;
  DalnyangKnownException(this.userMessage);

  @override
  String toString() => userMessage;
}

class DalnyangUnknownException implements Exception {
  final String message;
  final String debugText;

  DalnyangUnknownException({
    required this.message,
    required this.debugText,
  });

  @override
  String toString() => '$message\n\n---\n$debugText';
}

class DalnyangApi {
  static const String baseUrl =
      'https://asia-northeast3-tarotdiary-88376.cloudfunctions.net/api';

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[DalnyangApi] $message');
    }
  }

  static String dailyLimitAskMsg(int limit) =>
      '오늘 사용 가능한 횟수는 하루 ${limit}회까지입니다.\n오늘은 모두 사용하셨습니다. 내일 다시 시도해주세요.';

  static String dailyLimitRewardMsg(int limit) =>
      '오늘 받을 수 있는 보상은 하루 ${limit}회까지입니다.\n오늘은 모두 사용하셨습니다. 내일 다시 시도해주세요.';

  static String requestInProgressMsg() =>
      '같은 요청을 처리 중입니다.\n잠시만 기다린 뒤 다시 확인해주세요.';

  static String _shortRaw(String raw, {int max = 500}) =>
      raw.length <= max ? raw : '${raw.substring(0, max)}…';

  static String? _extractErrorCode(String raw) {
    try {
      final d = jsonDecode(raw);
      if (d is Map && d['error'] != null) return d['error'].toString();
    } catch (_) {}
    return null;
  }

  static Map<String, dynamic>? _tryDecodeJson(String raw) {
    try {
      final d = jsonDecode(raw);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }

  static String _dbg({
    required String prefix,
    required int status,
    String? code,
    required String raw,
  }) {
    final c = code == null ? '' : '\ncode=$code';
    return '$prefix\nHTTP $status$c\n${_shortRaw(raw)}';
  }

  static DalnyangUnknownException _unknown({
    required String message,
    required String debugPrefix,
    required int status,
    String? code,
    required String raw,
  }) {
    return DalnyangUnknownException(
      message: message,
      debugText: _dbg(
        prefix: debugPrefix,
        status: status,
        code: code,
        raw: raw,
      ),
    );
  }

  static DalnyangUnknownException _unknownText({
    required String message,
    required String debugText,
  }) {
    return DalnyangUnknownException(
      message: message,
      debugText: debugText,
    );
  }

  static dynamic _decodeJsonOrThrow({
    required String raw,
    required String userMessageOnFail,
    required String debugPrefix,
    required int status,
    String? code,
  }) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      throw _unknown(
        message: userMessageOnFail,
        debugPrefix: '$debugPrefix JSON 파싱 실패',
        status: status,
        code: code,
        raw: raw,
      );
    }
  }

  static int? _extractLimitFromAskResponseBody(String raw) {
    final m = _tryDecodeJson(raw);
    final usage = (m?['usage'] is Map) ? (m!['usage'] as Map) : null;
    final lim = usage?['limit'];
    return (lim is num) ? lim.toInt() : null;
  }

  static Future<String> _resolveFreshIdToken(String fallbackToken) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final currentToken = fallbackToken.trim();

      if (user == null) return currentToken;

      final fresh = await user.getIdToken(true);
      final freshToken = (fresh ?? '').trim();

      if (freshToken.isNotEmpty) return freshToken;
      return currentToken;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DalnyangApi._resolveFreshIdToken',
        error: e,
        stackTrace: st,
      );
      return fallbackToken.trim();
    }
  }

  /// 기존 warmUpServer는 Functions 호출 수를 늘려 비용을 만들 수 있어서
  /// 자동 호출하지 않도록 남겨만 둡니다.
  /// 필요할 때 수동 디버깅용으로만 쓰세요.
  static Future<void> warmUpServer({
    required String idToken,
    required String deviceId,
    bool force = false,
  }) async {
    return;
  }

  static Future<void> prepareForUse({
    required String idToken,
    required String deviceId,
  }) async {
    return;
  }

  static Future<RewardStatus> precheckRewardOrThrow({
    required String idToken,
    required String deviceId,
  }) async {
    final effectiveIdToken = await _resolveFreshIdToken(idToken);
    final status = await getRewardStatus(
      idToken: effectiveIdToken,
      deviceId: deviceId,
    );

    if (status.remaining <= 0) {
      throw DalnyangKnownException(dailyLimitRewardMsg(status.limit));
    }

    return status;
  }

  static Future<String> askArcanaMeaning({
    required String idToken,
    required String deviceId,
    required String idempotencyKey,
    required String cardKoName,
    required String cardEnName,
  }) {
    const question = '이 카드의 의미를 도감용으로 정리해주세요.';
    return ask(
      idToken: idToken,
      deviceId: deviceId,
      idempotencyKey: idempotencyKey,
      question: question,
      context: {
        'source': 'arcana',
        'card_ko': cardKoName,
        'card_en': cardEnName,
      },
    );
  }

  static Future<RewardCreditResult> creditRewardedAd({
    required String idToken,
    required String deviceId,
    required String adEventId,
    String? requestId,
    String status = 'rewarded',
    String adType = 'rewarded',
    String? platform,
  }) async {
    final effectiveIdToken = await _resolveFreshIdToken(idToken);

    final safeRequestId =
    (requestId != null && requestId.trim().isNotEmpty)
        ? requestId
        : adEventId;

    return _creditRewardedAdOnce(
      idToken: effectiveIdToken,
      deviceId: deviceId,
      adEventId: adEventId,
      requestId: safeRequestId,
      status: status,
      adType: adType,
      platform: platform,
    );
  }

  static Future<RewardCreditResult> _creditRewardedAdOnce({
    required String idToken,
    required String deviceId,
    required String adEventId,
    String? requestId,
    required String status,
    required String adType,
    String? platform,
  }) async {
    final uri = Uri.parse('$baseUrl/reward/rewarded-ad/credit');

    final safeRequestId =
    (requestId != null && requestId.trim().isNotEmpty)
        ? requestId
        : adEventId;

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $idToken',
      'X-Device-Id': deviceId,
    };

    final body = {
      'device_id': deviceId,
      'ad_event_id': adEventId,
      'request_id': safeRequestId,
      'status': status,
      'ad_type': adType,
      if (platform != null && platform.trim().isNotEmpty) 'platform': platform,
    };

    try {
      _log('reward credit request');

      final res = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));

      final raw = utf8.decode(res.bodyBytes);
      final code = _extractErrorCode(raw);

      _log('reward credit status=${res.statusCode}');
      _log('reward credit raw=${_shortRaw(raw, max: 2000)}');

      if (res.statusCode == 429 && code == 'DAILY_LIMIT_REWARD') {
        throw DalnyangKnownException(dailyLimitRewardMsg(3));
      }

      if (res.statusCode != 200) {
        throw _unknown(
          message: '광고 보상 처리에 실패했습니다.\n잠시 후 다시 시도해주세요.',
          debugPrefix: 'REWARD_CREDIT',
          status: res.statusCode,
          code: code,
          raw: raw,
        );
      }

      final data = _decodeJsonOrThrow(
        raw: raw,
        userMessageOnFail: '광고 보상 처리에 실패했습니다.\n잠시 후 다시 시도해주세요.',
        debugPrefix: 'REWARD_CREDIT',
        status: res.statusCode,
        code: code,
      );

      if (data is! Map || data['ok'] != true) {
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'INVALID_RESPONSE';
        throw _unknownText(
          message: '광고 보상 처리에 실패했습니다.\n잠시 후 다시 시도해주세요.',
          debugText: 'REWARD_CREDIT invalid response: $err\n$raw',
        );
      }

      final user = data['user'];
      final credits =
      (user is Map && user['credits'] is num)
          ? (user['credits'] as num).toInt()
          : 0;
      final creatorPoints =
      (user is Map && user['creator_points'] is num)
          ? (user['creator_points'] as num).toInt()
          : 0;
      final totalAdRewardCount =
      (user is Map && user['total_ad_reward_count'] is num)
          ? (user['total_ad_reward_count'] as num).toInt()
          : 0;

      return RewardCreditResult(
        duplicated: data['duplicated'] == true,
        rewarded: data['rewarded'] == true,
        credits: credits,
        creatorPoints: creatorPoints,
        totalAdRewardCount: totalAdRewardCount,
      );
    } on SocketException catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DalnyangApi._creditRewardedAdOnce.SocketException',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } on TimeoutException catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DalnyangApi._creditRewardedAdOnce.TimeoutException',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DalnyangApi._creditRewardedAdOnce',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  static Future<RewardStatus> getRewardStatus({
    required String idToken,
    required String deviceId,
  }) async {
    final effectiveIdToken = await _resolveFreshIdToken(idToken);

    return _getRewardStatusOnce(
      idToken: effectiveIdToken,
      deviceId: deviceId,
    );
  }

  static Future<RewardStatus> _getRewardStatusOnce({
    required String idToken,
    required String deviceId,
  }) async {
    final uri = Uri.parse('$baseUrl/reward/rewarded-ad/status');
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $idToken',
      'X-Device-Id': deviceId,
    };

    try {
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));
      final raw = utf8.decode(res.bodyBytes);
      final code = _extractErrorCode(raw);

      _log('reward status status=${res.statusCode}');
      _log('reward status raw=${_shortRaw(raw, max: 1000)}');

      if (res.statusCode != 200) {
        throw _unknown(
          message: '사용 가능 횟수를 확인하지 못했습니다.\n잠시 후 다시 시도해주세요.',
          debugPrefix: 'STATUS',
          status: res.statusCode,
          code: code,
          raw: raw,
        );
      }

      final data = _decodeJsonOrThrow(
        raw: raw,
        userMessageOnFail: '사용 가능 횟수를 확인하지 못했습니다.\n잠시 후 다시 시도해주세요.',
        debugPrefix: 'STATUS',
        status: res.statusCode,
        code: code,
      );

      if (data is! Map || data['ok'] != true) {
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'INVALID_RESPONSE';
        throw _unknownText(
          message: '사용 가능 횟수를 확인하지 못했습니다.\n잠시 후 다시 시도해주세요.',
          debugText: 'STATUS invalid response: $err\n$raw',
        );
      }

      return RewardStatus(
        day: (data['day'] ?? '').toString(),
        limit: (data['limit'] as num?)?.toInt() ?? 0,
        used: (data['used'] as num?)?.toInt() ?? 0,
        remaining: (data['remaining'] as num?)?.toInt() ?? 0,
      );
    } on SocketException catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DalnyangApi._getRewardStatusOnce.SocketException',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } on TimeoutException catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DalnyangApi._getRewardStatusOnce.TimeoutException',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DalnyangApi._getRewardStatusOnce',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  static Future<String> ask({
    required String idToken,
    required String deviceId,
    required String idempotencyKey,
    required String question,
    Map<String, dynamic>? context,
  }) async {
    final result = await askDetailed(
      idToken: idToken,
      deviceId: deviceId,
      idempotencyKey: idempotencyKey,
      question: question,
      context: context,
    );
    return result.answer;
  }

  static Future<AskResult> askDetailed({
    required String idToken,
    required String deviceId,
    required String idempotencyKey,
    required String question,
    Map<String, dynamic>? context,
  }) async {
    final effectiveIdToken = await _resolveFreshIdToken(idToken);

    if (effectiveIdToken.trim().isEmpty) {
      throw _unknownText(
        message: '로그인 상태를 확인해주세요.',
        debugText: 'idToken is empty',
      );
    }
    if (deviceId.trim().isEmpty) {
      throw _unknownText(
        message: '기기 정보를 확인해주세요.',
        debugText: 'deviceId is empty',
      );
    }
    if (idempotencyKey.trim().isEmpty) {
      throw _unknownText(
        message: '요청 키 생성에 실패했습니다.',
        debugText: 'idempotencyKey is empty',
      );
    }
    if (question.trim().isEmpty) {
      throw _unknownText(
        message: '질문 내용이 비어 있습니다.',
        debugText: 'question is empty',
      );
    }

    return _askOnce(
      idToken: effectiveIdToken,
      deviceId: deviceId,
      idempotencyKey: idempotencyKey,
      question: question,
      context: context,
    );
  }

  static Future<AskResult> _askOnce({
    required String idToken,
    required String deviceId,
    required String idempotencyKey,
    required String question,
    Map<String, dynamic>? context,
  }) async {
    final uri = Uri.parse('$baseUrl/dalnyang/ask');

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $idToken',
      'X-Device-Id': deviceId,
    };

    final body = <String, dynamic>{
      'device_id': deviceId,
      'idempotency_key': idempotencyKey,
      'question': question,
      if (context != null) 'context': context,
    };

    try {
      _log('ask request');

      final res = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 45));

      final raw = utf8.decode(res.bodyBytes);
      final code = _extractErrorCode(raw);

      _log('ask status=${res.statusCode}');
      _log('ask raw=${_shortRaw(raw, max: 2000)}');

      if (res.statusCode == 402 && code == 'NO_CREDITS') {
        throw DalnyangKnownException('코인이 부족합니다. 광고를 보고 다시 시도해주세요.');
      }

      if (res.statusCode == 409 && code == 'REQUEST_IN_PROGRESS') {
        throw DalnyangKnownException(requestInProgressMsg());
      }

      if (res.statusCode == 429) {
        final limit = _extractLimitFromAskResponseBody(raw) ?? 3;
        throw DalnyangKnownException(dailyLimitAskMsg(limit));
      }

      if (res.statusCode != 200) {
        throw _unknown(
          message: '달냥이 호출에 실패했습니다.\n잠시 후 다시 시도해주세요.',
          debugPrefix: 'ASK',
          status: res.statusCode,
          code: code,
          raw: raw,
        );
      }

      final data = _decodeJsonOrThrow(
        raw: raw,
        userMessageOnFail: '달냥이 호출에 실패했습니다.\n잠시 후 다시 시도해주세요.',
        debugPrefix: 'ASK',
        status: res.statusCode,
        code: code,
      );

      if (data is! Map || data['ok'] != true) {
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'INVALID_RESPONSE';
        throw _unknownText(
          message: '달냥이 호출에 실패했습니다.\n잠시 후 다시 시도해주세요.',
          debugText: 'ASK invalid response: $err\n$raw',
        );
      }

      final answer = (data['answer'] ?? '').toString().trim();
      if (answer.isEmpty) {
        throw _unknownText(
          message: '달냥이 답변이 비어 있습니다.\n다시 시도해주세요.',
          debugText: 'ASK answer empty\n$raw',
        );
      }

      final usage = data['usage'];
      final mode =
      (usage is Map && usage['mode'] != null) ? usage['mode'].toString() : null;

      final remainingCredits =
      (usage is Map && usage['remaining_credits'] is num)
          ? (usage['remaining_credits'] as num).toInt()
          : null;

      final day =
      (usage is Map && usage['day'] != null) ? usage['day'].toString() : null;

      final uidUsed =
      (usage is Map && usage['uid_used'] is num)
          ? (usage['uid_used'] as num).toInt()
          : null;

      final limit =
      (usage is Map && usage['limit'] is num)
          ? (usage['limit'] as num).toInt()
          : null;

      return AskResult(
        answer: answer,
        cached: data['cached'] == true,
        mode: mode,
        remainingCredits: remainingCredits,
        day: day,
        uidUsed: uidUsed,
        limit: limit,
      );
    } on SocketException catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DalnyangApi._askOnce.SocketException',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } on TimeoutException catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DalnyangApi._askOnce.TimeoutException',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DalnyangApi._askOnce',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}

class RewardStatus {
  final String day;
  final int limit;
  final int used;
  final int remaining;

  const RewardStatus({
    required this.day,
    required this.limit,
    required this.used,
    required this.remaining,
  });
}

class RewardCreditResult {
  final bool duplicated;
  final bool rewarded;
  final int credits;
  final int creatorPoints;
  final int totalAdRewardCount;

  const RewardCreditResult({
    required this.duplicated,
    required this.rewarded,
    required this.credits,
    required this.creatorPoints,
    required this.totalAdRewardCount,
  });
}

class AskResult {
  final String answer;
  final bool cached;
  final String? mode;
  final int? remainingCredits;
  final String? day;
  final int? uidUsed;
  final int? limit;

  const AskResult({
    required this.answer,
    required this.cached,
    required this.mode,
    required this.remainingCredits,
    required this.uidUsed,
    required this.day,
    required this.limit,
  });
}