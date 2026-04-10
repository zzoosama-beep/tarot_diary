import 'dart:convert';

/// ✅ 백업 파일 전체 스키마 버전
/// - 구조가 바뀌면 여기 숫자를 올리고 importer에서 분기 처리
const int kBackupSchemaVersion = 1;

/// ✅ 백업 파일명들
const String kBackupManifestFileName = 'backup_manifest.json';
const String kBackupDiaryFileName = 'diary_backup.json';
const String kBackupArcanaFileName = 'arcana_backup.json';
const String kBackupSettingsFileName = 'settings_backup.json';

/// ✅ 앱 전체 백업 번들 메타 정보
class BackupManifest {
  final int schemaVersion;
  final String appId;
  final String appName;
  final String createdAtIso;
  final int createdAtMs;
  final int diaryCount;
  final int arcanaCount;
  final bool hasSettings;
  final String timezone;
  final String deviceType;

  const BackupManifest({
    required this.schemaVersion,
    required this.appId,
    required this.appName,
    required this.createdAtIso,
    required this.createdAtMs,
    required this.diaryCount,
    required this.arcanaCount,
    required this.hasSettings,
    required this.timezone,
    required this.deviceType,
  });

  factory BackupManifest.create({
    required int diaryCount,
    required int arcanaCount,
    required bool hasSettings,
    String appId = 'tarot_diary',
    String appName = 'Tarot Diary',
    String timezone = 'Asia/Seoul',
    String deviceType = 'android',
  }) {
    final now = DateTime.now();
    return BackupManifest(
      schemaVersion: kBackupSchemaVersion,
      appId: appId,
      appName: appName,
      createdAtIso: now.toIso8601String(),
      createdAtMs: now.millisecondsSinceEpoch,
      diaryCount: diaryCount,
      arcanaCount: arcanaCount,
      hasSettings: hasSettings,
      timezone: timezone,
      deviceType: deviceType,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'appId': appId,
      'appName': appName,
      'createdAtIso': createdAtIso,
      'createdAtMs': createdAtMs,
      'diaryCount': diaryCount,
      'arcanaCount': arcanaCount,
      'hasSettings': hasSettings,
      'timezone': timezone,
      'deviceType': deviceType,
    };
  }

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      schemaVersion: _asInt(json['schemaVersion']) ?? 1,
      appId: _asString(json['appId']) ?? 'tarot_diary',
      appName: _asString(json['appName']) ?? 'Tarot Diary',
      createdAtIso: _asString(json['createdAtIso']) ?? '',
      createdAtMs: _asInt(json['createdAtMs']) ?? 0,
      diaryCount: _asInt(json['diaryCount']) ?? 0,
      arcanaCount: _asInt(json['arcanaCount']) ?? 0,
      hasSettings: _asBool(json['hasSettings']) ?? false,
      timezone: _asString(json['timezone']) ?? 'Asia/Seoul',
      deviceType: _asString(json['deviceType']) ?? 'android',
    );
  }

  String encode() => jsonEncode(toJson());

  factory BackupManifest.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup manifest JSON');
    }
    return BackupManifest.fromJson(decoded);
  }
}

/// ✅ 일기 백업 단건
class DiaryBackupItem {
  final int schemaVersion;
  final String dateKey;
  final int cardCount;
  final List<int> cards;
  final String beforeText;
  final String afterText;
  final int updatedAt;

  const DiaryBackupItem({
    required this.schemaVersion,
    required this.dateKey,
    required this.cardCount,
    required this.cards,
    required this.beforeText,
    required this.afterText,
    required this.updatedAt,
  });

  factory DiaryBackupItem.fromJson(Map<String, dynamic> json) {
    final cards = _asIntList(json['cards']).take(3).toList(growable: false);
    final cardCount = (_asInt(json['cardCount']) ?? cards.length).clamp(1, 3);

    return DiaryBackupItem(
      schemaVersion: _asInt(json['schemaVersion']) ?? 1,
      dateKey: _asString(json['dateKey']) ?? '',
      cardCount: cardCount,
      cards: cards,
      beforeText: _asString(json['beforeText']) ?? '',
      afterText: _asString(json['afterText']) ?? '',
      updatedAt: _asInt(json['updatedAt']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'dateKey': dateKey,
      'cardCount': cardCount,
      'cards': cards.take(3).toList(growable: false),
      'beforeText': beforeText,
      'afterText': afterText,
      'updatedAt': updatedAt,
    };
  }
}

/// ✅ 아르카나 백업 단건
class ArcanaBackupItem {
  final int schemaVersion;
  final int cardId;
  final String title;
  final String meaning;
  final String myNote;
  final String tags;
  final int updatedAt;

  const ArcanaBackupItem({
    required this.schemaVersion,
    required this.cardId,
    required this.title,
    required this.meaning,
    required this.myNote,
    required this.tags,
    required this.updatedAt,
  });

  factory ArcanaBackupItem.fromJson(Map<String, dynamic> json) {
    return ArcanaBackupItem(
      schemaVersion: _asInt(json['schemaVersion']) ?? 1,
      cardId: (_asInt(json['cardId']) ?? 0).clamp(0, 77),
      title: _asString(json['title']) ?? '',
      meaning: _asString(json['meaning']) ?? '',
      myNote: _asString(json['myNote']) ?? '',
      tags: _asString(json['tags']) ?? '',
      updatedAt: _asInt(json['updatedAt']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'cardId': cardId.clamp(0, 77),
      'title': title,
      'meaning': meaning,
      'myNote': myNote,
      'tags': tags,
      'updatedAt': updatedAt,
    };
  }
}

/// ✅ 설정 백업
class SettingsBackupData {
  final int schemaVersion;
  final Map<String, dynamic> values;
  final int updatedAt;

  const SettingsBackupData({
    required this.schemaVersion,
    required this.values,
    required this.updatedAt,
  });

  factory SettingsBackupData.empty() {
    return SettingsBackupData(
      schemaVersion: kBackupSchemaVersion,
      values: const <String, dynamic>{},
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory SettingsBackupData.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'];
    return SettingsBackupData(
      schemaVersion: _asInt(json['schemaVersion']) ?? 1,
      values: rawValues is Map
          ? Map<String, dynamic>.from(rawValues)
          : <String, dynamic>{},
      updatedAt: _asInt(json['updatedAt']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'values': values,
      'updatedAt': updatedAt,
    };
  }
}

/// ✅ 백업 파일 전체 묶음
class BackupBundle {
  final BackupManifest manifest;
  final List<DiaryBackupItem> diaries;
  final List<ArcanaBackupItem> arcanaNotes;
  final SettingsBackupData? settings;

  const BackupBundle({
    required this.manifest,
    required this.diaries,
    required this.arcanaNotes,
    this.settings,
  });

  BackupBundle copyWith({
    BackupManifest? manifest,
    List<DiaryBackupItem>? diaries,
    List<ArcanaBackupItem>? arcanaNotes,
    SettingsBackupData? settings,
    bool clearSettings = false,
  }) {
    return BackupBundle(
      manifest: manifest ?? this.manifest,
      diaries: diaries ?? this.diaries,
      arcanaNotes: arcanaNotes ?? this.arcanaNotes,
      settings: clearSettings ? null : (settings ?? this.settings),
    );
  }

  Map<String, dynamic> toManifestJson() => manifest.toJson();

  List<Map<String, dynamic>> toDiaryJsonList() {
    return diaries.map((e) => e.toJson()).toList(growable: false);
  }

  List<Map<String, dynamic>> toArcanaJsonList() {
    return arcanaNotes.map((e) => e.toJson()).toList(growable: false);
  }

  Map<String, dynamic>? toSettingsJsonOrNull() {
    return settings?.toJson();
  }

  String encodeManifest() => jsonEncode(toManifestJson());

  String encodeDiaryList() => jsonEncode(toDiaryJsonList());

  String encodeArcanaList() => jsonEncode(toArcanaJsonList());

  String? encodeSettingsOrNull() {
    final map = toSettingsJsonOrNull();
    if (map == null) return null;
    return jsonEncode(map);
  }
}

/// ✅ exporter 결과 묶음
class BackupExportResult {
  final BackupBundle bundle;
  final String manifestJson;
  final String diaryJson;
  final String arcanaJson;
  final String? settingsJson;

  const BackupExportResult({
    required this.bundle,
    required this.manifestJson,
    required this.diaryJson,
    required this.arcanaJson,
    required this.settingsJson,
  });

  Map<String, String> toFileMap({
    bool includeSettings = true,
  }) {
    final out = <String, String>{
      kBackupManifestFileName: manifestJson,
      kBackupDiaryFileName: diaryJson,
      kBackupArcanaFileName: arcanaJson,
    };

    if (includeSettings && settingsJson != null) {
      out[kBackupSettingsFileName] = settingsJson!;
    }

    return out;
  }
}

/// ✅ 백업 용량 계산 결과
class BackupSizeReport {
  final int diaryCount;
  final int arcanaCount;
  final bool hasSettings;

  final int manifestBytes;
  final int diaryBytes;
  final int arcanaBytes;
  final int settingsBytes;
  final int totalBytes;

  final int gzManifestBytes;
  final int gzDiaryBytes;
  final int gzArcanaBytes;
  final int gzSettingsBytes;
  final int gzTotalBytes;

  const BackupSizeReport({
    required this.diaryCount,
    required this.arcanaCount,
    required this.hasSettings,
    required this.manifestBytes,
    required this.diaryBytes,
    required this.arcanaBytes,
    required this.settingsBytes,
    required this.totalBytes,
    required this.gzManifestBytes,
    required this.gzDiaryBytes,
    required this.gzArcanaBytes,
    required this.gzSettingsBytes,
    required this.gzTotalBytes,
  });

  double get totalKb => totalBytes / 1024.0;
  double get totalMb => totalBytes / (1024.0 * 1024.0);

  double get gzTotalKb => gzTotalBytes / 1024.0;
  double get gzTotalMb => gzTotalBytes / (1024.0 * 1024.0);
}

// -------------------------------------------------------
// ✅ helpers
// -------------------------------------------------------

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String? _asString(dynamic v) {
  if (v == null) return null;
  return v.toString();
}

bool? _asBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;

  final s = v.toString().trim().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;

  return null;
}

List<int> _asIntList(dynamic v) {
  if (v == null) return const <int>[];

  if (v is List) {
    return v.map(_asInt).whereType<int>().toList(growable: false);
  }

  return const <int>[];
}