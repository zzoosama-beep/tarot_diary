import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

typedef RewardCallback = Future<void> Function();

class RewardedGate {
  RewardedGate._();

  static RewardedAd? _ad;
  static bool _loading = false;

  // ✅ 테스트 유닛(개발용)
  static const String _androidTest = 'ca-app-pub-3940256099942544/5224354917';
  static const String _iosTest = 'ca-app-pub-3940256099942544/1712485313';

  static String unitId(TargetPlatform platform) =>
      platform == TargetPlatform.iOS ? _iosTest : _androidTest;

  static bool get ready => _ad != null;

  static void preload(BuildContext context) {
    if (_loading || _ad != null) return;
    _loading = true;

    RewardedAd.load(
      adUnitId: unitId(Theme.of(context).platform),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;

          // 여기서는 "기본" callback만 세팅 (showAndReward에서 다시 덮어씀)
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _ad = null;
              preload(context);
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _ad = null;
              _loading = false;
              preload(context);
            },
          );
        },
        onAdFailedToLoad: (_) {
          _ad = null;
          _loading = false;
        },
      ),
    );
  }

  static Future<bool> confirmDialog(
      BuildContext context, {
        required String title,
        required String message,
        String cancelText = '취소',
        String okText = '광고 보고 진행',
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

  static Future<void> showAndReward(
      BuildContext context, {
        required String confirmTitle,
        required String confirmMessage,
        required RewardCallback onRewardEarned,

        /// ✅ 광고가 준비 안 됐을 때
        VoidCallback? onNotReady,

        /// ✅ 광고를 끝까지 안 봐서 보상 못 받았을 때
        VoidCallback? onRewardNotEarned,

        /// ✅ 광고 표시 자체가 실패했을 때
        void Function(Object error)? onShowFailed,
      }) async {
    final ok = await confirmDialog(
      context,
      title: confirmTitle,
      message: confirmMessage,
    );
    if (!ok) return;

    final ad = _ad;
    if (ad == null) {
      onNotReady?.call();
      preload(context);
      return;
    }

    // show 후에는 SDK가 lifecycle 처리 -> 참조 제거
    _ad = null;

    bool rewarded = false;
    bool settled = false; // ✅ dismiss에서 중복 실행 방지

    // ✅ 이번 show에 대한 콜백을 "여기서" 고정한다 (중요)
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();

        // 다음 광고 미리 로드
        _ad = null;
        preload(context);

        if (settled) return;
        settled = true;

        if (rewarded) {
          // ✅ 보상 확정 → 여기서 1번만 달냥 호출
          try {
            await onRewardEarned();
          } catch (e) {
            // 콜백 내부 에러는 여기서 삼키지 말고, 필요하면 상위에서 토스트 처리
            // (원하면 onShowFailed 같은 별도 처리 추가 가능)
            rethrow;
          }
        } else {
          // ✅ 닫았지만 보상 없음
          onRewardNotEarned?.call();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _ad = null;
        preload(context);

        if (settled) return;
        settled = true;

        onShowFailed?.call(err);
      },
    );

    // ✅ 보상 획득은 여기서만 true 처리
    ad.show(
      onUserEarnedReward: (_, __) {
        rewarded = true;
      },
    );
  }
}
