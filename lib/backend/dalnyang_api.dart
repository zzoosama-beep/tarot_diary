/// 챗지피티 사용 API
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;



class DalnyangApi {
  // emulator: 10.0.2.2 / real device: PC의 로컬IP로 바꿔야 함
  static const String baseUrl = 'http://10.0.2.2:8080';

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

    debugPrint('[REWARD][REQ] url=$uri');

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
    debugPrint('[REWARD][RES] status=${res.statusCode}');
    debugPrint('[REWARD][RES] body=$raw');

    if (res.statusCode != 200) {
      throw Exception('REWARD HTTP ${res.statusCode} - $raw');
    }

    final data = jsonDecode(raw);
    if (data is! Map || data['ok'] != true) {
      throw Exception((data is Map ? data['error'] : null) ?? 'reward ok=false');
    }
  }


  static Future<String> ask({
    required String idToken,
    required String deviceId,
    required String question,
    Map<String, dynamic>? context,
  }) async {
    final uri = Uri.parse('$baseUrl/dalnyang/ask');

    if (idToken.trim().isEmpty) {
      throw Exception('idToken이 비어있어. (로그인 토큰 획득 실패)');
    }
    if (deviceId.trim().isEmpty) {
      throw Exception('deviceId가 비어있어. (DeviceIdService 확인)');
    }
    if (question.trim().isEmpty) {
      throw Exception('question이 비어있어.');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $idToken',
      // ✅ 디버깅/서버 제한용(서버가 안 쓰면 무시)
      'X-Device-Id': deviceId,
    };

    // ✅ 요청 로그 (토큰 전체는 절대 찍지 말고 앞부분만)
    debugPrint('[DALNYANG][REQ] url=$uri');
    debugPrint('[DALNYANG][REQ] headers=${headers.keys.toList()}');
    final auth = headers['Authorization'] ?? '';
    debugPrint('[DALNYANG][REQ] authHead=${auth.length >= 28 ? auth.substring(0, 28) : auth}...');

    final body = <String, dynamic>{
      'device_id': deviceId,
      'question': question,
      if (context != null) 'context': context,
    };

    try {
      final res = await http
          .post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 20));

      final raw = utf8.decode(res.bodyBytes);

      // ✅ 응답 로그(너무 길면 앞부분만)
      debugPrint('[DALNYANG][RES] status=${res.statusCode}');
      debugPrint('[DALNYANG][RES] bodyHead=${raw.length > 300 ? raw.substring(0, 300) + '…' : raw}');

      // ✅ 402는 크레딧 이슈로 명확히 분기
      if (res.statusCode == 402) {
        throw Exception('NO_CREDITS(402) - $raw');
      }

      // ✅ status가 200이 아니면 원문을 그대로 보여줘야 디버깅 가능
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode} - $raw');
      }

      dynamic data;
      try {
        data = jsonDecode(raw);
      } catch (_) {
        throw Exception('JSON 파싱 실패: $raw');
      }

      if (data is! Map) {
        throw Exception('응답 형식 이상: $raw');
      }

      if (data['ok'] != true) {
        throw Exception((data['error'] ?? '서버 ok=false').toString());
      }

      final ans = (data['answer'] ?? '').toString().trim();
      if (ans.isEmpty) {
        throw Exception('서버가 answer를 비워서 보냈어: $raw');
      }

      return ans;
    } on SocketException catch (e) {
      throw Exception('네트워크 연결 실패: $e (baseUrl=$baseUrl)');
    } on TimeoutException {
      throw Exception('서버 응답이 너무 느려서 타임아웃(20s). 서버 상태 확인!');
    }
  }
}


