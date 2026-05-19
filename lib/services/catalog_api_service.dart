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

  /// Копия позиции с подмешанным `raw` (например `line_instance`, `line_note`).
  CatalogItem withMergedRaw({
    String? title,
    String? subtitle,
    Map<String, dynamic>? rawPatch,
    Iterable<String>? removeRawKeys,
  }) {
    final Map<String, dynamic> merged = Map<String, dynamic>.from(raw);
    if (removeRawKeys != null) {
      for (final String k in removeRawKeys) {
        merged.remove(k);
      }
    }
    if (rawPatch != null) {
      merged.addAll(rawPatch);
    }
    return CatalogItem(
      title: title ?? this.title,
      category: category,
      subtitle: subtitle ?? this.subtitle,
      categoryLabel: categoryLabel,
      imageUrl: imageUrl,
      price: price,
      unit: unit,
      raw: merged,
    );
  }
}

class CatalogCategory {
  const CatalogCategory({required this.code, required this.label});

  final String code;
  final String label;
}

abstract final class CatalogApiService {
  CatalogApiService._();

  /// Парсинг `thickness_mm` из API/raw для фильтра и отображения.
  static double? parseThicknessMm(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      final double d = value.toDouble();
      return d > 0 ? d : null;
    }
    final String s = value.toString().trim().replaceAll(',', '.');
    final double? d = double.tryParse(s);
    if (d == null || d <= 0) {
      return null;
    }
    return d;
  }

  /// Положительное значение размера в [raw] (мм), иначе `null`.
  static double? rawPositiveMm(Map<String, dynamic> raw, String key) {
    return parseThicknessMm(raw[key]);
  }

  /// Для позиций из `catalog_materials`: неполные габариты ведут к неточному количеству в смете.
  /// Категории **panel** и **work** не проверяются. `null` — предупреждение не показываем.
  static String? catalogMaterialEstimateDimensionHint(CatalogItem item) {
    final String cat = item.category;
    if (cat == 'panel' || cat == 'work') {
      return null;
    }
    const Set<String> skipCategories = <String>{
      'grout',
      'fastener',
      'consumable',
    };
    if (skipCategories.contains(cat)) {
      return null;
    }
    final Map<String, dynamic> raw = item.raw;
    final double? w = rawPositiveMm(raw, 'width_mm');
    final double? len = rawPositiveMm(raw, 'length_mm');
    final double? t = rawPositiveMm(raw, 'thickness_mm');

    final bool hasCrossSection = (w != null && w > 0) || (t != null && t > 0);
    final bool hasLength = len != null && len > 0;

    const Set<String> needCrossAndRun = <String>{
      'slope',
      'ebb',
      'corner',
    };
    if (needCrossAndRun.contains(cat)) {
      if (!hasCrossSection && !hasLength) {
        return 'В карточке не заполнены ширина/толщина и длина (мм). '
            'Проверьте номенклатуру на сервере и количество в смете вручную.';
      }
      if (!hasCrossSection) {
        return 'Не указана ширина или толщина профиля (мм). Подбор по проёму может быть неточным.';
      }
      if (!hasLength) {
        return 'Не указана длина (мм). Уточните количество в смете вручную.';
      }
      return null;
    }

    const Set<String> needRunOrWidth = <String>{
      'soffit',
      'soffit_lining',
      'front_overhang',
      'plinth',
    };
    if (needRunOrWidth.contains(cat)) {
      final bool hasWidth = w != null && w > 0;
      if (!hasLength && !hasWidth) {
        return 'Не указана длина или ширина элемента (мм). Проверьте данные в каталоге и количество в смете вручную.';
      }
    }
    return null;
  }

  /// Строка для query `thickness` (совпадает с числовым сравнением на сервере).
  static String? thicknessQueryString(double thicknessMm) {
    if (thicknessMm <= 0) {
      return null;
    }
    if (thicknessMm == thicknessMm.roundToDouble()) {
      return '${thicknessMm.round()}';
    }
    return thicknessMm.toString();
  }

  static String? thicknessTokenForRaw(dynamic rawThicknessMm) {
    final double? d = parseThicknessMm(rawThicknessMm);
    if (d == null) {
      return null;
    }
    return thicknessQueryString(d);
  }

  /// Для фильтра «Толщина, мм»: сначала [thickness_mm], иначе для откосов/отливов/уголков — [width_mm].
  static String? thicknessOrWidthMmTokenForCatalogFilter(CatalogItem item) {
    final String? t = thicknessTokenForRaw(item.raw['thickness_mm']);
    if (t != null) {
      return t;
    }
    const Set<String> fallbackWidthCategories = <String>{
      'slope',
      'ebb',
      'corner',
    };
    if (!fallbackWidthCategories.contains(item.category)) {
      return null;
    }
    return thicknessTokenForRaw(item.raw['width_mm']);
  }

  /// Уникальные значения толщины (мм) для выпадающего фильтра, по возрастанию.
  static List<String> uniqueThicknessFilterTokens(Iterable<CatalogItem> items) {
    final Set<String> out = <String>{};
    for (final CatalogItem item in items) {
      final String? t = thicknessOrWidthMmTokenForCatalogFilter(item);
      if (t != null) {
        out.add(t);
      }
    }
    final List<String> list = out.toList();
    list.sort((String a, String b) {
      final double da = double.tryParse(a.replaceAll(',', '.')) ?? 0;
      final double db = double.tryParse(b.replaceAll(',', '.')) ?? 0;
      return da.compareTo(db);
    });
    return list;
  }

  static int compareThicknessFilterTokens(String a, String b) {
    final double da = double.tryParse(a.replaceAll(',', '.')) ?? 0;
    final double db = double.tryParse(b.replaceAll(',', '.')) ?? 0;
    final int byNum = da.compareTo(db);
    if (byNum != 0) {
      return byNum;
    }
    return a.compareTo(b);
  }

  static const List<CatalogCategory> categories = <CatalogCategory>[
    CatalogCategory(code: 'all', label: 'Все'),
    CatalogCategory(code: 'panel', label: 'Панели'),
    CatalogCategory(code: 'slope', label: 'Откосы'),
    CatalogCategory(code: 'corner', label: 'Уголки'),
    CatalogCategory(code: 'grout', label: 'Затирка'),
    CatalogCategory(code: 'ebb', label: 'Отливы'),
    CatalogCategory(code: 'soffit', label: 'Софиты'),
    CatalogCategory(code: 'soffit_lining', label: 'Подшивка софитов'),
    CatalogCategory(code: 'front_overhang', label: 'Фронтальные свесы'),
    CatalogCategory(code: 'plinth', label: 'Цоколь'),
    CatalogCategory(code: 'fastener', label: 'Крепеж'),
    CatalogCategory(code: 'consumable', label: 'Расходники'),
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
    String? material,
    String? color,
    String? thickness,
  }) async {
    final Map<String, String> query = <String, String>{
      'limit': '$limit',
      'category': category,
    };
    final String? m = material?.trim();
    final String? c = color?.trim();
    final String? t = thickness?.trim();
    if (m != null && m.isNotEmpty) {
      query['material'] = m;
    }
    if (c != null && c.isNotEmpty) {
      query['color'] = c;
    }
    if (t != null && t.isNotEmpty) {
      query['thickness'] = t;
    }
    final Uri url = _uri('/api/v1/catalog/list.php').replace(
      queryParameters: query,
    );
    final http.Response res = await http
        .get(
          url,
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
