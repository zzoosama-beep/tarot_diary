import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static const _key = 'device_id';
  static const _storage = FlutterSecureStorage();

  static Future<String> getOrCreate() async {
    var id = await _storage.read(key: _key);
    if (id != null) return id;

    id = const Uuid().v4();
    await _storage.write(key: _key, value: id);
    return id;
  }
}
