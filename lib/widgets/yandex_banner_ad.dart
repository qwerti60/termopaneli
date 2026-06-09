import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:termopaneli_app/config/ads_config.dart';
import 'package:termopaneli_app/services/app_manifest_api_service.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

class YandexBannerAd extends StatefulWidget {
  const YandexBannerAd({
    super.key,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
  });

  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  @override
  State<YandexBannerAd> createState() => _YandexBannerAdState();
}

class _YandexBannerAdState extends State<YandexBannerAd> {
  BannerAd? _banner;
  StreamSubscription<BannerAdLoadState>? _loadStateSubscription;
  int? _loadedWidth;
  String _adUnitId = AdsConfig.yandexBannerAdUnitId.trim();
  String _loadedAdUnitId = '';
  bool _manifestChecked = false;
  bool _isResolvingAdUnitId = false;
  bool _isLoaded = false;
  String _debugMessage = 'РСЯ: ожидание размера баннера';

  bool get _platformSupportsAds {
    if (!AdsConfig.yandexAdsEnabled || kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get _canShowAds => _platformSupportsAds && _adUnitId.isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_platformSupportsAds) {
      return;
    }

    final int width = MediaQuery.sizeOf(context).width.floor();
    if (width <= 0) {
      return;
    }

    if (!_manifestChecked) {
      _resolveAdUnitId(width);
      return;
    }
    if (_adUnitId.isEmpty) {
      return;
    }
    if (width == _loadedWidth && _adUnitId == _loadedAdUnitId) {
      return;
    }

    _loadBanner(width, _adUnitId);
  }

  @override
  void dispose() {
    _loadStateSubscription?.cancel();
    _banner?.destroy();
    super.dispose();
  }

  Future<void> _resolveAdUnitId(int width) async {
    if (_isResolvingAdUnitId) {
      return;
    }
    _isResolvingAdUnitId = true;
    if (kDebugMode) {
      setState(() => _debugMessage = 'РСЯ: читаю app-manifest');
    }

    final AppManifest? manifest = await AppManifestApiService.fetch();
    if (!mounted) {
      return;
    }
    _isResolvingAdUnitId = false;
    final String serverAdUnitId = manifest?.yandexBannerAdUnitId.trim() ?? '';
    setState(() {
      _manifestChecked = true;
      _adUnitId = serverAdUnitId.isNotEmpty
          ? serverAdUnitId
          : AdsConfig.yandexBannerAdUnitId.trim();
      if (_adUnitId.isEmpty) {
        _debugMessage =
            'РСЯ: ID не задан в app-manifest и YANDEX_BANNER_AD_UNIT_ID';
      }
    });

    if (_adUnitId.isNotEmpty) {
      _loadBanner(width, _adUnitId);
    }
  }

  void _loadBanner(int width, String adUnitId) {
    _loadStateSubscription?.cancel();
    _banner?.destroy();
    _isLoaded = false;
    _debugMessage = 'РСЯ: загрузка баннера $adUnitId';

    final BannerAd banner = BannerAd(adSize: BannerAdSize.sticky(width: width));
    _loadStateSubscription = banner.loadStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      if (state is BannerAdLoadStateLoaded) {
        setState(() {
          _isLoaded = true;
          _debugMessage = 'РСЯ: баннер загружен ${state.width}x${state.height}';
        });
      } else if (state is BannerAdLoadStateError) {
        setState(() {
          _isLoaded = false;
          _debugMessage =
              'РСЯ: ошибка ${state.error.code} — ${state.error.description}';
          _banner = null;
          _loadedWidth = null;
        });
      } else if (state is BannerAdLoadStateLoading) {
        setState(() {
          _isLoaded = false;
          _debugMessage = 'РСЯ: загрузка баннера';
        });
      }
    });

    setState(() {
      _banner = banner;
      _loadedWidth = width;
      _loadedAdUnitId = adUnitId;
    });
    banner.load(AdRequest(adUnitId: adUnitId));
  }

  @override
  Widget build(BuildContext context) {
    final BannerAd? banner = _banner;
    if (!_canShowAds) {
      if (kDebugMode) {
        final String reason = AdsConfig.yandexAdsEnabled
            ? _debugMessage
            : 'РСЯ: выключена через YANDEX_ADS_ENABLED=false';
        return _DebugAdStatus(
          message: reason,
          backgroundColor: widget.backgroundColor,
        );
      }
      return const SizedBox.shrink();
    }

    if (banner == null) {
      if (kDebugMode) {
        return _DebugAdStatus(
          message: _debugMessage,
          backgroundColor: widget.backgroundColor,
        );
      }
      return const SizedBox.shrink();
    }

    if (!_isLoaded && kDebugMode) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugAdStatus(
            message: _debugMessage,
            backgroundColor: widget.backgroundColor,
          ),
          SizedBox(height: 1, child: AdWidget(bannerAd: banner)),
        ],
      );
    }

    return ColoredBox(
      color: widget.backgroundColor ?? Colors.transparent,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: widget.padding,
          child: Align(
            alignment: Alignment.center,
            child: AdWidget(bannerAd: banner),
          ),
        ),
      ),
    );
  }
}

class _DebugAdStatus extends StatelessWidget {
  const _DebugAdStatus({required this.message, required this.backgroundColor});

  final String message;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor ?? const Color(0xFFFFF8E1),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF795548),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
