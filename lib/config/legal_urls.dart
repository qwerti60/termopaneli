import 'package:termopaneli_app/config/api_config.dart';
import 'package:termopaneli_app/services/app_manifest_api_service.dart';

/// Публичные юридические URL (тот же хост, что и [ApiConfig.baseUrl]).
abstract final class LegalUrls {
  LegalUrls._();

  /// Ссылка на соглашение: из [AppManifestApiService] при успехе, иначе [userAgreement].
  static Future<Uri> userAgreementResolved() async {
    final AppManifest? m = await AppManifestApiService.fetch();
    final String u = m?.userAgreementUrl ?? '';
    if (u.isNotEmpty) {
      final Uri? parsed = Uri.tryParse(u);
      if (parsed != null) {
        return parsed;
      }
    }
    return userAgreement();
  }

  /// Пользовательское соглашение. На сервере: `…/tp_api/agreement.html`.
  static Uri userAgreement() {
    final String base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) {
      return Uri.parse('https://ivnovav.ru/tp_api/agreement.html');
    }
    final Uri u = Uri.parse(base);
    String p = u.path;
    if (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    final String agreementPath = p.isEmpty ? '/agreement.html' : '$p/agreement.html';
    return Uri(
      scheme: u.scheme,
      host: u.host,
      port: u.hasPort ? u.port : null,
      path: agreementPath,
    );
  }
}
