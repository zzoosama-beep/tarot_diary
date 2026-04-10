import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../error/error_reporter.dart';

class DiaryException implements Exception {
  final String message;
  const DiaryException(this.message);

  @override
  String toString() => message;
}

/// ✅ SQLite(Local) 저장소
///
/// Firestore 대신 로컬 DB를 1안으로 사용.
/// - 기존 DiaryFirestore와 최대한 동일한 인터페이스 제공(화면 교체 최소화)
///
/// 테이블: diaries
/// - dateKey TEXT PRIMARY KEY  ("yyyy-MM-dd")
/// - dateInt INTEGER           (yyyymmdd, 예: 20260204)  ✅ 월 dot 조회 빠르게
/// - cardCount INTEGER         (1~3)
/// - cardsJson TEXT            (예: "[0,12,77]")
/// - beforeText TEXT
/// - afterText TEXT
/// - updatedAt INTEGER         (ms since epoch)
class DiaryLocal {
  DiaryLocal._();
  static final DiaryLocal instance = DiaryLocal._();

  static const String _dbName = 'tarot_diary.db';
  static const int _dbVersion = 1;

  static const String _t = 'diaries';

  Database? _db;
  Future<Database>? _opening;

  // -------------------------
  // ✅ Date helpers
  // -------------------------

  /// DateTime -> "yyyy-MM-dd"
  static String dateKeyOf(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// "yyyy-MM-dd" -> DateTime
  static DateTime dateFromKey(String key) {
    try {
      final parts = key.split('-');
      if (parts.length != 3) {
        throw const FormatException('Invalid dateKey');
      }
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      return DateTime(y, m, d);
    } catch (_) {
      return DateTime(1970, 1, 1);
    }
  }

  /// dot 표시/쿼리용: 해당 날짜의 00:00
  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// yyyymmdd int
  static int dateIntOf(DateTime dt) => dt.year * 10000 + dt.month * 100 + dt.day;

  /// yyyymmdd int -> DateTime
  static DateTime dateFromInt(int key) {
    final y = key ~/ 10000;
    final m = (key % 10000) ~/ 100;
    final d = key % 100;
    return DateTime(y, m, d);
  }

  // -------------------------
  // ✅ DB lifecycle
  // -------------------------

  Future<Database> _open() async {
    if (_db != null) return _db!;
    if (_opening != null) return _opening!;

    _opening = _openInternal();

    try {
      final db = await _opening!;
      _db = db;
      return db;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _openInternal() async {
    try {
      final base = await getDatabasesPath();
      final path = p.join(base, _dbName);

      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $_t (
              dateKey TEXT PRIMARY KEY,
              dateInt INTEGER NOT NULL,
              cardCount INTEGER NOT NULL,
              cardsJson TEXT NOT NULL,
              beforeText TEXT NOT NULL,
              afterText TEXT NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');

          // 월 dot / 월 리스트 조회 최적화
          await db.execute('CREATE INDEX idx_${_t}_dateInt ON $_t(dateInt);');
        },
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryLocal._open',
        error: e,
        stackTrace: st,
      );

      throw const DiaryException(
        '일기 저장소를 여는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// 앱 종료/복원 전에 DB 닫을 때 사용
  Future<void> close() async {
    final db = _db;
    _db = null;
    _opening = null;

    if (db == null) return;

    try {
      await db.close();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryLocal.close',
        error: e,
        stackTrace: st,
      );

      throw const DiaryException(
        '일기 저장소를 정리하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// 현재 db 파일 경로가 필요할 때(백업용) 쓰기 좋음
  Future<String> getDbPath() async {
    try {
      final base = await getDatabasesPath();
      return p.join(base, _dbName);
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryLocal.getDbPath',
        error: e,
        stackTrace: st,
      );

      throw const DiaryException(
        '데이터 경로를 확인하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  // -------------------------
  // ✅ cards normalize
  // -------------------------

  static int _clampCardCount(dynamic v) {
    final n = (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '');
    return (n ?? 1).clamp(1, 3);
  }

  static String _str(dynamic v) => (v ?? '').toString();

  /// JSON string -> List<int>
  static List<int> _decodeCards(String jsonStr) {
    try {
      final raw = jsonDecode(jsonStr);
      if (raw is List) {
        return raw
            .where((e) => e is num || e is String)
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .toList();
      }
    } catch (_) {}
    return <int>[];
  }

  /// List<int> -> JSON string
  static String _encodeCards(List<int> cards) {
    final safe = cards.map((e) => e.clamp(0, 77)).toList();
    return jsonEncode(safe);
  }

  Map<String, dynamic> _normalizeRowFromDb(Map<String, dynamic> r) {
    final key = _str(r['dateKey']);
    final d = key.isNotEmpty
        ? dateFromKey(key)
        : dateFromInt((r['dateInt'] is num) ? (r['dateInt'] as num).toInt() : 0);

    final cc = _clampCardCount(r['cardCount']);
    final ids = _decodeCards(_str(r['cardsJson'])).take(cc).toList();

    return {
      'dateKey': key,
      'date': dateOnly(d),
      'dateInt': dateIntOf(dateOnly(d)),
      'cardCount': cc,
      'cards': ids,
      'beforeText': _str(r['beforeText']),
      'afterText': _str(r['afterText']),
      'updatedAt': (r['updatedAt'] is num)
          ? (r['updatedAt'] as num).toInt()
          : int.tryParse(_str(r['updatedAt'])) ?? 0,
    };
  }

  // -------------------------
  // ✅ CRUD
  // -------------------------

  /// ✅ 해당 날짜 일기 로드 (없으면 null)
  /// 반환되는 Map의 'cards'는 항상 List<int>로 정규화됨
  Future<Map<String, dynamic>?> read({
    required String uid, // ✅ 호환용 (로컬은 사용 안 함)
    required DateTime date,
  }) async {
    try {
      final db = await _open();
      final key = dateKeyOf(dateOnly(date));

      final rows = await db.query(
        _t,
        where: 'dateKey = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (rows.isEmpty) return null;
      return _normalizeRowFromDb(rows.first);
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryLocal.read',
        error: e,
        stackTrace: st,
        extra: {
          'uid': uid,
          'date': date.toIso8601String(),
        },
      );

      if (e is DiaryException) rethrow;

      throw const DiaryException(
        '일기 데이터를 불러오는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// ✅ 해당 날짜 일기 존재 여부
  Future<bool> exists({
    required String uid, // 호환용
    required DateTime date,
  }) async {
    try {
      final db = await _open();
      final key = dateKeyOf(dateOnly(date));

      final rows = await db.rawQuery(
        'SELECT 1 FROM $_t WHERE dateKey = ? LIMIT 1',
        [key],
      );

      return rows.isNotEmpty;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryLocal.exists',
        error: e,
        stackTrace: st,
        extra: {
          'uid': uid,
          'date': date.toIso8601String(),
        },
      );

      if (e is DiaryException) rethrow;

      throw const DiaryException(
        '일기 존재 여부를 확인하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// ✅ 저장(덮어쓰기)
  /// cards: List<int> (0~77)
  Future<void> save({
    required String uid, // 호환용
    required DateTime date,
    required int cardCount,
    required List<int> cards,
    required String beforeText,
    required String afterText,
  }) async {
    try {
      final db = await _open();
      final d0 = dateOnly(date);
      final key = dateKeyOf(d0);
      final di = dateIntOf(d0);

      final cc = cardCount.clamp(1, 3);
      final ids = cards.take(cc).map((e) => e.clamp(0, 77)).toList();

      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(
        _t,
        {
          'dateKey': key,
          'dateInt': di,
          'cardCount': cc,
          'cardsJson': _encodeCards(ids),
          'beforeText': beforeText,
          'afterText': afterText,
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryLocal.save',
        error: e,
        stackTrace: st,
        extra: {
          'uid': uid,
          'date': date.toIso8601String(),
          'cardCount': cardCount,
          'cardsLength': cards.length,
        },
      );

      if (e is DiaryException) rethrow;

      throw const DiaryException(
        '일기를 저장하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// ✅ 삭제
  Future<void> delete({
    required String uid, // 호환용
    required DateTime date,
  }) async {
    try {
      final db = await _open();
      final key = dateKeyOf(dateOnly(date));
      await db.delete(_t, where: 'dateKey = ?', whereArgs: [key]);
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryLocal.delete',
        error: e,
        stackTrace: st,
        extra: {
          'uid': uid,
          'date': date.toIso8601String(),
        },
      );

      if (e is DiaryException) rethrow;

      throw const DiaryException(
        '일기를 삭제하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// ✅ 월별 dot 표시용: 해당 월에 저장된 날짜들의 key Set 반환
  /// 반환값: yyyymmdd int set (예: 20260126)
  Future<Set<int>> listMonthEntryKeys({
    required String uid, // 호환용
    required DateTime month,
  }) async {
    try {
      final db = await _open();

      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 1);

      final startKey = dateIntOf(start);
      final endKey = dateIntOf(end);

      final rows = await db.query(
        _t,
        columns: ['dateInt'],
        where: 'dateInt >= ? AND dateInt < ?',
        whereArgs: [startKey, endKey],
        orderBy: 'dateInt ASC',
      );

      final out = <int>{};
      for (final r in rows) {
        final v = r['dateInt'];
        if (v is int) out.add(v);
        if (v is num) out.add(v.toInt());
      }
      return out;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryLocal.listMonthEntryKeys',
        error: e,
        stackTrace: st,
        extra: {
          'uid': uid,
          'month': month.toIso8601String(),
        },
      );

      if (e is DiaryException) rethrow;

      throw const DiaryException(
        '월별 일기 목록을 불러오는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// ✅ 월의 모든 일기를 한 번에 가져오기
  /// 반환되는 각 Map의 'cards'는 항상 List<int>로 정규화됨
  Future<List<Map<String, dynamic>>> listMonthDocs({
    required String uid, // 호환용
    required DateTime month,
  }) async {
    try {
      final db = await _open();

      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 1);

      final startKey = dateIntOf(start);
      final endKey = dateIntOf(end);

      final rows = await db.query(
        _t,
        where: 'dateInt >= ? AND dateInt < ?',
        whereArgs: [startKey, endKey],
        orderBy: 'dateInt ASC',
      );

      return rows.map(_normalizeRowFromDb).toList();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryLocal.listMonthDocs',
        error: e,
        stackTrace: st,
        extra: {
          'uid': uid,
          'month': month.toIso8601String(),
        },
      );

      if (e is DiaryException) rethrow;

      throw const DiaryException(
        '월별 일기 데이터를 불러오는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// ✅ 백업용: 전체 일기 목록
  Future<List<Map<String, dynamic>>> listAllDocs({
    required String uid, // 호환용
  }) async {
    try {
      final db = await _open();

      final rows = await db.query(
        _t,
        orderBy: 'dateInt ASC',
      );

      return rows.map(_normalizeRowFromDb).toList();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DiaryLocal.listAllDocs',
        error: e,
        stackTrace: st,
        extra: {
          'uid': uid,
        },
      );

      if (e is DiaryException) rethrow;

      throw const DiaryException(
        '전체 일기 데이터를 불러오는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }
}