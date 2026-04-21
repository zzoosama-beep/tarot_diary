import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../error/error_reporter.dart';

class RewardedGate {
  RewardedGate._();

  static RewardedAd? _ad;
  static bool _loading = false;
  static bool _showing = false;

  static final ValueNotifier<bool> isReadyNotifier = ValueNotifier<bool>(false);

  static bool _sdkInitialized = false;
  static Future<void>? _initFuture;

  static DateTime? _lastLoadFailedAt;
  static DateTime? _lastLoadStartedAt;

  static const String _androidTest = 'ca-app-pub-3940256099942544/5224354917';
  static const String _iosTest = 'ca-app-pub-3940256099942544/1712485313';

  static const String _androidProd = 'ca-app-pub-5894860240201267/3391634063';
  static const String _iosProd = '여기에_ios_보상형_광고ID';

  static const Duration _loadCooldown = Duration(seconds: 10);

  // 실제 폰 테스트 안전용
  // 아직 기기 ID를 모르면 빈 배열로 둬도 됨.
  // 나중에 로그에서 얻은 test device id를 넣으면 됨.
  static const List<String> _testDeviceIds = <String>[
    // '여기에_네_테스트기기_ID',
  ];

  static String get unitId {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;

    if (kReleaseMode) {
      return isIos ? _iosProd : _androidProd;
    }

    return isIos ? _iosTest : _androidTest;
  }

  static bool get _hasValidProdUnitId {
    if (!kReleaseMode) return true;
    final id = unitId.trim();
    return id.isNotEmpty &&
        !id.contains('여기에_') &&
        id.startsWith('ca-app-pub-');
  }

  static bool get ready => _ad != null;
  static bool get isLoading => _loading;
  static bool get isShowing => _showing;

  static void _syncReadyNotifier() {
    final next = _ad != null;
    if (isReadyNotifier.value != next) {
      isReadyNotifier.value = next;
    }
  }

  static Future<void> ensureInitialized() {
    if (_sdkInitialized) return Future.value();

    _initFuture ??= () async {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: _testDeviceIds,
        ),
      );

      await MobileAds.instance.initialize();
      _sdkInitialized = true;
    }();

    return _initFuture!;
  }

  static void disposeCurrentAd() {
    _ad?.dispose();
    _ad = null;
    _loading = false;
    _showing = false;
    _syncReadyNotifier();
  }

  static Future<void>? _warmUpFuture;
  static bool _warmUpDone = false;

  static Future<void> warmUpOnce() {
    if (_warmUpDone) return Future.value();
    if (_warmUpFuture != null) return _warmUpFuture!;

    _warmUpFuture = () async {
      try {
        await warmUp();
        _warmUpDone = true;
      } catch (e, st) {
        await ErrorReporter.I.record(
          source: 'RewardedGate.warmUpOnce',
          error: e,
          stackTrace: st,
        );
        rethrow;
      } finally {
        _warmUpFuture = null;
      }
    }();

    return _warmUpFuture!;
  }

  static bool get hasWarmedUp => _warmUpDone;
  static bool get isWarmingUp => _warmUpFuture != null;

  static bool _isCoolingDown() {
    final failedAt = _lastLoadFailedAt;
    if (failedAt == null) return false;
    return DateTime.now().difference(failedAt) < _loadCooldown;
  }

  static Future<void> preload({bool force = false}) async {
    if (_loading || _ad != null || _showing) return;
    if (!force && _isCoolingDown()) return;

    if (!_hasValidProdUnitId) {
      await ErrorReporter.I.record(
        source: 'RewardedGate.preload.invalidProdUnitId',
        error: Exception('Rewarded ad unit id is missing in release mode'),
      );
      _ad = null;
      _loading = false;
      _syncReadyNotifier();
      return;
    }

    _loading = true;
    _lastLoadStartedAt = DateTime.now();
    _syncReadyNotifier();

    try {
      await ensureInitialized();

      RewardedAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _ad?.dispose();
            _ad = ad;
            _loading = false;
            _lastLoadFailedAt = null;
            _syncReadyNotifier();

            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                if (identical(_ad, ad)) {
                  _ad = null;
                }
                _showing = false;
                _loading = false;
                _syncReadyNotifier();
              },
              onAdFailedToShowFullScreenContent: (ad, err) async {
                ad.dispose();

                await ErrorReporter.I.record(
                  source: 'RewardedGate.onAdFailedToShow',
                  error: err,
                );

                if (identical(_ad, ad)) {
                  _ad = null;
                }
                _showing = false;
                _loading = false;
                _lastLoadFailedAt = DateTime.now();
                _syncReadyNotifier();
              },
              onAdShowedFullScreenContent: (ad) {},
              onAdImpression: (ad) {},
            );
          },
          onAdFailedToLoad: (error) async {
            await ErrorReporter.I.record(
              source: 'RewardedGate.onAdFailedToLoad',
              error: error,
            );

            _ad = null;
            _loading = false;
            _lastLoadFailedAt = DateTime.now();
            _syncReadyNotifier();
          },
        ),
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'RewardedGate.preload',
        error: e,
        stackTrace: st,
      );

      _ad = null;
      _loading = false;
      _lastLoadFailedAt = DateTime.now();
      _syncReadyNotifier();
    }
  }

  static Future<void> warmUp() async {
    await preload();
  }

  static Future<bool> ensureLoaded({
    Duration timeout = const Duration(seconds: 4),
    Duration tick = const Duration(milliseconds: 120),
  }) async {
    if (_ad != null) return true;

    if (!_loading) {
      await preload(force: true);
    }

    final sw = Stopwatch()..start();

    while (sw.elapsed < timeout) {
      if (_ad != null) {
        _syncReadyNotifier();
        return true;
      }
      await Future.delayed(tick);
    }

    _syncReadyNotifier();
    return _ad != null;
  }

  static Future<bool> confirmDialog(
      BuildContext context, {
        required String title,
        required String message,
        String cancelText = '취소',
        String okText = '광고를 보고 진행하시겠습니까?',
      }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(okText),
          ),
        ],
      ),
    );
    return ok == true;
  }

  static Future<bool> showForRewardResult(
      BuildContext context, {
        bool skipConfirm = false,
        String confirmTitle = '',
        String confirmMessage = '',
        String cancelText = '취소',
        String okText = '광고를 보고 진행하시겠습니까?',
        VoidCallback? onNotReady,
        void Function(Object error)? onShowFailed,
      }) async {
    if (_showing) return false;

    await ensureInitialized();

    final loaded = await ensureLoaded();
    if (!loaded) {
      onNotReady?.call();
      return false;
    }

    if (!skipConfirm) {
      final ok = await confirmDialog(
        context,
        title: confirmTitle,
        message: confirmMessage,
        cancelText: cancelText,
        okText: okText,
      );
      if (!ok) return false;

      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!context.mounted) return false;
    if (_showing) return false;

    final ad = _ad;
    if (ad == null) {
      onNotReady?.call();
      return false;
    }

    _showing = true;
    _ad = null;
    _syncReadyNotifier();

    bool rewarded = false;
    bool settled = false;
    final completer = Completer<bool>();

    Future<void> finishOnly() async {
      _showing = false;
      _loading = false;
      _syncReadyNotifier();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();

        if (!settled) {
          settled = true;
          await finishOnly();
          if (!completer.isCompleted) completer.complete(rewarded);
          return;
        }

        await finishOnly();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, err) async {
        ad.dispose();

        await ErrorReporter.I.record(
          source: 'RewardedGate.show_failed',
          error: err,
        );

        if (!settled) {
          settled = true;
          onShowFailed?.call(err);
          await finishOnly();
          if (!completer.isCompleted) completer.complete(false);
          return;
        }

        await finishOnly();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdShowedFullScreenContent: (ad) {},
      onAdImpression: (ad) {},
    );

    try {
      ad.show(
        onUserEarnedReward: (_, reward) {
          rewarded = true;
        },
      );

      return await completer.future;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'RewardedGate.show',
        error: e,
        stackTrace: st,
      );

      _showing = false;
      _syncReadyNotifier();
      onShowFailed?.call(e);
      if (!completer.isCompleted) completer.complete(false);
      return completer.future;
    }
  }
}