import 'package:termopaneli_app/services/estimate_api_service.dart';
import 'package:termopaneli_app/services/estimate_service.dart';

/// Текстовое представление сметы для «Поделиться» (мессенджеры, почта, заметки).
abstract final class EstimateShareText {
  EstimateShareText._();

  static String money(double value) {
    if (value == 0) {
      return 'по запросу';
    }
    return '${value.toStringAsFixed(0)} ₽';
  }

  static String _formatTimestamp(DateTime local) {
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  /// Текущая (несохранённая) смета из [EstimateLine].
  static String fromCurrentLines({
    required List<EstimateLine> lines,
    String title = 'Смета',
    double estimateDiscountPercent = 0,
    double estimateDiscountRub = 0,
    Map<String, dynamic>? calculation,
  }) {
    if (lines.isEmpty) {
      return '';
    }
    final StringBuffer out = StringBuffer();
    out.writeln(title);
    out.writeln('Сформировано: ${_formatTimestamp(DateTime.now().toLocal())}');
    out.writeln();

    _appendCalculation(out, calculation);

    final List<EstimateLine> materials =
        EstimateService.materialLines(lines);
    final List<EstimateLine> works = EstimateService.workLines(lines);

    if (materials.isNotEmpty) {
      out.writeln('Материалы');
      out.writeln(_repeat('─', 32));
      int n = 0;
      for (final EstimateLine line in materials) {
        n += 1;
        _appendLine(out, n, line);
      }
      out.writeln();
    }

    if (works.isNotEmpty) {
      out.writeln('Работы');
      out.writeln(_repeat('─', 32));
      int n = 0;
      for (final EstimateLine line in works) {
        n += 1;
        _appendLine(out, n, line);
      }
      out.writeln();
    }

    final double sumLines = EstimateService.total(lines);
    final double grand = EstimateService.total(
      lines,
      estimateDiscountPercent: estimateDiscountPercent,
      estimateDiscountRub: estimateDiscountRub,
    );

    if ((sumLines - grand).abs() > 0.5) {
      out.writeln('Сумма по строкам: ${money(sumLines)}');
      if (estimateDiscountPercent > 0) {
        out.writeln(
          'Скидка на смету: ${estimateDiscountPercent.toStringAsFixed(0)}%',
        );
      }
      if (estimateDiscountRub > 0) {
        out.writeln(
          'Скидка на смету (фикс): ${money(estimateDiscountRub)}',
        );
      }
      out.writeln('Итого: ${money(grand)}');
    } else {
      out.writeln('Итого: ${money(grand)}');
    }

    return out.toString().trimRight();
  }

  /// Сохранённая смета с сервера.
  static String fromSaved({
    required SavedEstimate estimate,
    required String statusLine,
    String? requestComment,
  }) {
    final StringBuffer out = StringBuffer();
    out.writeln(estimate.title);
    out.writeln('№ ${estimate.id} • $statusLine');
    out.writeln('Создана: ${estimate.createdAt}');
    out.writeln();

    if (requestComment != null && requestComment.trim().isNotEmpty) {
      out.writeln('Комментарий к заявке');
      out.writeln(_repeat('─', 32));
      out.writeln(requestComment.trim());
      out.writeln();
    }

    _appendCalculation(out, estimate.calculation);

    final List<SavedEstimateItem> materials = estimate.items
        .where((SavedEstimateItem i) => i.category != 'work')
        .toList(growable: false);
    final List<SavedEstimateItem> works = estimate.items
        .where((SavedEstimateItem i) => i.category == 'work')
        .toList(growable: false);

    if (materials.isNotEmpty) {
      out.writeln('Материалы');
      out.writeln(_repeat('─', 32));
      int n = 0;
      for (final SavedEstimateItem item in materials) {
        n += 1;
        _appendSavedItem(out, n, item);
      }
      out.writeln();
    }

    if (works.isNotEmpty) {
      out.writeln('Работы');
      out.writeln(_repeat('─', 32));
      int n = 0;
      for (final SavedEstimateItem item in works) {
        n += 1;
        _appendSavedItem(out, n, item);
      }
      out.writeln();
    }

    final double sumLines = estimate.items.fold<double>(
      0,
      (double s, SavedEstimateItem i) => s + i.totalPrice,
    );
    if ((sumLines - estimate.totalAmount).abs() > 0.5) {
      out.writeln('Сумма по строкам: ${money(sumLines)}');
      out.writeln('Итого (с учётом скидки на смету): ${money(estimate.totalAmount)}');
    } else {
      out.writeln('Итого: ${money(estimate.totalAmount)}');
    }

    return out.toString().trimRight();
  }

  /// Строки блока «Параметры расчёта» для текста и PDF. Пустой список — блок не показывать.
  static List<String> calculationTextLines(Map<String, dynamic>? c) {
    if (c == null || c.isEmpty) {
      return const <String>[];
    }
    final List<String> parts = <String>[];
    void add(String label, String key) {
      final Object? v = c[key];
      if (v == null) {
        return;
      }
      final String s = '$v'.trim();
      if (s.isEmpty || s == '0' || s == '0.0') {
        return;
      }
      parts.add('$label: $s');
    }

    add('Площадь фасада, м²', 'facade_area_m2');
    add('Проёмы, м²', 'opening_area_m2');
    add('Периметр проёмов, м', 'opening_perimeter_lm');
    add('Окна, шт', 'window_count');
    add('Углы, м', 'corner_length_lm');
    add('Примыкания, м', 'sealing_length_lm');

    final Object? openings = c['openings'];
    if (openings is List && openings.isNotEmpty) {
      parts.add('Проёмов в списке: ${openings.length}');
    }

    final double edp = _readDouble(c['estimate_discount_percent']);
    final double edr = _readDouble(c['estimate_discount_rub']);
    if (edp > 0) {
      parts.add('Скидка на смету: ${edp.toStringAsFixed(0)}%');
    }
    if (edr > 0) {
      parts.add('Скидка на смету (фикс): ${money(edr)}');
    }

    return parts;
  }

  /// Короткая подпись для списков и карточек: скидка на смету или расхождение суммы строк с итогом.
  static String? estimateDiscountCaption({
    required double lineItemsSum,
    required double totalAmount,
    Map<String, dynamic>? calculation,
  }) {
    final Map<String, dynamic> c = calculation ?? const <String, dynamic>{};
    final double edp = _readDouble(c['estimate_discount_percent']);
    final double edr = _readDouble(c['estimate_discount_rub']);
    final bool mismatch = (lineItemsSum - totalAmount).abs() > 0.5;
    if (edp <= 0 && edr <= 0 && !mismatch) {
      return null;
    }
    final List<String> parts = <String>[];
    if (edp > 0) {
      parts.add('${edp.toStringAsFixed(0)}%');
    }
    if (edr > 0) {
      parts.add(money(edr));
    }
    if (parts.isNotEmpty) {
      return 'Скидка на смету: ${parts.join(' + ')}';
    }
    if (mismatch) {
      return 'Сумма строк ${money(lineItemsSum)} → итог ${money(totalAmount)}';
    }
    return null;
  }

  static void _appendCalculation(StringBuffer out, Map<String, dynamic>? c) {
    final List<String> lines = calculationTextLines(c);
    if (lines.isEmpty) {
      return;
    }
    out.writeln('Параметры расчёта');
    out.writeln(_repeat('─', 32));
    for (final String p in lines) {
      out.writeln(p);
    }
    out.writeln();
  }

  static void _appendLine(StringBuffer out, int index, EstimateLine line) {
    final String unit =
        line.item.unit == null || line.item.unit!.isEmpty ? 'шт' : line.item.unit!;
    final String cat = line.item.categoryLabel ?? line.item.category;
    out.write('$index. ${line.item.title}');
    out.writeln(' ($cat)');
    out.writeln(
      '   ${line.quantity} $unit × ${money(line.price)} → ${money(line.total)}',
    );
    final String note = '${line.item.raw['line_note'] ?? ''}'.trim();
    if (note.isNotEmpty) {
      out.writeln('   Примечание: $note');
    }
    if (line.item.category == 'work') {
      final double pct = _readDouble(line.item.raw['line_discount_percent']);
      final double fix = _readDouble(line.item.raw['line_discount_fixed_rub']);
      if (pct > 0 || fix > 0) {
        final List<String> bits = <String>[];
        if (pct > 0) {
          bits.add('${pct.toStringAsFixed(0)}%');
        }
        if (fix > 0) {
          bits.add(money(fix));
        }
        out.writeln('   Скидка на работу: ${bits.join(' + ')}');
      }
    }
  }

  static void _appendSavedItem(StringBuffer out, int index, SavedEstimateItem item) {
    out.write('$index. ${item.name}');
    out.writeln(' (${item.category})');
    out.writeln(
      '   ${item.quantity} ${item.unit} × ${money(item.unitPrice)} → ${money(item.totalPrice)}',
    );
    final String note = '${item.raw['line_note'] ?? ''}'.trim();
    if (note.isNotEmpty) {
      out.writeln('   Примечание: $note');
    }
    if (item.category == 'work') {
      final double pct = _readDouble(item.raw['line_discount_percent']);
      final double fix = _readDouble(item.raw['line_discount_fixed_rub']);
      if (pct > 0 || fix > 0) {
        final List<String> bits = <String>[];
        if (pct > 0) {
          bits.add('${pct.toStringAsFixed(0)}%');
        }
        if (fix > 0) {
          bits.add(money(fix));
        }
        out.writeln('   Скидка на работу: ${bits.join(' + ')}');
      }
    }
    if (item.sku != null && item.sku!.trim().isNotEmpty) {
      out.writeln('   арт. ${item.sku}');
    }
  }

  static double _readDouble(Object? v) {
    if (v == null) {
      return 0;
    }
    if (v is num) {
      return v.toDouble();
    }
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }

  static String _repeat(String ch, int n) {
    return List<String>.filled(n, ch).join();
  }
}
