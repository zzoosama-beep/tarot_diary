import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../error/error_reporter.dart';

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

    final d = await openDatabase(path);
    return d;
  }

  Future<void> _ensureTables(Database d) async {
    await d.execute('''
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

  Map<String, dynamic> _normalizeRow(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'uid': (raw['uid'] ?? _localUid).toString(),
      'cardId': (raw['cardId'] is num)
          ? (raw['cardId'] as num).toInt()
          : int.tryParse('${raw['cardId']}') ?? 0,
      'title': (raw['title'] ?? '').toString(),
      'meaning': (raw['meaning'] ?? '').toString(),
      'myNote': (raw['myNote'] ?? '').toString(),
      'tags': (raw['tags'] ?? '').toString(),
      'updatedAt': (raw['updatedAt'] is num)
          ? (raw['updatedAt'] as num).toInt()
          : int.tryParse('${raw['updatedAt']}') ?? 0,
    };
  }

  // -------------------------------------------------------
  // Public API
  // -------------------------------------------------------

  Future<Map<String, dynamic>?> read({
    String uid = _localUid,
    required int cardId,
  }) async {
    final d = await db;

    try {
      await _ensureTables(d); // 🔥 추가

      final rows = await d.query(
        table,
        where: 'uid = ? AND cardId = ?',
        whereArgs: [uid, cardId],
        limit: 1,
      );

      if (rows.isEmpty) return null;
      return _normalizeRow(rows.first);
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'ArcanaLocal.read',
        error: e,
        stackTrace: st,
        extra: {
          'uid': uid,
          'cardId': cardId,
        },
      );
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

  Future<void> save({
    String uid = _localUid,
    required int cardId,
    String? title,
    required String meaning,
    required String myNote,
    required String tags,
  }) async {
    final d = await db;

    try {
      await _ensureTables(d);

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
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'ArcanaLocal.save',
        error: e,
        stackTrace: st,
        extra: {
          'uid': uid,
          'cardId': cardId,
        },
      );
      rethrow;
    }
  }

  Future<void> delete({
    String uid = _localUid,
    required int cardId,
  }) async {
    final d = await db;

    try {
      await _ensureTables(d);

      await d.delete(
        table,
        where: 'uid = ? AND cardId = ?',
        whereArgs: [uid, cardId],
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'ArcanaLocal.delete',
        error: e,
        stackTrace: st,
        extra: {
          'uid': uid,
          'cardId': cardId,
        },
      );
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listAll({
    String uid = _localUid,
  }) async {
    final d = await db;

    try {
      await _ensureTables(d); // 🔥 추가

      final rows = await d.query(
        table,
        where: 'uid = ?',
        whereArgs: [uid],
        orderBy: 'updatedAt DESC',
      );

      return rows.map(_normalizeRow).toList();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'ArcanaLocal.listAll',
        error: e,
        stackTrace: st,
        extra: {'uid': uid},
      );
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> listAllForBackup({
    String uid = _localUid,
  }) async {
    final d = await db;

    try {
      await _ensureTables(d);

      final rows = await d.query(
        table,
        where: 'uid = ?',
        whereArgs: [uid],
        orderBy: 'cardId ASC',
      );

      return rows.map(_normalizeRow).toList();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'ArcanaLocal.listAllForBackup',
        error: e,
        stackTrace: st,
        extra: {'uid': uid},
      );
      return const [];
    }
  }

  Future<void> close() async {
    final d = _db;
    _db = null;
    if (d != null) await d.close();
  }

  // -------------------------------------------------------
  // Debug (완전 분리)
  // -------------------------------------------------------

  Future<void> debugPrintAllRows({String tag = 'ARCANA_DB'}) async {
    if (!kDebugMode) return;

    final d = await db;

    final rows = await d.query(table, orderBy: 'updatedAt DESC');

    debugPrint('[$tag] rowCount=${rows.length}');
  }
}