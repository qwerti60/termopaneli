import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:termopaneli_app/config/api_config.dart';

/// Ответ [GET .../settings/app-manifest.php]: реквизиты PDF и публичные ссылки.
class AppManifest {
  const AppManifest({
    required this.companyPdfMap,
    required this.userAgreementUrl,
    required this.privacyPolicyUrl,
    this.smartCalcUrl = '',
    this.yandexBannerAdUnitId = '',
  });

  final Map<String, dynamic> companyPdfMap;
  final String userAgreementUrl;
  final String privacyPolicyUrl;

  /// URL SmartCalc для WebView (PRO). Задаётся в `config.php` → `app_manifest.smartcalc_url`.
  final String smartCalcUrl;

  /// ID баннерного блока РСЯ. Задаётся в веб-админке или `config.php` → `app_manifest.yandex_banner_ad_unit_id`.
  final String yandexBannerAdUnitId;
}

/// Публичный манифест приложения (один запрос вместо разрозненных URL).
abstract final class AppManifestApiService {
  AppManifestApiService._();

  static AppManifest? _cache;
  static DateTime? _cachedAt;
  static const Duration _ttl = Duration(minutes: 4);

  static Uri? _manifestUri() {
    final String base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) {
      return null;
    }
    final String normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return Uri.parse('$normalized/api/v1/settings/app-manifest.php');
  }

  /// Загрузка манифеста; при ошибке — `null`. Короткое кэширование в памяти.
  static Future<AppManifest?> fetch({bool bypassCache = false}) async {
    if (!bypassCache &&
        _cache != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _ttl) {
      return _cache;
    }
    final Uri? uri = _manifestUri();
    if (uri == null) {
      return null;
    }
    try {
      final http.Response r = await http
          .get(uri, headers: <String, String>{'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) {
        return null;
      }
      final Object? decoded = json.decode(r.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final Object? cp = decoded['company_pdf'];
      if (cp is! Map) {
        return null;
      }
      final Map<String, dynamic> companyPdfMap = cp.cast<String, dynamic>();
      final String userAgreementUrl = '${decoded['user_agreement_url'] ?? ''}'
          .trim();
      final String privacyPolicyUrl = '${decoded['privacy_policy_url'] ?? ''}'
          .trim();
      final String smartCalcUrl = '${decoded['smartcalc_url'] ?? ''}'.trim();
      final String yandexBannerAdUnitId =
          '${decoded['yandex_banner_ad_unit_id'] ?? ''}'.trim();
      final AppManifest manifest = AppManifest(
        companyPdfMap: companyPdfMap,
        userAgreementUrl: userAgreementUrl,
        privacyPolicyUrl: privacyPolicyUrl,
        smartCalcUrl: smartCalcUrl,
        yandexBannerAdUnitId: yandexBannerAdUnitId,
      );
      _cache = manifest;
      _cachedAt = DateTime.now();
      return manifest;
    } catch (_) {
      return null;
    }
  }

  /// Сброс кэша (например, после смены API base URL в настройках).
  static void clearCache() {
    _cache = null;
    _cachedAt = null;
  }
}
