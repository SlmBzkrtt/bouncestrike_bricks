import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centralized configuration for Google AdMob ad units and monetization policies.
abstract final class AdConfig {
  /// Whether the current platform supports Google Mobile Ads SDK.
  static bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Test mode flag: automatically active in debug and profile modes.
  static bool get isTestMode => !kReleaseMode;

  // ---------------------------------------------------------------------------
  // BANNER AD UNIT ID
  // ---------------------------------------------------------------------------
  static String get bannerAdUnitId {
    if (!isSupportedPlatform) return '';
    if (isTestMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111' // Official Google Android Test Banner
          : 'ca-app-pub-3940256099942544/2934735716'; // Official Google iOS Test Banner
    }
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/6300978111' // Canlı Android Banner ID (Play Console'dan temin edilir)
        : 'ca-app-pub-3940256099942544/2934735716'; // Canlı iOS Banner ID
  }

  // ---------------------------------------------------------------------------
  // INTERSTITIAL AD UNIT ID
  // ---------------------------------------------------------------------------
  static String get interstitialAdUnitId {
    if (!isSupportedPlatform) return '';
    if (isTestMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712' // Official Google Android Test Interstitial
          : 'ca-app-pub-3940256099942544/4411468910'; // Official Google iOS Test Interstitial
    }
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/1033173712' // Canlı Android Interstitial ID
        : 'ca-app-pub-3940256099942544/4411468910'; // Canlı iOS Interstitial ID
  }

  // ---------------------------------------------------------------------------
  // REWARDED AD UNIT ID
  // ---------------------------------------------------------------------------
  static String get rewardedAdUnitId {
    if (!isSupportedPlatform) return '';
    if (isTestMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917' // Official Google Android Test Rewarded
          : 'ca-app-pub-3940256099942544/1712485313'; // Official Google iOS Test Rewarded
    }
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/5224354917' // Canlı Android Rewarded ID
        : 'ca-app-pub-3940256099942544/1712485313'; // Canlı iOS Rewarded ID
  }

  /// Interstitial reklam sıklığı: Oyuncuyu bunaltmamak için her 3 Game Over'da 1 tetiklenir.
  static const int interstitialGameOverInterval = 3;

  /// Ödüllü reklam yüklenemediğinde yeniden deneme taban süresi (saniye).
  static const int retryBaseDelaySeconds = 2;
}

