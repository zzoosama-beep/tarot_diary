import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore 구조:
/// users/{uid}/diaries/{yyyy-MM-dd}
///
/// 문서 필드:
/// - dateKey: "2026-01-26"
/// - date: Timestamp(해당 날짜 00:00)  ✅ 월별 dot 조회에 사용
/// - cardCount: int (1~3)
/// - cards: List<int> (카드 id. 예: [0, 12, 77]) ✅ 권장/최종
///   * 구버전 호환: 과거 문서에 cards가 List<String> (예: "00_thefool.png") 인 경우도
///     read/list 시 자동으로 List<int>로 변환해 반환함.
/// - beforeText: String
/// - afterText: String
/// - updatedAt: serverTimestamp()
class DiaryFirestore {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// DateTime -> "yyyy-MM-dd"
  static String dateKeyOf(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// dot 표시/쿼리용: 해당 날짜의 00:00
  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static CollectionReference<Map<String, dynamic>> _diariesCol(String uid) {
    return _db.collection('users').doc(uid).collection('diaries');
  }

  static DocumentReference<Map<String, dynamic>> docRef({
    required String uid,
    required DateTime date,
  }) {
    return _diariesCol(uid).doc(dateKeyOf(date));
  }

  /// -------------------------
  /// ✅ cards normalize helpers
  /// -------------------------

  /// "00_thefool.png" / "00-TheFool.png" / "00" / "0" -> 0
  static int? _cardIdFromString(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;

    // 맨 앞 연속 숫자 파싱 (예: "00_thefool.png" -> "00", "7_foo" -> "7")
    final m = RegExp(r'^(\d+)').firstMatch(t);
    if (m == null) return null;

    final n = int.tryParse(m.group(1)!);
    if (n == null) return null;
    return n;
  }

  /// Firestore에서 읽은 cards 필드를 List<int>로 통일
  static List<int> normalizeCardIds(dynamic raw) {
    if (raw is List) {
      final out = <int>[];

      for (final e in raw) {
        if (e is num) {
          out.add(e.toInt());
          continue;
        }
        final s = e?.toString();
        if (s == null) continue;

        final id = _cardIdFromString(s);
        if (id != null) out.add(id);
      }

      return out;
    }
    return <int>[];
  }

  static int _clampCardCount(dynamic v) {
    final n = (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '');
    return (n ?? 1).clamp(1, 3);
  }

  static String _str(dynamic v) => (v ?? '').toString();

  /// ✅ 해당 날짜 일기 로드 (없으면 null)
  /// 반환되는 Map의 'cards'는 항상 List<int>로 정규화됨 (구버전 문자열 저장도 자동 변환)
  static Future<Map<String, dynamic>?> read({
    required String uid,
    required DateTime date,
  }) async {
    final snap = await docRef(uid: uid, date: date).get();
    if (!snap.exists) return null;

    final data = snap.data() ?? <String, dynamic>{};

    final cc = _clampCardCount(data['cardCount']);
    final ids = normalizeCardIds(data['cards']).take(cc).toList();

    return {
      ...data,
      'cardCount': cc,
      'cards': ids, // ✅ 항상 List<int>
      'beforeText': _str(data['beforeText']),
      'afterText': _str(data['afterText']),
    };
  }

  /// ✅ 해당 날짜 일기 존재 여부
  static Future<bool> exists({
    required String uid,
    required DateTime date,
  }) async {
    final snap = await docRef(uid: uid, date: date).get();
    return snap.exists;
  }

  /// ✅ 저장(덮어쓰기/merge)
  /// - 하루 1개 문서 (docId가 dateKey)
  /// - date(Timestamp) 필드를 넣어 월별 dot 조회를 쉽게 함
  ///
  /// cards: List<int> (0~77)
  static Future<void> save({
    required String uid,
    required DateTime date,
    required int cardCount,
    required List<int> cards,
    required String beforeText,
    required String afterText,
  }) async {
    final d0 = dateOnly(date);
    final cc = cardCount.clamp(1, 3);

    final ids = cards.take(cc).toList();

    await docRef(uid: uid, date: date).set(
      {
        'dateKey': dateKeyOf(date),
        'date': Timestamp.fromDate(d0), // ✅ 중요: 월별 dot 조회
        'cardCount': cc,
        'cards': ids, // ✅ List<int>
        'beforeText': beforeText,
        'afterText': afterText,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// ✅ 삭제(원하면 사용)
  static Future<void> delete({
    required String uid,
    required DateTime date,
  }) async {
    await docRef(uid: uid, date: date).delete();
  }

  /// ✅ 월별 dot 표시용: 해당 월에 저장된 날짜들의 key Set 반환
  ///
  /// 반환값: yyyymmdd int set (예: 20260126)
  /// 캘린더에서 기존에 쓰던 _key(day)와 호환되게 해둠.
  static Future<Set<int>> listMonthEntryKeys({
    required String uid,
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    // ⚠️ date 필드를 Timestamp로 저장해야 이 쿼리가 됨.
    final q = await _diariesCol(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    int keyOf(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

    final keys = <int>{};
    for (final doc in q.docs) {
      final data = doc.data();
      final v = data['date'];
      if (v is Timestamp) {
        keys.add(keyOf(v.toDate()));
      } else {
        // 혹시 이전 버전 문서가 date 없이 저장된 경우 대비:
        // docId(yyyy-MM-dd)에서 파싱 시도
        final id = doc.id; // "yyyy-MM-dd"
        final parts = id.split('-');
        if (parts.length == 3) {
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final d = int.tryParse(parts[2]);
          if (y != null && m != null && d != null) {
            keys.add(y * 10000 + m * 100 + d);
          }
        }
      }
    }
    return keys;
  }

  /// ✅ (선택) 월의 모든 일기를 한 번에 가져오기
  /// 화면에 리스트 모드 만들 때 유용함.
  ///
  /// 반환되는 각 Map의 'cards'는 항상 List<int>로 정규화됨
  static Future<List<Map<String, dynamic>>> listMonthDocs({
    required String uid,
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final q = await _diariesCol(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: false)
        .get();

    return q.docs.map((doc) {
      final data = doc.data();

      final cc = _clampCardCount(data['cardCount']);
      final ids = normalizeCardIds(data['cards']).take(cc).toList();

      return {
        ...data,
        'cardCount': cc,
        'cards': ids,
        'beforeText': _str(data['beforeText']),
        'afterText': _str(data['afterText']),
      };
    }).toList();
  }
}
