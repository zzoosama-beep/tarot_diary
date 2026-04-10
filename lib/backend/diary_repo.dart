import 'dart:async';

import '../backup/drive_backup_service.dart';
import '../error/error_reporter.dart';
import 'diary_local.dart';

class DiaryRepo {
  DiaryRepo._();
  static final DiaryRepo I = DiaryRepo._();

  final DiaryLocal _local = DiaryLocal.instance;

  static const String _uid = 'local';
  static const int backupSchemaVersion = 1;

  String dateKeyOf(DateTime dt) => DiaryLocal.dateKeyOf(dt);
  DateTime dateOnly(DateTime dt) => DiaryLocal.dateOnly(dt);
  DateTime dateFromKey(String key) => DiaryLocal.dateFromKey(key);

  Future<Map<String, dynamic>?> read({
    required DateTime date,
  }) async {
    try {
      final row = await _local.read(uid: _uid, date: date);
      return normalizeRow(row);
    } on DiaryException {
      rethrow;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryRepo.read',
        error: e,
        stackTrace: st,
        extra: {'date': date.toIso8601String()},
      );

      throw const DiaryException(
        '일기 데이터를 불러오는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  Future<bool> exists({
    required DateTime date,
  }) async {
    try {
      return await _local.exists(uid: _uid, date: date);
    } on DiaryException {
      rethrow;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryRepo.exists',
        error: e,
        stackTrace: st,
        extra: {'date': date.toIso8601String()},
      );

      throw const DiaryException(
        '일기 존재 여부를 확인하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  Future<void> save({
    required DateTime date,
    required int cardCount,
    required List<int> cards,
    required String beforeText,
    required String afterText,
  }) async {
    try {
      await _local.save(
        uid: _uid,
        date: date,
        cardCount: cardCount,
        cards: cards,
        beforeText: beforeText,
        afterText: afterText,
      );

      unawaited(DriveBackupService.I.notifyDataChanged());
    } on DiaryException {
      rethrow;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryRepo.save',
        error: e,
        stackTrace: st,
        extra: {
          'date': date.toIso8601String(),
          'cardCount': cardCount,
        },
      );

      throw const DiaryException(
        '일기를 저장하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  Future<void> delete({
    required DateTime date,
  }) async {
    try {
      await _local.delete(uid: _uid, date: date);

      unawaited(DriveBackupService.I.notifyDataChanged());
    } on DiaryException {
      rethrow;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryRepo.delete',
        error: e,
        stackTrace: st,
        extra: {'date': date.toIso8601String()},
      );

      throw const DiaryException(
        '일기를 삭제하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  Future<bool> hasAnyData() async {
    try {
      final rows = await _local.listAllDocs(uid: _uid);
      return rows.isNotEmpty;
    } on DiaryException {
      rethrow;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryRepo.hasAnyData',
        error: e,
        stackTrace: st,
      );

      throw const DiaryException(
        '일기 데이터 존재 여부를 확인하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  Future<void> importAllFromBackup(
      List<Map<String, dynamic>> items, {
        bool replaceExisting = true,
      }) async {
    try {
      if (replaceExisting) {
        final existing = await _local.listAllDocs(uid: _uid);
        for (final row in existing) {
          final dateKey = _stringOf(row['dateKey']) ?? '';
          if (!_isValidDateKey(dateKey)) continue;
          await _local.delete(uid: _uid, date: dateFromKey(dateKey));
        }
      }

      for (final raw in items) {
        final row = normalizeBackupJson(raw);
        final dateKey = row['dateKey'] as String;

        if (!_isValidDateKey(dateKey)) {
          continue;
        }

        final cards = List<int>.from(row['cards'] as List);
        final safeCards = cards.take(3).map((e) => e.clamp(0, 77)).toList();
        final safeCardCount =
        (row['cardCount'] as int).clamp(1, 3);

        await _local.save(
          uid: _uid,
          date: dateFromKey(dateKey),
          cardCount: safeCards.isEmpty ? 1 : safeCardCount,
          cards: safeCards,
          beforeText: row['beforeText'] as String,
          afterText: row['afterText'] as String,
        );
      }
    } on DiaryException {
      rethrow;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryRepo.importAllFromBackup',
        error: e,
        stackTrace: st,
        extra: {
          'count': items.length,
          'replaceExisting': replaceExisting,
        },
      );

      throw const DiaryException(
        '백업 데이터를 복원하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  Future<Set<int>> listMonthEntryKeys({
    required DateTime month,
  }) async {
    try {
      return await _local.listMonthEntryKeys(uid: _uid, month: month);
    } on DiaryException {
      rethrow;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryRepo.listMonthEntryKeys',
        error: e,
        stackTrace: st,
        extra: {'month': month.toIso8601String()},
      );

      throw const DiaryException(
        '월별 데이터를 불러오는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> listMonthDocs({
    required DateTime month,
  }) async {
    try {
      final rows = await _local.listMonthDocs(uid: _uid, month: month);
      return rows.map(normalizeRowNotNull).toList();
    } on DiaryException {
      rethrow;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryRepo.listMonthDocs',
        error: e,
        stackTrace: st,
        extra: {'month': month.toIso8601String()},
      );

      throw const DiaryException(
        '월별 일기 데이터를 불러오는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> exportAllForBackup() async {
    try {
      final rows = await _local.listAllDocs(uid: _uid);
      return rows.map(toBackupJson).toList();
    } on DiaryException {
      rethrow;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryRepo.exportAllForBackup',
        error: e,
        stackTrace: st,
      );

      throw const DiaryException(
        '백업 데이터를 준비하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  Map<String, dynamic>? normalizeRow(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    return normalizeRowNotNull(raw);
  }

  Map<String, dynamic> normalizeRowNotNull(Map<String, dynamic> raw) {
    final row = Map<String, dynamic>.from(raw);

    row['dateKey'] = _stringOf(row['dateKey']) ?? '';
    row['cards'] = cardsOf(row);

    final cards = List<int>.from(row['cards'] as List);
    final fallbackCount = cards.isEmpty ? 1 : cards.length;
    row['cardCount'] = (_toInt(row['cardCount']) ?? fallbackCount).clamp(1, 3);

    row['beforeText'] = _stringOf(row['beforeText']) ?? '';
    row['afterText'] = _stringOf(row['afterText']) ?? '';
    row['updatedAt'] = _toInt(row['updatedAt']) ?? 0;

    final dateValue = row['date'];
    if (dateValue is! DateTime) {
      final key = _stringOf(row['dateKey']) ?? '';
      row['date'] = _isValidDateKey(key)
          ? dateFromKey(key)
          : DateTime(1970, 1, 1);
    }

    return row;
  }

  Map<String, dynamic> toBackupJson(Map<String, dynamic> raw) {
    final row = normalizeRowNotNull(raw);
    final cards = cardsOf(row);
    final safeCount =
    (_toInt(row['cardCount']) ?? (cards.isEmpty ? 1 : cards.length))
        .clamp(1, 3);

    return <String, dynamic>{
      'schemaVersion': backupSchemaVersion,
      'dateKey': _stringOf(row['dateKey']) ?? '',
      'cardCount': safeCount,
      'cards': cards.take(3).toList(),
      'beforeText': _stringOf(row['beforeText']) ?? '',
      'afterText': _stringOf(row['afterText']) ?? '',
      'updatedAt': _toInt(row['updatedAt']) ?? 0,
    };
  }

  Map<String, dynamic> normalizeBackupJson(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);

    final dateKey = (_stringOf(map['dateKey']) ?? '').trim();
    final cards = _toIntList(map['cards']).take(3).toList();

    final parsedCount = _toInt(map['cardCount']);
    final fallbackCount = cards.isEmpty ? 1 : cards.length;
    final safeCardCount = (parsedCount ?? fallbackCount).clamp(1, 3);

    return <String, dynamic>{
      'dateKey': dateKey,
      'date': _isValidDateKey(dateKey)
          ? dateFromKey(dateKey)
          : DateTime(1970, 1, 1),
      'cardCount': safeCardCount,
      'cards': cards,
      'beforeText': _stringOf(map['beforeText']) ?? '',
      'afterText': _stringOf(map['afterText']) ?? '',
      'updatedAt': _toInt(map['updatedAt']) ?? 0,
    };
  }

  List<int> cardsOf(Map<String, dynamic> row) {
    return _toIntList(row['cards']).take(3).toList();
  }

  List<int> _toIntList(dynamic value) {
    if (value == null) return <int>[];

    if (value is List) {
      return value
          .map((e) => _toInt(e))
          .whereType<int>()
          .map((e) => e.clamp(0, 77))
          .toList();
    }

    return <int>[];
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

  bool _isValidDateKey(String key) {
    if (key.isEmpty) return false;

    final reg = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!reg.hasMatch(key)) return false;

    final dt = DateTime.tryParse(key);
    if (dt == null) return false;

    return DiaryLocal.dateKeyOf(dt) == key;
  }
}