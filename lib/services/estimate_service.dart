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

class EstimateLine {
  const EstimateLine({required this.item, required this.quantity});

  final CatalogItem item;
  final int quantity;

  String get key {
    final dynamic sku =
        item.raw['sku'] ?? item.raw['article'] ?? item.raw['id'];
    final String stableId = sku?.toString().trim() ?? '';
    if (stableId.isNotEmpty) {
      return '${item.category}:$stableId';
    }
    return '${item.category}:${item.title}';
  }

  double get price {
    final String raw = item.price ?? '';
    final String normalized = raw
        .replaceAll(RegExp(r'[^0-9,.]'), '')
        .replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  double get total => price * quantity;

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
    final int safeQuantity = quantity < 1 ? 1 : quantity;
    final List<EstimateLine> current = List<EstimateLine>.from(lines.value);
    final EstimateLine incoming = EstimateLine(
      item: item,
      quantity: safeQuantity,
    );
    final int index = current.indexWhere(
      (EstimateLine line) => line.key == incoming.key,
    );
    if (index >= 0) {
      final EstimateLine existing = current[index];
      current[index] = existing.copyWith(
        quantity: existing.quantity + safeQuantity,
      );
    } else {
      current.add(incoming);
    }
    lines.value = current;
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
        return _ceilPositive(input.openingPerimeterLm);
      case 'window_count':
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

  static double total(List<EstimateLine> estimateLines) {
    return estimateLines.fold<double>(
      0,
      (double sum, EstimateLine line) => sum + line.total,
    );
  }
}
