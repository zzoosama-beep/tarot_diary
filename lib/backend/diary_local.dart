import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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

  // -------------------------
  // ✅ Date helpers (Firestore와 동일)
  // -------------------------

  /// DateTime -> "yyyy-MM-dd"
  static String dateKeyOf(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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

    final base = await getDatabasesPath();
    final path = p.join(base, _dbName);

    _db = await openDatabase(
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

    return _db!;
  }

  /// 앱 종료/복원 전에 DB 닫을 때 사용
  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) {
      await db.close();
    }
  }

  /// 현재 db 파일 경로가 필요할 때(백업용) 쓰기 좋음
  Future<String> getDbPath() async {
    final base = await getDatabasesPath();
    return p.join(base, _dbName);
  }

  // -------------------------
  // ✅ cards normalize (Firestore 스타일)
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

  // -------------------------
  // ✅ CRUD (DiaryFirestore와 동일한 느낌)
  // -------------------------

  /// ✅ 해당 날짜 일기 로드 (없으면 null)
  /// 반환되는 Map의 'cards'는 항상 List<int>로 정규화됨
  Future<Map<String, dynamic>?> read({
    required String uid, // ✅ 호환용 (로컬은 사용 안 함)
    required DateTime date,
  }) async {
    final db = await _open();
    final key = dateKeyOf(date);

    final rows = await db.query(
      _t,
      where: 'dateKey = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final r = rows.first;

    final cc = _clampCardCount(r['cardCount']);
    final cards = _decodeCards(_str(r['cardsJson'])).take(cc).toList();

    return {
      'dateKey': key,
      // Firestore의 'date'(Timestamp) 대신, 로컬은 DateTime(00:00)을 함께 제공
      'date': dateOnly(date),
      'cardCount': cc,
      'cards': cards,
      'beforeText': _str(r['beforeText']),
      'afterText': _str(r['afterText']),
      // 로컬은 updatedAt을 int(ms)로 저장
      'updatedAt': r['updatedAt'],
    };
  }

  /// ✅ 해당 날짜 일기 존재 여부
  Future<bool> exists({
    required String uid, // 호환용
    required DateTime date,
  }) async {
    final db = await _open();
    final key = dateKeyOf(date);

    final rows = await db.rawQuery(
      'SELECT 1 FROM $_t WHERE dateKey = ? LIMIT 1',
      [key],
    );

    return rows.isNotEmpty;
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
  }

  /// ✅ 삭제
  Future<void> delete({
    required String uid, // 호환용
    required DateTime date,
  }) async {
    final db = await _open();
    final key = dateKeyOf(dateOnly(date));
    await db.delete(_t, where: 'dateKey = ?', whereArgs: [key]);
  }

  /// ✅ 월별 dot 표시용: 해당 월에 저장된 날짜들의 key Set 반환
  /// 반환값: yyyymmdd int set (예: 20260126)
  Future<Set<int>> listMonthEntryKeys({
    required String uid, // 호환용
    required DateTime month,
  }) async {
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
  }

  /// ✅ (선택) 월의 모든 일기를 한 번에 가져오기
  /// 반환되는 각 Map의 'cards'는 항상 List<int>로 정규화됨
  Future<List<Map<String, dynamic>>> listMonthDocs({
    required String uid, // 호환용
    required DateTime month,
  }) async {
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

    return rows.map((r) {
      final di = (r['dateInt'] is num) ? (r['dateInt'] as num).toInt() : 0;
      final d = dateFromInt(di);
      final key = _str(r['dateKey']);

      final cc = _clampCardCount(r['cardCount']);
      final ids = _decodeCards(_str(r['cardsJson'])).take(cc).toList();

      return {
        'dateKey': key,
        'date': dateOnly(d),
        'cardCount': cc,
        'cards': ids,
        'beforeText': _str(r['beforeText']),
        'afterText': _str(r['afterText']),
        'updatedAt': r['updatedAt'],
      };
    }).toList();
  }
}
