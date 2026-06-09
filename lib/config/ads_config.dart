class AdsConfig {
  const AdsConfig._();

  static const bool yandexAdsEnabled = bool.fromEnvironment(
    'YANDEX_ADS_ENABLED',
    defaultValue: true,
  );

  static const String yandexBannerAdUnitId = String.fromEnvironment(
    'YANDEX_BANNER_AD_UNIT_ID',
    defaultValue: '',
  );
}
