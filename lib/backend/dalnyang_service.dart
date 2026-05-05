import 'dart:io';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ads/coin_service.dart';
import '../ads/rewarded_gate.dart';
import '../error/error_reporter.dart';
import 'dalnyang_api.dart';
import 'device_id_service.dart';

typedef DalnyangCardNameBuilder = String Function(int id);

class DalnyangService {
  DalnyangService._();

  static final Random _random = Random.secure();

  static const int _dailyAskCost = 1;
  static const int _arcanaAskCost = 1;

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[DalnyangService] $message');
    }
  }

  static Future<String?> askWithCoin({
    required BuildContext context,
    required List<int> pickedCardIds,
    required int cardCount,
    required DalnyangCardNameBuilder cardNameBuilder,
    VoidCallback? onThinkingStart,
    VoidCallback? onThinkingEnd,
  }) async {
    try {
      await CoinService.I.init();

      final cc = cardCount.clamp(1, 3);
      final originalIds = pickedCardIds.take(cc).toList();

      if (originalIds.length != cc) {
        throw DalnyangKnownException('카드 $cc장 선택이 완료되어야 합니다.');
      }

      final orderedIds = _sortByInterpretPriority(originalIds);
      final orderedKoCards = orderedIds.map(cardNameBuilder).toList();

      final canProceed = await _confirmAskFlow(
        context,
        cost: _dailyAskCost,
        title: '하루 흐름 해석',
      );
      if (!canProceed) return null;

      return _runAskWithServerValidation(
        context: context,
        title: '하루 흐름 해석',
        cost: _dailyAskCost,
        onThinkingStart: onThinkingStart,
        onThinkingEnd: onThinkingEnd,
        run: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            throw DalnyangKnownException(
              '로그인이 필요합니다.\n다시 로그인 후 시도해주세요.',
            );
          }

          final idToken = await user.getIdToken() ?? '';
          if (idToken.isEmpty) {
            throw DalnyangKnownException(
              '로그인 정보를 확인하지 못했습니다.\n다시 로그인 후 시도해주세요.',
            );
          }

          final deviceId = await DeviceIdService.getOrCreate();
          final question = orderedKoCards.join(', ');

          final idempotencyKey = _newIdempotencyKey(
            deviceId: deviceId,
            seed: question,
          );

          return DalnyangApi.askDetailed(
            idToken: idToken,
            deviceId: deviceId,
            idempotencyKey: idempotencyKey,
            question: question,
          );
        },
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DalnyangService.askWithCoin',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  static Future<String?> askArcanaWithCoin({
    required BuildContext context,
    required int cardId,
    required String cardKoName,
    required String cardEnName,
    VoidCallback? onThinkingStart,
    VoidCallback? onThinkingEnd,
  }) async {
    try {
      await CoinService.I.init();

      final canProceed = await _confirmAskFlow(
        context,
        cost: _arcanaAskCost,
        title: '아르카나 도감 정리',
      );
      if (!canProceed) return null;

      return _runAskWithServerValidation(
        context: context,
        title: '아르카나 도감 정리',
        cost: _arcanaAskCost,
        onThinkingStart: onThinkingStart,
        onThinkingEnd: onThinkingEnd,
        run: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            throw DalnyangKnownException(
              '로그인이 필요합니다.\n다시 로그인 후 시도해주세요.',
            );
          }

          final idToken = await user.getIdToken() ?? '';
          if (idToken.isEmpty) {
            throw DalnyangKnownException(
              '로그인 정보를 확인하지 못했습니다.\n다시 로그인 후 시도해주세요.',
            );
          }

          final deviceId = await DeviceIdService.getOrCreate();
          final idempotencyKey = _newIdempotencyKey(
            deviceId: deviceId,
            seed: 'arcana_$cardId',
          );

          return DalnyangApi.askDetailed(
            idToken: idToken,
            deviceId: deviceId,
            idempotencyKey: idempotencyKey,
            question: '이 카드의 의미를 도감용으로 정리해주세요.',
            context: {
              'source': 'arcana',
              'card_ko': cardKoName,
              'card_en': cardEnName,
            },
          );
        },
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DalnyangService.askArcanaWithCoin',
        error: e,
        stackTrace: st,
        extra: {
          'cardId': cardId,
        },
      );
      rethrow;
    }
  }

  static Future<String?> _runAskWithServerValidation({
    required BuildContext context,
    required String title,
    required int cost,
    required Future<AskResult> Function() run,
    VoidCallback? onThinkingStart,
    VoidCallback? onThinkingEnd,
  }) async {
    bool retriedAfterAd = false;

    while (true) {
      bool thinkingStarted = false;

      try {
        onThinkingStart?.call();
        thinkingStarted = true;

        final result = await run();

        if (result.remainingCredits != null) {
          await CoinService.I.setCoins(result.remainingCredits!);
          _log('ask success: synced coins=${result.remainingCredits}');
        }

        return result.answer;
      } on DalnyangKnownException {
        rethrow;
      } on DalnyangUnknownException catch (e, st) {
        await ErrorReporter.I.record(
          source: 'DalnyangService._runAskWithServerValidation.unknown',
          error: e,
          stackTrace: st,
          extra: {
            'title': title,
            'cost': cost,
            'retriedAfterAd': retriedAfterAd,
          },
        );

        if (_isNoCreditsError(e)) {
          await CoinService.I.setCoins(0);

          final status = await _fetchAndSyncRewardStatus();
          if (status.remaining <= 0) {
            await _showNoMoreAdsDialog(
              context,
              limit: status.limit,
            );
            return null;
          }

          if (retriedAfterAd) {
            throw DalnyangKnownException(
              '코인이 부족합니다.\n광고를 보고 다시 시도해주세요.',
            );
          }

          final goAd = await _showNoCoinDialog(
            context,
            currentCoins: 0,
            cost: cost,
            title: title,
          );
          if (!goAd) return null;

          final earned = await _ensureCoinsByAd(
            context,
            neededCoins: cost,
          );
          if (!earned) return null;

          retriedAfterAd = true;
          continue;
        }

        throw DalnyangKnownException(e.message);
      } catch (e, st) {
        await ErrorReporter.I.record(
          source: 'DalnyangService._runAskWithServerValidation',
          error: e,
          stackTrace: st,
          extra: {
            'title': title,
            'cost': cost,
            'retriedAfterAd': retriedAfterAd,
          },
        );

        if (_isNoCreditsError(e)) {
          await CoinService.I.setCoins(0);

          final status = await _fetchAndSyncRewardStatus();
          if (status.remaining <= 0) {
            await _showNoMoreAdsDialog(
              context,
              limit: status.limit,
            );
            return null;
          }

          if (retriedAfterAd) {
            throw DalnyangKnownException(
              '코인이 부족합니다.\n광고를 보고 다시 시도해주세요.',
            );
          }

          final goAd = await _showNoCoinDialog(
            context,
            currentCoins: 0,
            cost: cost,
            title: title,
          );
          if (!goAd) return null;

          final earned = await _ensureCoinsByAd(
            context,
            neededCoins: cost,
          );
          if (!earned) return null;

          retriedAfterAd = true;
          continue;
        }

        throw DalnyangKnownException(
          '요청을 처리하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
        );
      } finally {
        if (thinkingStarted) {
          onThinkingEnd?.call();
        }
      }
    }
  }

  static bool _isNoCreditsError(Object e) {
    if (e is DalnyangKnownException) {
      final raw = e.userMessage.toUpperCase();
      return raw.contains('NO_CREDITS') || raw.contains('코인이 부족');
    }

    if (e is DalnyangUnknownException) {
      final raw = '${e.message}\n${e.debugText}'.toUpperCase();
      return raw.contains('NO_CREDITS') || raw.contains('402');
    }

    final raw = e.toString().toUpperCase();
    return raw.contains('NO_CREDITS') || raw.contains('402');
  }

  static List<int> _sortByInterpretPriority(List<int> ids) {
    final indexed = ids.asMap().entries.map((e) {
      return _IndexedCard(
        originalIndex: e.key,
        cardId: e.value,
        priority: _cardInterpretPriority(e.value),
      );
    }).toList();

    indexed.sort((a, b) {
      final byPriority = a.priority.compareTo(b.priority);
      if (byPriority != 0) return byPriority;
      return a.originalIndex.compareTo(b.originalIndex);
    });

    return indexed.map((e) => e.cardId).toList();
  }

  static int _cardInterpretPriority(int cardId) {
    if (cardId >= 0 && cardId <= 21) {
      return 0;
    }

    if (cardId >= 22) {
      final offsetInSuit = (cardId - 22) % 14;

      if (offsetInSuit >= 10) {
        return 1;
      }

      return 2;
    }

    return 9;
  }

  static Future<bool> _confirmAskFlow(
      BuildContext context, {
        required int cost,
        required String title,
      }) async {
    await CoinService.I.init();

    final currentCoins = CoinService.I.current;

    if (currentCoins >= cost) {
      return _showUseCoinDialog(
        context,
        currentCoins: currentCoins,
        cost: cost,
        title: title,
      );
    }

    final status = await _fetchAndSyncRewardStatus();

    if (status.remaining <= 0) {
      await CoinService.I.setCoins(0);
      await _showNoMoreAdsDialog(
        context,
        limit: status.limit,
      );
      return false;
    }

    final goAd = await _showNoCoinDialog(
      context,
      currentCoins: currentCoins,
      cost: cost,
      title: title,
    );
    if (!goAd) return false;

    final earned = await _ensureCoinsByAd(
      context,
      neededCoins: cost - currentCoins,
    );
    if (!earned) return false;

    final refreshedCoins = CoinService.I.current;
    if (refreshedCoins < cost) {
      throw DalnyangKnownException(
        '코인이 아직 부족합니다.\n광고를 더 본 뒤 다시 시도해주세요.',
      );
    }

    return true;
  }

  static Future<RewardStatusCache> _fetchAndSyncRewardStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw DalnyangKnownException(
        '로그인이 필요합니다.\n다시 로그인 후 시도해주세요.',
      );
    }

    final idToken = await user.getIdToken() ?? '';
    if (idToken.isEmpty) {
      throw DalnyangKnownException(
        '로그인 정보를 확인하지 못했습니다.\n다시 로그인 후 시도해주세요.',
      );
    }

    final deviceId = await DeviceIdService.getOrCreate();

    final status = await DalnyangApi.getRewardStatus(
      idToken: idToken,
      deviceId: deviceId,
    );

    await CoinService.I.syncRewardStatus(
      limit: status.limit,
      used: status.used,
      remaining: status.remaining,
    );

    return RewardStatusCache(
      limit: status.limit,
      used: status.used,
      remaining: status.remaining,
    );
  }

  static Future<bool> _showNoCoinDialog(
      BuildContext context, {
        required int currentCoins,
        required int cost,
        required String title,
      }) async {
    RewardStatusCache? cache = await CoinService.I.getRewardStatusCache();

    if (cache == null) {
      try {
        cache = await _fetchAndSyncRewardStatus();
      } catch (e, st) {
        await ErrorReporter.I.record(
          source: 'DalnyangService._showNoCoinDialog.fetchRewardStatus',
          error: e,
          stackTrace: st,
        );
      }
    }

    String remainText = '확인 중입니다.';
    if (cache != null) {
      remainText = '${cache.remaining}회';
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          title: Row(
            children: const [
              Text('🐱'),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '코인이 부족합니다',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            '$title에는 코인 $cost개가 필요합니다.\n'
                '광고 1회당 코인 1개를 받을 수 있습니다.\n\n'
                '오늘 남은 광고 보상: $remainText',
            style: const TextStyle(
              fontSize: 14.0,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                '취소',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                '광고 보고 코인 받기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  static Future<bool> _showUseCoinDialog(
      BuildContext context, {
        required int currentCoins,
        required int cost,
        required String title,
      }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            '코인 사용',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '$title에 코인 $cost개를 사용합니다.\n'
                '현재 보유 코인: $currentCoins개',
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('사용하기'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  static Future<bool> _ensureCoinsByAd(
      BuildContext context, {
        required int neededCoins,
      }) async {
    await CoinService.I.init();

    if (neededCoins <= 0 && CoinService.I.current > 0) {
      return true;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw DalnyangKnownException(
        '로그인이 필요합니다.\n다시 로그인 후 시도해주세요.',
      );
    }

    final idToken = await user.getIdToken() ?? '';
    if (idToken.isEmpty) {
      throw DalnyangKnownException(
        '로그인 정보를 확인하지 못했습니다.\n다시 로그인 후 시도해주세요.',
      );
    }

    final deviceId = await DeviceIdService.getOrCreate();

    final status = await DalnyangApi.getRewardStatus(
      idToken: idToken,
      deviceId: deviceId,
    );

    await CoinService.I.syncRewardStatus(
      limit: status.limit,
      used: status.used,
      remaining: status.remaining,
    );

    if (status.remaining <= 0) {
      await CoinService.I.setCoins(0);
      await _showNoMoreAdsDialog(
        context,
        limit: status.limit,
      );
      return false;
    }

    final watched = await RewardedGate.showForRewardResult(
      context,
      skipConfirm: true,
      confirmTitle: '광고 보고 진행',
      confirmMessage: '광고를 보면 코인 1개를 받을 수 있습니다.',
      cancelText: '취소',
      okText: '광고 보기',
      onNotReady: () {
        throw DalnyangKnownException(
          '광고가 아직 준비되지 않았습니다.\n잠시 후 다시 시도해주세요.',
        );
      },
      onShowFailed: (error) {
        throw DalnyangKnownException(
          '광고를 열지 못했습니다.\n잠시 후 다시 시도해주세요.',
        );
      },
    );

    if (!watched) return false;

    final adEventId = _newAdEventId(deviceId: deviceId);
    _log('creditRewardedAd start');

    final creditResult = await DalnyangApi.creditRewardedAd(
      idToken: idToken,
      deviceId: deviceId,
      adEventId: adEventId,
      adType: 'rewarded',
      status: 'rewarded',
      platform: Platform.isIOS ? 'ios' : 'android',
    );

    _log(
      'creditRewardedAd success: duplicated=${creditResult.duplicated}, '
          'rewarded=${creditResult.rewarded}, credits=${creditResult.credits}',
    );

    await CoinService.I.setCoins(creditResult.credits);

    await CoinService.I.applyRewardStatusAfterCredit(
      previousLimit: status.limit,
      previousUsed: status.used,
      previousRemaining: status.remaining,
    );

    return CoinService.I.current >= 1;
  }

  static String _newIdempotencyKey({
    required String deviceId,
    required String seed,
  }) {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final randA = _random.nextInt(0x7fffffff).toRadixString(16);
    final randB = _random.nextInt(0x7fffffff).toRadixString(16);
    final sLen = seed.length.toRadixString(16);

    return 'ask_${deviceId}_${now}_${sLen}${randA}${randB}';
  }

  static String _newAdEventId({
    required String deviceId,
  }) {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final randA = _random.nextInt(0x7fffffff).toRadixString(16);
    final randB = _random.nextInt(0x7fffffff).toRadixString(16);

    return 'ad_${deviceId}_$now$randA$randB';
  }

  static Future<void> _showNoMoreAdsDialog(
      BuildContext context, {
        required int limit,
      }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            '안내',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            '오늘 시청 가능한 광고 횟수를\n모두 사용하셨어요.\n내일 다시 이용해 주세요.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                '확인',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IndexedCard {
  final int originalIndex;
  final int cardId;
  final int priority;

  const _IndexedCard({
    required this.originalIndex,
    required this.cardId,
    required this.priority,
  });
}