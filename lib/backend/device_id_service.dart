import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../error/error_reporter.dart';

class DeviceIdException implements Exception {
  final String message;
  const DeviceIdException(this.message);

  @override
  String toString() => message;
}

class DeviceIdService {
  DeviceIdService._();

  static const _key = 'device_id';
  static const _storage = FlutterSecureStorage();

  static String? _cachedId;
  static Future<String>? _pending;

  static Future<String> getOrCreate() {
    if (_cachedId != null && _cachedId!.isNotEmpty) {
      return Future.value(_cachedId);
    }

    if (_pending != null) return _pending!;

    _pending = _loadOrCreate();
    return _pending!;
  }

  static Future<String> _loadOrCreate() async {
    try {
      final stored = await _storage.read(key: _key);

      if (stored != null && stored.isNotEmpty) {
        _cachedId = stored;
        _pending = null;
        return stored;
      }
    } catch (e, st) {
      _pending = null;

      await ErrorReporter.I.record(
        source: 'DeviceIdService.read',
        error: e,
        stackTrace: st,
      );

      throw const DeviceIdException(
        '기기 정보를 확인하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }

    final newId = const Uuid().v4();

    try {
      await _storage.write(key: _key, value: newId);
      _cachedId = newId;
      _pending = null;
      return newId;
    } catch (e, st) {
      _pending = null;

      await ErrorReporter.I.record(
        source: 'DeviceIdService.write',
        error: e,
        stackTrace: st,
        extra: {'generatedId': newId},
      );

      throw const DeviceIdException(
        '기기 정보를 저장하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }
}