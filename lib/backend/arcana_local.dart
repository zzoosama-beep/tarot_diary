// lib/backend/arcana_local.dart
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// ✅ 카드 도감(Arcana) 기록 SQLite
/// - 카드(0~77) 1장당 1개의 기록 (업서트)
/// - DiaryLocal과 같은 DB 파일(tarot_diary.db)을 공유
///
/// ✅ 중요:
/// - 같은 DB 파일을 여러 Local이 열 때 version 충돌이 나기 쉬움
/// - 그래서 여기서는 version 없이 openDatabase(path)로 열고,
///   항상 CREATE TABLE IF NOT EXISTS로 테이블 존재를 보장한다.
class ArcanaLocal {
  ArcanaLocal._();
  static final ArcanaLocal instance = ArcanaLocal._();

  static const String _dbName = 'tarot_diary.db';
  static const String table = 'arcana_notes';

  static const String _localUid = 'local';

  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final base = await getDatabasesPath();
    final path = p.join(base, _dbName);

    // ✅ open은 "열기"만. 여기서 쓰기(CREATE TABLE) 절대 하지 않기.
    final d = await openDatabase(path);
    return d;
  }

  Future<void> _ensureTablesForWrite(Database d) async {
    // ✅ 쓰기(save/delete) 할 때만 테이블 보장
    await _createTables(d);
  }


  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        uid TEXT NOT NULL,
        cardId INTEGER NOT NULL,
        title TEXT,
        meaning TEXT,
        myNote TEXT,
        tags TEXT,
        updatedAt INTEGER NOT NULL,
        PRIMARY KEY (uid, cardId)
      )
    ''');
  }

  // -------------------------------------------------------
  // ✅ Public API
  // -------------------------------------------------------

  Future<Map<String, dynamic>?> read({
    String uid = _localUid,
    required int cardId,
  }) async {
    final d = await db;

    try {
      final rows = await d.query(
        table,
        where: 'uid = ? AND cardId = ?',
        whereArgs: [uid, cardId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first;
    } catch (e) {
      // ✅ 테이블이 없거나 read-only 등 어떤 이유든 "읽기"는 안전하게 null
      // ignore: avoid_print
      print('[ARCANA_DB] read failed (ignored): $e');
      return null;
    }
  }


  Future<bool> exists({
    String uid = _localUid,
    required int cardId,
  }) async {
    final r = await read(uid: uid, cardId: cardId);
    return r != null;
  }

  /// ✅ 저장(업서트)
  Future<void> save({
    String uid = _localUid,
    required int cardId,
    String? title,
    required String meaning,
    required String myNote,
    required String tags,
  }) async {
    final d = await db;

    await _ensureTablesForWrite(d);

    final now = DateTime.now().millisecondsSinceEpoch;

    await d.insert(
      table,
      {
        'uid': uid,
        'cardId': cardId,
        'title': title,
        'meaning': meaning,
        'myNote': myNote,
        'tags': tags,
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }


  Future<void> delete({
    String uid = _localUid,
    required int cardId,
  }) async {
    final d = await db;

    await _ensureTablesForWrite(d);

    await d.delete(
      table,
      where: 'uid = ? AND cardId = ?',
      whereArgs: [uid, cardId],
    );
  }



  /// ✅ 저장된 것만 전체 리스트(최근 수정순)
  Future<List<Map<String, dynamic>>> listAll({
    String uid = _localUid,
  }) async {
    final d = await db;

    try {
      return await d.query(
        table,
        where: 'uid = ?',
        whereArgs: [uid],
        orderBy: 'updatedAt DESC',
      );
    } catch (e) {
      // ✅ 테이블이 없거나 read-only여도 리스트 화면은 그냥 "0개"로
      // ignore: avoid_print
      print('[ARCANA_DB] listAll failed (return empty): $e');
      return const [];
    }
  }



  /// (선택) 앱 종료/로그아웃 등에 호출 가능
  Future<void> close() async {
    final d = _db;
    _db = null;
    if (d != null) await d.close();
  }

  // -------------------------------------------------------
  // ✅ DEBUG helpers (콘솔로 DB 상태 찍기)
  // -------------------------------------------------------
  Future<String> debugDbPath() async {
    final base = await getDatabasesPath();
    return p.join(base, _dbName);
  }

  Future<List<Map<String, dynamic>>> debugAllRowsRaw() async {
    final d = await db;

    try {
      return await d.query(table, orderBy: 'updatedAt DESC');
    } catch (e) {
      // ignore: avoid_print
      print('[ARCANA_DB] debugAllRowsRaw failed: $e');
      return const [];
    }
  }



  Future<void> debugPrintAllRows({String tag = 'ARCANA_DB'}) async {
    final path = await debugDbPath();
    final rows = await debugAllRowsRaw();

    // ignore: avoid_print
    print('[$tag] dbPath = $path');
    // ignore: avoid_print
    print('[$tag] table=$table rowCount=${rows.length}');

    for (final r in rows.take(80)) {
      // ignore: avoid_print
      print(
        '[$tag] row: uid=${r['uid']} cardId=${r['cardId']} title=${r['title']} '
            'meaningLen=${(r['meaning'] ?? '').toString().length} '
            'myNoteLen=${(r['myNote'] ?? '').toString().length} '
            'tags=${r['tags']} updatedAt=${r['updatedAt']}',
      );
    }
  }
}
