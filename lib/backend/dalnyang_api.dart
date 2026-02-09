/// 챗지피티 사용 API
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// ✅ 유저에게 "안내만" 보여줄 사전정의(known) 예외
/// - 디버그(HTTP/code/raw) 노출 금지
class DalnyangKnownException implements Exception {
  final String userMessage;
  DalnyangKnownException(this.userMessage);

  @override
  String toString() => userMessage;
}

/// ✅ 우리가 모르는/돌발(unknown) 예외
/// - 디버그(HTTP/code/raw) 포함 가능
class DalnyangUnknownException implements Exception {
  final String message; // 유저 요약 문구(짧게)
  final String debugText; // HTTP/code/raw 등 디버그

  DalnyangUnknownException({
    required this.message,
    required this.debugText,
  });

  @override
  String toString() => '$message\n\n---\n$debugText';
}

class DalnyangApi {
  // emulator: 10.0.2.2 / real device: PC의 로컬IP로 바꿔야 함
  static const String baseUrl = 'http://10.0.2.2:8080';

  // -------------------------
  // Known 메시지(한 곳에서만 관리)
  // -------------------------
  static const String _msgNoCredits =
      '크레딧이 부족해.\n광고를 보고 크레딧을 충전한 뒤 다시 시도해줘!';

  static String dailyLimitAskMsg(int limit) =>
      '오늘 사용 가능한 횟수는 하루 ${limit}회까지야.\n오늘은 모두 사용했어. 내일 다시 시도해줘!';

  static String dailyLimitRewardMsg(int limit) =>
      '오늘 받을 수 있는 보상은 하루 ${limit}회까지야.\n오늘은 모두 사용했어. 내일 다시 시도해줘!';

  // -------------------------
  // Helpers
  // -------------------------
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
      debugText: _dbg(prefix: debugPrefix, status: status, code: code, raw: raw),
    );
  }

  static DalnyangUnknownException _unknownText({
    required String message,
    required String debugText,
  }) {
    return DalnyangUnknownException(message: message, debugText: debugText);
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

  // -------------------------
  // precheck (status 조회 후, 남은 횟수 없으면 Known throw)
  // -------------------------
  static Future<void> precheckRewardOrThrow({
    required String idToken,
    required String deviceId,
  }) async {
    final status = await getRewardStatus(idToken: idToken, deviceId: deviceId);
    if (status.remaining <= 0) {
      throw DalnyangKnownException(dailyLimitRewardMsg(status.limit));
    }
  }

  // -------------------------
  // 아르카나(편의 함수)
  // -------------------------
  static Future<String> askArcanaMeaning({
    required String idToken,
    required String deviceId,
    required String cardKoName,
    required String cardEnName,
  }) {
    const question = '이 카드의 의미를 도감용으로 정리해줘.';
    return ask(
      idToken: idToken,
      deviceId: deviceId,
      question: question,
      context: {
        'source': 'arcana',
        'card_ko': cardKoName,
        'card_en': cardEnName,
      },
    );
  }

  // -------------------------
  // API: Reward credit
  // -------------------------
  static Future<void> creditRewardedAd({
    required String idToken,
    required String deviceId,
    required String adEventId,
  }) async {
    final uri = Uri.parse('$baseUrl/rewarded-ad/credit');
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $idToken',
      'X-Device-Id': deviceId,
    };

    try {
      final res = await http
          .post(
        uri,
        headers: headers,
        body: jsonEncode({
          'device_id': deviceId,
          'ad_event_id': adEventId,
        }),
      )
          .timeout(const Duration(seconds: 20));

      final raw = utf8.decode(res.bodyBytes);
      final code = _extractErrorCode(raw);

      // ✅ known: 일일 보상 제한 → 서버 status로 limit 읽어와서 문구 생성
      if (res.statusCode == 429 || code == 'DAILY_LIMIT_UID' || code == 'DAILY_LIMIT_DEVICE') {
        final st = await getRewardStatus(idToken: idToken, deviceId: deviceId);
        throw DalnyangKnownException(dailyLimitRewardMsg(st.limit));
      }

      if (res.statusCode != 200) {
        throw _unknown(
          message: '보상 처리 중 문제가 생겼어.\n잠시 후 다시 시도해줘.',
          debugPrefix: 'REWARD',
          status: res.statusCode,
          code: code,
          raw: raw,
        );
      }

      final data = _decodeJsonOrThrow(
        raw: raw,
        userMessageOnFail: '보상 처리 중 문제가 생겼어.\n잠시 후 다시 시도해줘.',
        debugPrefix: 'REWARD',
        status: res.statusCode,
        code: code,
      );

      if (data is! Map || data['ok'] != true) {
        final err = (data is Map ? data['error'] : null)?.toString() ?? 'reward ok=false';

        if (err == 'DAILY_LIMIT_UID' || err == 'DAILY_LIMIT_DEVICE') {
          final st = await getRewardStatus(idToken: idToken, deviceId: deviceId);
          throw DalnyangKnownException(dailyLimitRewardMsg(st.limit));
        }

        throw _unknownText(
          message: '보상 처리 중 문제가 생겼어.\n잠시 후 다시 시도해줘.',
          debugText: 'REWARD ok=false\nerror=$err\n${_shortRaw(raw)}',
        );
      }
    } on SocketException catch (e) {
      throw _unknownText(
        message: '네트워크 연결이 불안정해.\n인터넷 상태를 확인해줘.',
        debugText: 'SocketException: $e\nbaseUrl=$baseUrl',
      );
    } on TimeoutException {
      throw _unknownText(
        message: '서버 응답이 너무 느려서 타임아웃이 났어.\n잠시 후 다시 시도해줘.',
        debugText: 'Timeout(20s)\nbaseUrl=$baseUrl',
      );
    }
  }

  // -------------------------
  // API: Reward status (precheck용)
  // -------------------------
  static Future<RewardStatus> getRewardStatus({
    required String idToken,
    required String deviceId,
  }) async {
    final uri = Uri.parse('$baseUrl/rewarded-ad/status');
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $idToken',
      'X-Device-Id': deviceId,
    };

    try {
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));
      final raw = utf8.decode(res.bodyBytes);
      final code = _extractErrorCode(raw);

      if (res.statusCode != 200) {
        throw _unknown(
          message: '사용 가능 횟수를 확인하지 못했어.\n잠시 후 다시 시도해줘.',
          debugPrefix: 'STATUS',
          status: res.statusCode,
          code: code,
          raw: raw,
        );
      }

      final data = _decodeJsonOrThrow(
        raw: raw,
        userMessageOnFail: '사용 가능 횟수를 확인하지 못했어.\n잠시 후 다시 시도해줘.',
        debugPrefix: 'STATUS',
        status: res.statusCode,
        code: code,
      );

      if (data is! Map || data['ok'] != true) {
        final err = (data is Map ? data['error'] : null)?.toString() ?? 'status ok=false';
        throw _unknownText(
          message: '사용 가능 횟수를 확인하지 못했어.\n잠시 후 다시 시도해줘.',
          debugText: 'STATUS ok=false\nerror=$err\n${_shortRaw(raw)}',
        );
      }

      return RewardStatus.fromJson(data as Map);
    } on SocketException catch (e) {
      throw _unknownText(
        message: '네트워크가 불안정해.\n인터넷 상태를 확인해줘.',
        debugText: 'SocketException: $e\nbaseUrl=$baseUrl',
      );
    } on TimeoutException {
      throw _unknownText(
        message: '서버 응답이 느려서 확인에 실패했어.\n잠시 후 다시 시도해줘.',
        debugText: 'Timeout(12s)\nbaseUrl=$baseUrl',
      );
    }
  }

  // -------------------------
  // API: Ask
  // -------------------------
  static Future<String> ask({
    required String idToken,
    required String deviceId,
    required String question,
    Map<String, dynamic>? context,
  }) async {
    final uri = Uri.parse('$baseUrl/dalnyang/ask');

    // 입력 검증은 Unknown으로 처리(개발/로직 문제)
    if (idToken.trim().isEmpty) {
      throw _unknownText(message: '로그인 상태를 확인해줘.', debugText: 'idToken is empty');
    }
    if (deviceId.trim().isEmpty) {
      throw _unknownText(message: '기기 정보를 확인해줘.', debugText: 'deviceId is empty (DeviceIdService)');
    }
    if (question.trim().isEmpty) {
      throw _unknownText(message: '질문 내용이 비어있어.', debugText: 'question is empty');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $idToken',
      'X-Device-Id': deviceId,
    };

    final body = <String, dynamic>{
      'device_id': deviceId,
      'question': question,
      if (context != null) 'context': context,
    };

    try {
      final res = await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(
        const Duration(seconds: 20),
      );

      final raw = utf8.decode(res.bodyBytes);
      final code = _extractErrorCode(raw);

      // ✅ known: 크레딧 부족
      if (res.statusCode == 402 || code == 'NO_CREDITS' || code == 'NO_CREDITS_RACE') {
        throw DalnyangKnownException(_msgNoCredits);
      }

      // ✅ known: 일일 제한 → 서버 응답 usage.limit를 우선 사용
      if (res.statusCode == 429 || code == 'DAILY_LIMIT_UID' || code == 'DAILY_LIMIT_DEVICE') {
        final lim = _extractLimitFromAskResponseBody(raw);
        if (lim != null) {
          throw DalnyangKnownException(dailyLimitAskMsg(lim));
        }
        throw DalnyangKnownException('오늘 사용 가능한 횟수를 모두 사용했어.\n내일 다시 시도해줘!');
      }

      if (res.statusCode != 200) {
        throw _unknown(
          message: '달냥이 호출에 실패했어.\n잠시 후 다시 시도해줘.',
          debugPrefix: 'ASK',
          status: res.statusCode,
          code: code,
          raw: raw,
        );
      }

      final data = _decodeJsonOrThrow(
        raw: raw,
        userMessageOnFail: '달냥이 응답을 읽는 데 실패했어.\n잠시 후 다시 시도해줘.',
        debugPrefix: 'ASK',
        status: res.statusCode,
        code: code,
      );

      if (data is! Map) {
        throw _unknownText(
          message: '달냥이 응답 형식이 이상해.\n잠시 후 다시 시도해줘.',
          debugText: 'ASK response not Map\n${_shortRaw(raw)}',
        );
      }

      if (data['ok'] != true) {
        final err = (data['error'] ?? '서버 ok=false').toString();

        // ✅ known: ok=false로 내려와도 안내만
        if (err == 'NO_CREDITS' || err == 'NO_CREDITS_RACE') {
          throw DalnyangKnownException(_msgNoCredits);
        }
        if (err == 'DAILY_LIMIT_UID' || err == 'DAILY_LIMIT_DEVICE') {
          // ok=false 케이스에서도 raw에서 limit 뽑아 시도
          final lim = _extractLimitFromAskResponseBody(raw);
          throw DalnyangKnownException(
            lim != null ? dailyLimitAskMsg(lim) : '오늘 사용 가능한 횟수를 모두 사용했어.\n내일 다시 시도해줘!',
          );
        }

        throw _unknownText(
          message: '달냥이 응답 처리 중 문제가 생겼어.\n잠시 후 다시 시도해줘.',
          debugText: 'ASK ok=false\nerror=$err\n${_shortRaw(raw)}',
        );
      }

      final ans = (data['answer'] ?? '').toString().trim();
      if (ans.isEmpty) {
        throw _unknownText(
          message: '달냥이 답변이 비어있어.\n잠시 후 다시 시도해줘.',
          debugText: 'answer empty\n${_shortRaw(raw)}',
        );
      }

      return ans;
    } on SocketException catch (e) {
      throw _unknownText(
        message: '네트워크 연결이 불안정해.\n인터넷 상태를 확인해줘.',
        debugText: 'SocketException: $e\nbaseUrl=$baseUrl',
      );
    } on TimeoutException {
      throw _unknownText(
        message: '서버 응답이 너무 느려서 타임아웃이 났어.\n잠시 후 다시 시도해줘.',
        debugText: 'Timeout(20s)\nbaseUrl=$baseUrl',
      );
    }
  }
}

class RewardStatus {
  final int limit;
  final int used;
  final int remaining;

  const RewardStatus({
    required this.limit,
    required this.used,
    required this.remaining,
  });

  factory RewardStatus.fromJson(Map m) {
    return RewardStatus(
      // ✅ 서버가 limit를 안 주면 "3"으로 회귀하지 않게 0 처리
      limit: (m['limit'] as num?)?.toInt() ?? 0,
      used: (m['used'] as num?)?.toInt() ?? 0,
      remaining: (m['remaining'] as num?)?.toInt() ?? 0,
    );
  }
}
