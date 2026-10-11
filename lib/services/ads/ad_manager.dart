import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../logger/app_logger.dart';
import 'ad_config.dart';

/// Production-ready singleton AdManager service.
///
/// Handles:
/// 1. Google UMP (User Messaging Platform) GDPR / CCPA consent management.
/// 2. Pre-cached Interstitial ads with frequency capping to prevent player churn.
/// 3. Resilient Rewarded ads with exponential backoff retry policy and guaranteed reward callbacks.
/// 4. Safe fallback for desktop / non-mobile platforms.
class AdManager {
  AdManager._internal();
  static final AdManager instance = AdManager._internal();

  bool _isInitialized = false;
  bool _canRequestAds = false;

  // Interstitial State
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  int _gameOverCounter = 0;

  // Rewarded State
  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;
  int _rewardedRetryAttempt = 0;

  bool get isRewardedAdReady => _rewardedAd != null;

  // ---------------------------------------------------------------------------
  // INITIALIZATION & UMP CONSENT
  // ---------------------------------------------------------------------------
  Future<void> initialize({VoidCallback? onConsentComplete}) async {
    if (!AdConfig.isSupportedPlatform) {
      AppLogger.info('Mevcut platform mobil reklamları desteklemiyor; AdMob atlandı.');
      onConsentComplete?.call();
      return;
    }

    if (_isInitialized) {
      onConsentComplete?.call();
      return;
    }

    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
          if (formError != null) {
            AppLogger.warning('UMP Consent form uyarısı: ${formError.message}');
          }

          final canRequest = await ConsentInformation.instance.canRequestAds();
          _canRequestAds = canRequest;

          if (_canRequestAds) {
            await MobileAds.instance.initialize();
            _isInitialized = true;
            AppLogger.info('AdMob & UMP SDK başarıyla başlatıldı.');
            _loadInterstitialAd();
            _loadRewardedAd();
          }

          onConsentComplete?.call();
        });
      },
      (formError) {
        AppLogger.warning('UMP Bilgi güncelleme hatası: ${formError.message}');
        onConsentComplete?.call();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // INTERSTITIAL AD (Pre-Cached & Frequency Capped)
  // ---------------------------------------------------------------------------
  void _loadInterstitialAd() {
    if (!_canRequestAds || _isInterstitialLoading || _interstitialAd != null) {
      return;
    }

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          AppLogger.info('Geçiş reklamı önbelleklendi (pre-cached).');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              AppLogger.error('Geçiş reklamı gösterim hatası', error);
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          _interstitialAd = null;
          AppLogger.warning('Geçiş reklamı yüklenemedi: ${error.message}');
        },
      ),
    );
  }

  /// Oyun bittiğinde çağrılır; oyuncuyu sıkmamak için [AdConfig.interstitialGameOverInterval]
  /// kuralına göre gösterir. Gösterilemese bile oyunu kilitlemez, [onComplete] tetiklenir.
  void showInterstitialOnGameOver({VoidCallback? onComplete}) {
    if (!AdConfig.isSupportedPlatform) {
      onComplete?.call();
      return;
    }

    _gameOverCounter++;

    if (_gameOverCounter % AdConfig.interstitialGameOverInterval != 0) {
      onComplete?.call();
      return;
    }

    if (_interstitialAd != null) {
      _interstitialAd!.show();
      onComplete?.call();
    } else {
      AppLogger.info('Geçiş reklamı hazır değil; akış kesilmeden devam edildi.');
      _loadInterstitialAd();
      onComplete?.call();
    }
  }

  // ---------------------------------------------------------------------------
  // REWARDED AD (Exponential Backoff & Guaranteed Callback)
  // ---------------------------------------------------------------------------
  void _loadRewardedAd() {
    if (!_canRequestAds || _isRewardedLoading || _rewardedAd != null) return;

    _isRewardedLoading = true;
    RewardedAd.load(
      adUnitId: AdConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          _rewardedRetryAttempt = 0;
          AppLogger.info('Ödüllü reklam başarıyla yüklendi.');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              AppLogger.error('Ödüllü reklam gösterim hatası', error);
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isRewardedLoading = false;
          _rewardedAd = null;
          AppLogger.warning('Ödüllü reklam yükleme hatası: ${error.message}');

          _rewardedRetryAttempt++;
          final delaySeconds = math.min(
            math.pow(AdConfig.retryBaseDelaySeconds, _rewardedRetryAttempt).toInt(),
            32,
          );
          Timer(Duration(seconds: delaySeconds), _loadRewardedAd);
        },
      ),
    );
  }

  void showRewardedAd({
    required void Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onAdUnavailable,
  }) {
    if (!AdConfig.isSupportedPlatform) {
      onAdUnavailable?.call();
      return;
    }

    if (_rewardedAd != null) {
      _rewardedAd!.show(onUserEarnedReward: (_, reward) {
        AppLogger.info('Kullanıcı ödülü teslim edildi: ${reward.amount} ${reward.type}');
        onUserEarnedReward(reward);
      });
    } else {
      AppLogger.warning('Ödüllü reklam hazır değil.');
      onAdUnavailable?.call();
      _loadRewardedAd();
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
