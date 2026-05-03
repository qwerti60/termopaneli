import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:termopaneli_app/config/api_config.dart';

class CatalogItem {
  const CatalogItem({
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.raw = const <String, dynamic>{},
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final Map<String, dynamic> raw;
}

abstract final class CatalogApiService {
  CatalogApiService._();

  static Uri _uri(String path) {
    final String base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) {
      throw StateError('API_BASE_URL');
    }
    final String normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return Uri.parse('$normalized$path');
  }

  static Future<List<CatalogItem>> fetchCatalog({int limit = 100}) async {
    final http.Response res = await http
        .get(
          _uri('/api/v1/catalog/list.php?limit=$limit'),
          headers: const <String, String>{'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception('Ошибка загрузки каталога: ${res.statusCode}');
    }

    final dynamic data = jsonDecode(res.body);
    if (data is! Map<String, dynamic> || data['items'] is! List) {
      throw Exception('Некорректный формат каталога');
    }

    final List items = data['items'] as List;
    return items
        .whereType<Map>()
        .map((Map row) => _toItem(row.cast<String, dynamic>()))
        .toList(growable: false);
  }

  static CatalogItem _toItem(Map<String, dynamic> row) {
    String pick(List<String> keys, {String fallback = ''}) {
      for (final String k in keys) {
        final dynamic v = row[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return fallback;
    }

    final String title = pick(
      <String>['title', 'name', 'panel_name', 'model', 'model_code', 'code', 'article', 'id'],
      fallback: 'Термопанель',
    );
    final String subtitle = pick(
      <String>[
        'color_description',
        'description',
        'collection_style',
        'collection',
        'color',
        'price_m2',
        'price',
        'price_per_m2_rub',
      ],
    );
    final String imageRaw = pick(
      <String>['image_path', 'image_url', 'image', 'photo', 'img', 'preview'],
    );
    final String? image = _normalizeImageUrl(imageRaw);

    return CatalogItem(
      title: title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      imageUrl: image,
      raw: row,
    );
  }

  static String? _normalizeImageUrl(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final String base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) {
      return null;
    }
    final String normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final Uri baseUri = Uri.parse(normalizedBase);
    final String origin = '${baseUri.scheme}://${baseUri.host}';

    // Уже путь от корня сайта.
    if (value.startsWith('/')) {
      return '$origin$value';
    }
    // Путь внутри tp_api.
    if (value.startsWith('catalog/')) {
      return '$normalizedBase/$value';
    }
    // В БД просто имя файла.
    return '$normalizedBase/catalog/$value';
  }
}
