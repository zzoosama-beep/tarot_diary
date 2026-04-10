import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ContactApiException implements Exception {
  final String userMessage;
  final Object? rawError;
  final int? statusCode;

  const ContactApiException(
      this.userMessage, {
        this.rawError,
        this.statusCode,
      });

  @override
  String toString() => userMessage;
}

class ContactApi {
  const ContactApi();

  static const String _endpoint = 'https://formspree.io/f/xwvraeed';

  Future<void> sendContact({
    required String replyEmail,
    required String message,
    required String appVersion,
    required String deviceInfo,
  }) async {
    final uri = Uri.parse(_endpoint);

    try {
      final res = await http
          .post(
        uri,
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'application/json',
        },
        body: jsonEncode({
          'email': replyEmail.trim(),
          'appVersion': appVersion.trim(),
          'deviceInfo': deviceInfo.trim(),
          'message': message.trim(),
          'source': 'dalnyang_flutter_app',
        }),
      )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return;
      }

      throw ContactApiException(
        '문의 전송에 실패했습니다.\n잠시 후 다시 시도해주세요.',
        rawError: res.body,
        statusCode: res.statusCode,
      );
    } on TimeoutException catch (e) {
      throw ContactApiException(
        '응답이 지연되고 있습니다.\n잠시 후 다시 시도해주세요.',
        rawError: e,
      );
    } on SocketException catch (e) {
      throw ContactApiException(
        '인터넷 연결을 확인한 뒤 다시 시도해주세요.',
        rawError: e,
      );
    } on HttpException catch (e) {
      throw ContactApiException(
        '서버와의 통신에 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
        rawError: e,
      );
    } on ContactApiException {
      rethrow;
    } catch (e) {
      throw ContactApiException(
        '문의 전송 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
        rawError: e,
      );
    }
  }
}