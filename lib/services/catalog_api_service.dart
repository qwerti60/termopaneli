import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:termopaneli_app/config/api_config.dart';

class CatalogItem {
  const CatalogItem({
    required this.title,
    required this.category,
    this.subtitle,
    this.categoryLabel,
    this.imageUrl,
    this.price,
    this.unit,
    this.raw = const <String, dynamic>{},
  });

  final String title;
  final String category;
  final String? subtitle;
  final String? categoryLabel;
  final String? imageUrl;
  final String? price;
  final String? unit;
  final Map<String, dynamic> raw;
}

class CatalogCategory {
  const CatalogCategory({required this.code, required this.label});

  final String code;
  final String label;
}

abstract final class CatalogApiService {
  CatalogApiService._();

  static const List<CatalogCategory> categories = <CatalogCategory>[
    CatalogCategory(code: 'all', label: 'Все'),
    CatalogCategory(code: 'panel', label: 'Панели'),
    CatalogCategory(code: 'slope', label: 'Откосы'),
    CatalogCategory(code: 'corner', label: 'Уголки'),
    CatalogCategory(code: 'grout', label: 'Затирка'),
    CatalogCategory(code: 'ebb', label: 'Отливы'),
    CatalogCategory(code: 'soffit', label: 'Софиты'),
    CatalogCategory(code: 'plinth', label: 'Цоколь'),
    CatalogCategory(code: 'fastener', label: 'Крепеж'),
  ];

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

  static Future<List<CatalogItem>> fetchCatalog({
    int limit = 100,
    String category = 'all',
  }) async {
    final String normalizedCategory = Uri.encodeQueryComponent(category);
    final http.Response res = await http
        .get(
          _uri(
            '/api/v1/catalog/list.php?limit=$limit&category=$normalizedCategory',
          ),
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

    final String title = pick(<String>[
      'title',
      'name',
      'panel_name',
      'model',
      'model_code',
      'code',
      'article',
      'id',
    ], fallback: 'Термопанель');
    final String subtitle = pick(<String>[
      'color_description',
      'description',
      'collection_style',
      'collection',
      'color',
      'price_m2',
      'price',
      'price_per_m2_rub',
    ]);
    final String imageRaw = pick(<String>[
      'image_path',
      'image_url',
      'image',
      'photo',
      'img',
      'preview',
    ]);
    final String? image = _normalizeImageUrl(imageRaw);
    final String category = pick(<String>['category'], fallback: 'panel');
    final String categoryLabel = pick(<String>['category_label']);
    final String price = pick(<String>[
      'price',
      'price_m2',
      'price_per_m2_rub',
      'panel_price',
    ]);
    final String unit = pick(<String>['unit']);

    return CatalogItem(
      title: title,
      category: category,
      subtitle: subtitle.isEmpty ? null : subtitle,
      categoryLabel: categoryLabel.isEmpty ? null : categoryLabel,
      imageUrl: image,
      price: price.isEmpty ? null : price,
      unit: unit.isEmpty ? null : unit,
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
    final String normalizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
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
