import 'package:flutter/foundation.dart';
import 'package:termopaneli_app/services/catalog_api_service.dart';

class EstimateCalculationInput {
  const EstimateCalculationInput({
    required this.facadeAreaM2,
    this.openingAreaM2 = 0,
    this.openingPerimeterLm = 0,
    this.windowCount = 0,
    this.cornerLengthLm = 0,
    this.sealingLengthLm = 0,
  });

  final double facadeAreaM2;
  final double openingAreaM2;
  final double openingPerimeterLm;
  final int windowCount;
  final double cornerLengthLm;
  final double sealingLengthLm;

  double get netFacadeAreaM2 {
    final double net = facadeAreaM2 - openingAreaM2;
    return net > 0 ? net : 0;
  }
}

double _readRawDouble(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString().replaceAll(',', '.').trim()) ?? 0;
}

class EstimateLine {
  const EstimateLine({required this.item, required this.quantity});

  final CatalogItem item;
  final int quantity;

  String get key {
    final dynamic sku =
        item.raw['sku'] ?? item.raw['article'] ?? item.raw['id'];
    final String stableId = sku?.toString().trim() ?? '';
    final String instance =
        '${item.raw['line_instance'] ?? ''}'.trim();
    if (stableId.isNotEmpty) {
      final String base = '${item.category}:$stableId';
      if (instance.isNotEmpty) {
        return '$base:$instance';
      }
      return base;
    }
    final String title = item.title;
    if (instance.isNotEmpty) {
      return '${item.category}:$title:$instance';
    }
    return '${item.category}:$title';
  }

  double get price {
    final String raw = item.price ?? '';
    final String normalized = raw
        .replaceAll(RegExp(r'[^0-9,.]'), '')
        .replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  double get subtotal => price * quantity;

  double get total {
    double v = subtotal;
    final double pct = _readRawDouble(item.raw['line_discount_percent']);
    if (pct > 0) {
      v *= 1 - pct.clamp(0, 100) / 100;
    }
    final double fix = _readRawDouble(item.raw['line_discount_fixed_rub']);
    if (fix > 0) {
      v -= fix;
    }
    if (v < 0) {
      return 0;
    }
    return v;
  }

  bool get hasLineDiscount => (subtotal - total) > 0.009;

  EstimateLine copyWith({int? quantity}) {
    return EstimateLine(item: item, quantity: quantity ?? this.quantity);
  }

  int quantityForArea(double areaM2) {
    if (areaM2 <= 0) {
      return quantity;
    }
    if (item.category == 'work') {
      return EstimateService.quantityForWork(
        item,
        EstimateCalculationInput(facadeAreaM2: areaM2),
      );
    }
    final String rawArea = '${item.raw['area_m2'] ?? ''}'
        .replaceAll(',', '.')
        .trim();
    final double panelArea = double.tryParse(rawArea) ?? 0;
    if (panelArea > 0) {
      return (areaM2 / panelArea).ceil().clamp(1, 999999);
    }
    final String unit = (item.unit ?? '').toLowerCase();
    if (unit.contains('м²') || unit.contains('м2')) {
      return areaM2.ceil().clamp(1, 999999);
    }
    return quantity;
  }
}

abstract final class EstimateService {
  EstimateService._();

  static final ValueNotifier<List<EstimateLine>> lines =
      ValueNotifier<List<EstimateLine>>(<EstimateLine>[]);

  static void addItem(CatalogItem item, {int quantity = 1}) {
    if (quantity < 1) {
      return;
    }
    final List<EstimateLine> current = List<EstimateLine>.from(lines.value);
    final EstimateLine incoming = EstimateLine(item: item, quantity: quantity);
    final int index = current.indexWhere(
      (EstimateLine line) => line.key == incoming.key,
    );
    if (index >= 0) {
      final EstimateLine existing = current[index];
      current[index] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      current.add(incoming);
    }
    lines.value = current;
  }

  /// Обновить позицию (тот же [EstimateLine.key]) с новым [CatalogItem], количество сохраняется.
  static void replaceLineItem(EstimateLine line, CatalogItem newItem) {
    final String k = line.key;
    lines.value = lines.value
        .map(
          (EstimateLine l) => l.key == k
              ? EstimateLine(item: newItem, quantity: l.quantity)
              : l,
        )
        .toList(growable: false);
  }

  /// Примечание к строке работы (попадает в `raw_json` при сохранении сметы).
  static void updateWorkLineNote(EstimateLine line, String note) {
    if (line.item.category != 'work') {
      return;
    }
    final String trimmed = note.trim();
    final CatalogItem next = line.item.withMergedRaw(
      rawPatch: <String, dynamic>{'line_note': trimmed},
    );
    replaceLineItem(line, next);
  }

  static void updateWorkLineDiscount(
    EstimateLine line, {
    required double percent,
    required double fixedRub,
  }) {
    if (line.item.category != 'work') {
      return;
    }
    final CatalogItem next = line.item.withMergedRaw(
      rawPatch: <String, dynamic>{
        'line_discount_percent': percent <= 0 ? 0 : percent.clamp(0, 100),
        'line_discount_fixed_rub': fixedRub <= 0 ? 0 : fixedRub,
      },
    );
    replaceLineItem(line, next);
  }

  static List<EstimateLine> materialLines(List<EstimateLine> source) {
    return source
        .where((EstimateLine line) => line.item.category != 'work')
        .toList(growable: false);
  }

  static List<EstimateLine> workLines(List<EstimateLine> source) {
    return source
        .where((EstimateLine line) => line.item.category == 'work')
        .toList(growable: false);
  }

  static int quantityForWork(CatalogItem item, EstimateCalculationInput input) {
    final String calcRule = '${item.raw['calc_rule'] ?? ''}'.trim();
    switch (calcRule) {
      case 'facade_area_m2':
        return _ceilPositive(input.netFacadeAreaM2);
      case 'fixed_once':
        return 1;
      case 'opening_perimeter_lm':
        if (input.openingPerimeterLm <= 0) {
          return 0;
        }
        return input.openingPerimeterLm.ceil().clamp(1, 999999);
      case 'window_count':
        if (input.windowCount <= 0) {
          return 0;
        }
        return input.windowCount.clamp(1, 999999);
      case 'corner_length_lm':
        return _ceilPositive(input.cornerLengthLm);
      case 'sealing_length_lm':
        return _ceilPositive(input.sealingLengthLm);
      default:
        return 1;
    }
  }

  static int _ceilPositive(double value) {
    if (value <= 0) {
      return 1;
    }
    return value.ceil().clamp(1, 999999);
  }

  static void updateQuantity(EstimateLine line, int quantity) {
    if (quantity < 1) {
      removeLine(line);
      return;
    }
    lines.value = lines.value
        .map(
          (EstimateLine current) => current.key == line.key
              ? current.copyWith(quantity: quantity)
              : current,
        )
        .toList(growable: false);
  }

  static void removeLine(EstimateLine line) {
    lines.value = lines.value
        .where((EstimateLine current) => current.key != line.key)
        .toList(growable: false);
  }

  static void clear() {
    lines.value = <EstimateLine>[];
  }

  static void replaceAll(List<EstimateLine> estimateLines) {
    lines.value = List<EstimateLine>.from(estimateLines);
  }

  static int applyArea(double areaM2) {
    int changed = 0;
    lines.value = lines.value
        .map((EstimateLine line) {
          final int nextQuantity = line.quantityForArea(areaM2);
          if (nextQuantity != line.quantity) {
            changed += 1;
            return line.copyWith(quantity: nextQuantity);
          }
          return line;
        })
        .toList(growable: false);
    return changed;
  }

  static double total(
    List<EstimateLine> estimateLines, {
    double estimateDiscountPercent = 0,
    double estimateDiscountRub = 0,
  }) {
    double sum = estimateLines.fold<double>(
      0,
      (double s, EstimateLine line) => s + line.total,
    );
    if (estimateDiscountPercent > 0) {
      sum *= 1 - estimateDiscountPercent.clamp(0, 100) / 100;
    }
    if (estimateDiscountRub > 0) {
      sum = (sum - estimateDiscountRub).clamp(0, double.infinity);
    }
    return sum;
  }
}
