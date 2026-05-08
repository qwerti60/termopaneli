import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:termopaneli_app/config/api_config.dart';
import 'package:termopaneli_app/services/catalog_api_service.dart';

abstract final class WorkPriceApiService {
  WorkPriceApiService._();

  static Uri _uri(String path) {
    final String base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) {
      throw StateError('API_BASE_URL');
    }
    final String normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return Uri.parse('$normalized$path');
  }

  static Future<List<CatalogItem>> fetchWorkPrices({int limit = 100}) async {
    final http.Response res = await http
        .get(
          _uri('/api/v1/work-prices/list.php?limit=$limit'),
          headers: const <String, String>{'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception('Ошибка загрузки прайса работ: ${res.statusCode}');
    }

    final dynamic data = jsonDecode(res.body);
    if (data is! Map<String, dynamic> || data['items'] is! List) {
      throw Exception('Некорректный формат прайса работ');
    }

    return (data['items'] as List)
        .whereType<Map>()
        .map((Map row) => _toWorkItem(row.cast<String, dynamic>()))
        .toList(growable: false);
  }

  static CatalogItem _toWorkItem(Map<String, dynamic> row) {
    String pick(List<String> keys, {String fallback = ''}) {
      for (final String key in keys) {
        final dynamic value = row[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return fallback;
    }

    final String title = pick(<String>['title', 'name'], fallback: 'Работа');
    final String description = pick(<String>['description']);
    final String price = pick(<String>['price']);
    final String unit = pick(<String>['unit'], fallback: 'шт');

    return CatalogItem(
      title: title,
      category: 'work',
      subtitle: description.isEmpty ? null : description,
      categoryLabel: 'Работы',
      price: price.isEmpty ? null : price,
      unit: unit,
      raw: row,
    );
  }
}
