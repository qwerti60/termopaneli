import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:termopaneli_app/config/api_config.dart';
import 'package:termopaneli_app/services/app_manifest_api_service.dart';
import 'package:termopaneli_app/services/pdf_company_requisites.dart';

/// Реквизиты для PDF: сначала [GET app-manifest.php], иначе [company-for-pdf.php], иначе [PdfCompanyRequisites.fallback].
abstract final class CompanyPdfApiService {
  CompanyPdfApiService._();

  static Future<PdfCompanyRequisites> fetchForPdf() async {
    final String base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) {
      return PdfCompanyRequisites.fallback;
    }
    final String normalized =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;

    final AppManifest? manifest = await AppManifestApiService.fetch();
    if (manifest != null && manifest.companyPdfMap.isNotEmpty) {
      return PdfCompanyRequisites.fromApiMap(manifest.companyPdfMap);
    }

    final Uri legacy = Uri.parse(
      '$normalized/api/v1/settings/company-for-pdf.php',
    );
    try {
      final http.Response r = await http
          .get(legacy, headers: <String, String>{'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) {
        return PdfCompanyRequisites.fallback;
      }
      final Object? decoded = json.decode(r.body);
      if (decoded is! Map<String, dynamic>) {
        return PdfCompanyRequisites.fallback;
      }
      return PdfCompanyRequisites.fromApiMap(decoded);
    } catch (_) {
      return PdfCompanyRequisites.fallback;
    }
  }
}
