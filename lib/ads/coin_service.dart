import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🪙 코인 관리 서비스
/// 역할:
/// - 현재 코인 로컬 보관
/// - 서버에서 내려준 광고 보상 상태(limit/used/remaining) 캐시
/// - UI에서 즉시 볼 수 있는 ValueNotifier 제공
///
/// 하지 않는 일:
/// - 하루 제한 판단
/// - 광고 보상 가능 여부 차단
/// - 서버 정책 결정
class CoinService {
  CoinService._();
  static final CoinService I = CoinService._();

  final ValueNotifier<int> coins = ValueNotifier<int>(0);

  static const _kKeyCoins = 'coins';

  static const _kKeyRewardDate = 'reward_status_date';
  static const _kKeyRewardLimit = 'reward_status_limit';
  static const _kKeyRewardUsed = 'reward_status_used';
  static const _kKeyRewardRemaining = 'reward_status_remaining';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    var savedCoins = prefs.getInt(_kKeyCoins) ?? 0;

    if (savedCoins < 0) {
      savedCoins = 0;
      await prefs.setInt(_kKeyCoins, 0);
    }

    coins.value = savedCoins;
    _initialized = true;
  }

  int get current => coins.value;

  Future<void> _saveCoins(int value) async {
    final prefs = await SharedPreferences.getInstance();
    final safeValue = value < 0 ? 0 : value;
    await prefs.setInt(_kKeyCoins, safeValue);
    coins.value = safeValue;
  }

  Future<void> setCoins(int value) async {
    await _saveCoins(value);
  }

  Future<int> addLocalCoin([int amount = 1]) async {
    await init();
    if (amount <= 0) return coins.value;

    final next = coins.value + amount;
    await _saveCoins(next);
    return next;
  }

  Future<int> refundOneCoin() async {
    return addLocalCoin(1);
  }

  Future<int> refundCoins(int amount) async {
    return addLocalCoin(amount);
  }

  Future<bool> useOneCoin() async {
    return useCoins(1);
  }

  Future<bool> useCoins(int amount) async {
    await init();

    if (amount <= 0) return true;
    if (coins.value < amount) return false;

    final next = coins.value - amount;
    await _saveCoins(next);
    return true;
  }

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 서버 reward/status 결과를 캐시
  Future<void> syncRewardStatus({
    required int limit,
    required int used,
    required int remaining,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKeyRewardDate, _todayKey());
    await prefs.setInt(_kKeyRewardLimit, limit);
    await prefs.setInt(_kKeyRewardUsed, used);
    await prefs.setInt(_kKeyRewardRemaining, remaining);
  }

  Future<RewardStatusCache?> getRewardStatusCache() async {
    final prefs = await SharedPreferences.getInstance();

    final savedDate = prefs.getString(_kKeyRewardDate);
    if (savedDate != _todayKey()) return null;

    final limit = prefs.getInt(_kKeyRewardLimit);
    final used = prefs.getInt(_kKeyRewardUsed);
    final remaining = prefs.getInt(_kKeyRewardRemaining);

    if (limit == null || used == null || remaining == null) {
      return null;
    }

    return RewardStatusCache(
      limit: limit,
      used: used,
      remaining: remaining,
    );
  }

  Future<void> clearRewardStatusCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKeyRewardDate);
    await prefs.remove(_kKeyRewardLimit);
    await prefs.remove(_kKeyRewardUsed);
    await prefs.remove(_kKeyRewardRemaining);
  }

  /// 서버 credit 성공 직후, 로컬 캐시를 즉시 갱신하고 싶을 때 사용
  Future<void> applyRewardStatusAfterCredit({
    required int previousLimit,
    required int previousUsed,
    required int previousRemaining,
  }) async {
    final nextUsed = previousUsed + 1;
    final nextRemaining = previousRemaining > 0 ? previousRemaining - 1 : 0;

    await syncRewardStatus(
      limit: previousLimit,
      used: nextUsed,
      remaining: nextRemaining,
    );
  }

  /// 필요시 완전 초기화용
  Future<void> resetAllForUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kKeyCoins, 0);
    await clearRewardStatusCache();
    coins.value = 0;
  }
}

class RewardStatusCache {
  final int limit;
  final int used;
  final int remaining;

  const RewardStatusCache({
    required this.limit,
    required this.used,
    required this.remaining,
  });
}