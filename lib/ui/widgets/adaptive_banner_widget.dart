import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../services/ads/ad_config.dart';
import '../../services/logger/app_logger.dart';

/// Anchored adaptive banner widget.
///
/// Designed to sit safely outside the active gameplay canvas (`AspectRatio 1080/1470`)
/// and above bottom navigation bars, without obscuring touch controls.
class AdaptiveBannerWidget extends StatefulWidget {
  const AdaptiveBannerWidget({super.key});

  @override
  State<AdaptiveBannerWidget> createState() => _AdaptiveBannerWidgetState();
}

class _AdaptiveBannerWidgetState extends State<AdaptiveBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAdaptiveBanner();
  }

  Future<void> _loadAdaptiveBanner() async {
    if (!AdConfig.isSupportedPlatform) return;

    final mediaWidth = MediaQuery.of(context).size.width.truncate();
    if (mediaWidth <= 0) return;

    final adSize =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSize(mediaWidth);

    if (adSize == null || !mounted) return;

    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isAdLoaded = true);
          AppLogger.info('Adaptive Banner başarıyla yüklendi.');
        },
        onAdFailedToLoad: (ad, error) {
          AppLogger.warning('Adaptive Banner yüklenemedi: ${error.message}');
          ad.dispose();
          if (!mounted) return;
          setState(() => _isAdLoaded = false);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      color: Colors.transparent,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
