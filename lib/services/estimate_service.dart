import 'package:flutter/foundation.dart';
import 'package:termopaneli_app/services/catalog_api_service.dart';

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

  static double total(List<EstimateLine> estimateLines) {
    return estimateLines.fold<double>(
      0,
      (double sum, EstimateLine line) => sum + line.total,
    );
  }
}
