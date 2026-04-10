import 'dart:async';

import '../backup/drive_backup_service.dart';
import '../error/error_reporter.dart';
import 'arcana_local.dart';

class ArcanaRepo {
  ArcanaRepo._();
  static final ArcanaRepo I = ArcanaRepo._();

  final ArcanaLocal _local = ArcanaLocal.instance;

  static const String _localUid = 'local';
  static const int backupSchemaVersion = 1;

  Future<Map<String, dynamic>?> read({
    required int cardId,
  }) async {
    final row = await _local.read(uid: _localUid, cardId: cardId);
    if (row == null) return null;
    return _normalize(row);
  }

  Future<bool> exists({
    required int cardId,
  }) async {
    return _local.exists(uid: _localUid, cardId: cardId);
  }

  Future<void> save({
    required int cardId,
    String? title,
    required String meaning,
    required String myNote,
    required String tags,
  }) async {
    try {
      await _local.save(
        uid: _localUid,
        cardId: cardId.clamp(0, 77),
        title: title,
        meaning: meaning,
        myNote: myNote,
        tags: tags,
      );

      unawaited(DriveBackupService.I.notifyDataChanged());
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'ArcanaRepo.save',
        error: e,
        stackTrace: st,
        extra: {
          'cardId': cardId,
        },
      );
      rethrow;
    }
  }

  Future<void> delete({
    required int cardId,
  }) async {
    try {
      await _local.delete(uid: _localUid, cardId: cardId);

      unawaited(DriveBackupService.I.notifyDataChanged());
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'ArcanaRepo.delete',
        error: e,
        stackTrace: st,
        extra: {
          'cardId': cardId,
        },
      );
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listAll() async {
    final rows = await _local.listAll(uid: _localUid);
    return rows.map(_normalize).toList();
  }

  Future<Set<int>> listCardIdsHavingNotes() async {
    final rows = await _local.listAll(uid: _localUid);
    final set = <int>{};

    for (final r in rows) {
      final id = _toInt(r['cardId']);
      if (id != null && _isValidCardId(id)) {
        set.add(id);
      }
    }

    return set;
  }

  Future<bool> hasAnyData() async {
    final rows = await _local.listAll(uid: _localUid);
    return rows.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> exportAllForBackup() async {
    final rows = await _local.listAllForBackup(uid: _localUid);
    return rows.map(_toBackupJson).toList();
  }

  Map<String, dynamic> normalizeBackupJson(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);

    final parsedCardId = _toInt(map['cardId']);
    final safeCardId = (parsedCardId ?? -1);

    return <String, dynamic>{
      'cardId': safeCardId,
      'title': _stringOf(map['title']) ?? '',
      'meaning': _stringOf(map['meaning']) ?? '',
      'myNote': _stringOf(map['myNote']) ?? '',
      'tags': _stringOf(map['tags']) ?? '',
      'updatedAt': _toInt(map['updatedAt']) ?? 0,
    };
  }

  Future<void> importAllFromBackup(
      List<Map<String, dynamic>> items, {
        bool replaceExisting = true,
      }) async {
    try {
      if (replaceExisting) {
        final existing = await _local.listAll(uid: _localUid);
        for (final row in existing) {
          final cardId = _toInt(row['cardId']);
          if (cardId != null && _isValidCardId(cardId)) {
            await _local.delete(uid: _localUid, cardId: cardId);
          }
        }
      }

      for (final raw in items) {
        final row = normalizeBackupJson(raw);
        final cardId = row['cardId'] as int;

        if (!_isValidCardId(cardId)) {
          continue;
        }

        await _local.save(
          uid: _localUid,
          cardId: cardId,
          title: row['title'] as String,
          meaning: row['meaning'] as String,
          myNote: row['myNote'] as String,
          tags: row['tags'] as String,
        );
      }
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'ArcanaRepo.importAllFromBackup',
        error: e,
        stackTrace: st,
        extra: {
          'count': items.length,
          'replaceExisting': replaceExisting,
        },
      );
      rethrow;
    }
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);

    final parsedCardId = _toInt(map['cardId']);
    final safeCardId = _isValidCardId(parsedCardId) ? parsedCardId! : 0;

    return <String, dynamic>{
      'cardId': safeCardId,
      'title': _stringOf(map['title']) ?? '',
      'meaning': _stringOf(map['meaning']) ?? '',
      'myNote': _stringOf(map['myNote']) ?? '',
      'tags': _stringOf(map['tags']) ?? '',
      'updatedAt': _toInt(map['updatedAt']) ?? 0,
    };
  }

  Map<String, dynamic> _toBackupJson(Map<String, dynamic> raw) {
    final row = _normalize(raw);

    return <String, dynamic>{
      'schemaVersion': backupSchemaVersion,
      'cardId': (row['cardId'] as int).clamp(0, 77),
      'title': row['title'] as String,
      'meaning': row['meaning'] as String,
      'myNote': row['myNote'] as String,
      'tags': row['tags'] as String,
      'updatedAt': row['updatedAt'] as int,
    };
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String? _stringOf(dynamic v) {
    if (v == null) return null;
    return v.toString();
  }

  bool _isValidCardId(int? id) {
    if (id == null) return false;
    return id >= 0 && id <= 77;
  }
}