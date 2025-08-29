import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class AdService {
  static AdService? _instance;
  static AdService get instance => _instance ??= AdService._();

  AdService._();

  // Test Ad Unit IDs
  static final String _bannerId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';

  static final String _interstitialId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910';

  static final String _rewardedId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-3940256099942544/1712485313';

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _interstitialReady = false;
  bool _rewardedReady = false;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      loadInterstitial();
      loadRewarded();
      debugPrint('✅ AdService initialized successfully');
    } catch (e) {
      debugPrint('❌ AdService initialization failed: $e');
    }
  }

  BannerAd createBannerAdWithListener({
    required void Function(Ad) onAdLoaded,
    required void Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
      ),
    );
  }

  // ✅ This method creates unique banner ads
  BannerAd createBannerAd({
    void Function(Ad)? onLoaded,
    void Function(Ad, LoadAdError)? onFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onLoaded ?? (_) => debugPrint('✅ Banner ad loaded'),
        onAdFailedToLoad:
            onFailedToLoad ??
            (ad, error) {
              debugPrint('❌ Banner ad failed: $error');
              ad.dispose();
            },
      ),
    );
  }

  // Interstitial Ad
  void loadInterstitial() {
    if (!_isInitialized) return;

    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialReady = true;
          debugPrint('✅ Interstitial ad loaded');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialReady = false;
              loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ Interstitial show failed: $error');
              ad.dispose();
              _interstitialReady = false;
              loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Interstitial load failed: $error');
          _interstitialReady = false;
          Future.delayed(const Duration(seconds: 60), loadInterstitial);
        },
      ),
    );
  }

  Future<void> showInterstitial() async {
    if (!_isInitialized) return;

    if (_interstitialReady && _interstitialAd != null) {
      await _interstitialAd!.show();
    } else {
      loadInterstitial();
    }
  }

  // Rewarded Ad
  void loadRewarded() {
    if (!_isInitialized) return;

    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedReady = true;
          debugPrint('✅ Rewarded ad loaded');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedReady = false;
              loadRewarded();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ Rewarded show failed: $error');
              ad.dispose();
              _rewardedReady = false;
              loadRewarded();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Rewarded load failed: $error');
          _rewardedReady = false;
          Future.delayed(const Duration(seconds: 60), loadRewarded);
        },
      ),
    );
  }

  Future<bool> showRewarded({
    required void Function(int amount) onReward,
  }) async {
    if (!_isInitialized) return false;

    if (_rewardedReady && _rewardedAd != null) {
      bool rewardEarned = false;
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          rewardEarned = true;
          onReward(reward.amount.toInt());
        },
      );
      return rewardEarned;
    } else {
      loadRewarded();
      return false;
    }
  }

  bool get isInterstitialReady => _interstitialReady;
  bool get isRewardedReady => _rewardedReady;

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd = null;
    _rewardedAd = null;
    _interstitialReady = false;
    _rewardedReady = false;
  }
}
