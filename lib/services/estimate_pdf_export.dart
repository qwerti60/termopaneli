import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:termopaneli_app/services/estimate_api_service.dart';
import 'package:termopaneli_app/services/pdf_company_requisites.dart';
import 'package:termopaneli_app/services/estimate_service.dart';
import 'package:termopaneli_app/services/estimate_share_text.dart';

/// Генерация PDF сметы (кириллица: Roboto; шапка: логотип из assets; подвал: реквизиты).
abstract final class EstimatePdfExport {
  EstimatePdfExport._();

  static const String _logoAsset = 'assets/icons/app_icon.png';

  static Future<pw.Font> _loadRoboto() async {
    final ByteData data = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    return pw.Font.ttf(data);
  }

  static Future<pw.ImageProvider?> _loadLogo() async {
    try {
      final ByteData data = await rootBundle.load(_logoAsset);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static pw.TextStyle _title(pw.Font f) => pw.TextStyle(
        font: f,
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
      );

  static pw.TextStyle _section(pw.Font f) => pw.TextStyle(
        font: f,
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
      );

  static pw.TextStyle _body(pw.Font f) => pw.TextStyle(font: f, fontSize: 9);

  static pw.TextStyle _companyTitle(pw.Font f) => pw.TextStyle(
        font: f,
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
      );

  static pw.TextStyle _caption(pw.Font f) =>
      pw.TextStyle(font: f, fontSize: 8, color: PdfColors.grey800);

  static pw.TextStyle _footerSmall(pw.Font f) =>
      pw.TextStyle(font: f, fontSize: 6.8, color: PdfColors.grey700);

  static pw.Widget _buildHeader(
    pw.Font font,
    pw.ImageProvider? logo,
    PdfCompanyRequisites company,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.7),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: <pw.Widget>[
              if (logo != null) ...<pw.Widget>[
                pw.Image(logo, width: 42, height: 42, fit: pw.BoxFit.contain),
                pw.SizedBox(width: 10),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(company.legalName, style: _companyTitle(font)),
                    pw.SizedBox(height: 2),
                    pw.Text(company.tagline, style: _caption(font)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '${company.innLine}  •  ${company.phoneLine}',
            style: _body(font),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(company.address, style: _body(font)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(company.areaNote, style: _footerSmall(font)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              'Сайт: ${company.website}',
              style: _footerSmall(font),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              'Пользовательское соглашение: ${company.userAgreementUrl}',
              style: _footerSmall(font),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Divider(thickness: 0.6, color: PdfColors.grey500),
          pw.SizedBox(height: 4),
          pw.Text(
            'Стр. ${context.pageNumber} из ${context.pagesCount}',
            style: _footerSmall(font),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _calculationBlock(pw.Font font, Map<String, dynamic>? c) {
    final List<String> lines = EstimateShareText.calculationTextLines(c);
    if (lines.isEmpty) {
      return <pw.Widget>[];
    }
    return <pw.Widget>[
      pw.SizedBox(height: 6),
      pw.Text('Параметры расчёта', style: _section(font)),
      ...lines.map(
        (String s) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(s, style: _body(font)),
        ),
      ),
      pw.SizedBox(height: 6),
    ];
  }

  static List<pw.Widget> _estimateLineWidgets(pw.Font font, EstimateLine line, int index) {
    final String unit =
        line.item.unit == null || line.item.unit!.isEmpty ? 'шт' : line.item.unit!;
    final String cat = line.item.categoryLabel ?? line.item.category;
    final List<pw.Widget> out = <pw.Widget>[
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Text(
          '$index. ${line.item.title} ($cat)',
          style: _body(font),
        ),
      ),
      pw.Text(
        '${line.quantity} $unit × ${EstimateShareText.money(line.price)} → ${EstimateShareText.money(line.total)}',
        style: _body(font),
      ),
    ];
    final String note = '${line.item.raw['line_note'] ?? ''}'.trim();
    if (note.isNotEmpty) {
      out.add(pw.Text('Примечание: $note', style: _body(font)));
    }
    final double pct = _readDouble(line.item.raw['line_discount_percent']);
    final double fix = _readDouble(line.item.raw['line_discount_fixed_rub']);
    if (pct > 0 || fix > 0) {
      final List<String> bits = <String>[];
      if (pct > 0) {
        bits.add('${pct.toStringAsFixed(0)}%');
      }
      if (fix > 0) {
        bits.add(EstimateShareText.money(fix));
      }
      out.add(pw.Text('Скидка на позицию: ${bits.join(' + ')}', style: _body(font)));
    }
    return out;
  }

  static List<pw.Widget> _savedItemWidgets(pw.Font font, SavedEstimateItem item, int index) {
    final List<pw.Widget> out = <pw.Widget>[
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Text(
          '$index. ${item.name} (${item.category})',
          style: _body(font),
        ),
      ),
      pw.Text(
        '${item.quantity} ${item.unit} × ${EstimateShareText.money(item.unitPrice)} → ${EstimateShareText.money(item.totalPrice)}',
        style: _body(font),
      ),
    ];
    final String note = '${item.raw['line_note'] ?? ''}'.trim();
    if (note.isNotEmpty) {
      out.add(pw.Text('Примечание: $note', style: _body(font)));
    }
    final double pct = _readDouble(item.raw['line_discount_percent']);
    final double fix = _readDouble(item.raw['line_discount_fixed_rub']);
    if (pct > 0 || fix > 0) {
      final List<String> bits = <String>[];
      if (pct > 0) {
        bits.add('${pct.toStringAsFixed(0)}%');
      }
      if (fix > 0) {
        bits.add(EstimateShareText.money(fix));
      }
      out.add(pw.Text('Скидка на позицию: ${bits.join(' + ')}', style: _body(font)));
    }
    if (item.sku != null && item.sku!.trim().isNotEmpty) {
      out.add(pw.Text('арт. ${item.sku}', style: _body(font)));
    }
    return out;
  }

  static List<pw.Widget> _totalsCurrent(
    pw.Font font,
    List<EstimateLine> lines,
    double estimateDiscountPercent,
    double estimateDiscountRub,
  ) {
    final double sumLines = EstimateService.total(lines);
    final double grand = EstimateService.total(
      lines,
      estimateDiscountPercent: estimateDiscountPercent,
      estimateDiscountRub: estimateDiscountRub,
    );
    final List<pw.Widget> w = <pw.Widget>[
      pw.SizedBox(height: 8),
      pw.Divider(thickness: 0.5),
    ];
    if ((sumLines - grand).abs() > 0.5) {
      w.add(pw.Text('Сумма по строкам: ${EstimateShareText.money(sumLines)}', style: _body(font)));
      if (estimateDiscountPercent > 0) {
        w.add(pw.Text(
          'Скидка на смету: ${estimateDiscountPercent.toStringAsFixed(0)}%',
          style: _body(font),
        ));
      }
      if (estimateDiscountRub > 0) {
        w.add(pw.Text(
          'Скидка на смету (фикс): ${EstimateShareText.money(estimateDiscountRub)}',
          style: _body(font),
        ));
      }
    }
    w.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Text(
          'Итого: ${EstimateShareText.money(grand)}',
          style: _section(font),
        ),
      ),
    );
    return w;
  }

  static List<pw.Widget> _totalsSaved(pw.Font font, SavedEstimate estimate) {
    final double sumLines = estimate.items.fold<double>(
      0,
      (double s, SavedEstimateItem i) => s + i.totalPrice,
    );
    final List<pw.Widget> w = <pw.Widget>[
      pw.SizedBox(height: 8),
      pw.Divider(thickness: 0.5),
    ];
    if ((sumLines - estimate.totalAmount).abs() > 0.5) {
      w.add(pw.Text('Сумма по строкам: ${EstimateShareText.money(sumLines)}', style: _body(font)));
      w.add(pw.Text(
        'Итого (с учётом скидки на смету): ${EstimateShareText.money(estimate.totalAmount)}',
        style: _section(font),
      ));
    } else {
      w.add(pw.Text('Итого: ${EstimateShareText.money(estimate.totalAmount)}', style: _section(font)));
    }
    return w;
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

  static Future<Uint8List> buildFromCurrentLines({
    required List<EstimateLine> lines,
    required PdfCompanyRequisites company,
    String title = 'Смета',
    double estimateDiscountPercent = 0,
    double estimateDiscountRub = 0,
    Map<String, dynamic>? calculation,
  }) async {
    final pw.Font font = await _loadRoboto();
    final pw.ImageProvider? logo = await _loadLogo();
    final pw.Document doc = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );

    final List<EstimateLine> materials = EstimateService.materialLines(lines);
    final List<EstimateLine> works = EstimateService.workLines(lines);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 72, 40, 52),
        header: (pw.Context c) => _buildHeader(font, logo, company),
        footer: (pw.Context c) => _buildFooter(c, font),
        build: (pw.Context context) {
          final List<pw.Widget> children = <pw.Widget>[
            pw.Text(title, style: _title(font)),
            pw.Text(
              'Сформировано: ${_formatNow()}',
              style: _body(font),
            ),
            ..._calculationBlock(font, calculation),
          ];

          if (materials.isNotEmpty) {
            children.add(pw.Text('Материалы', style: _section(font)));
            int n = 0;
            for (final EstimateLine line in materials) {
              n += 1;
              children.addAll(_estimateLineWidgets(font, line, n));
            }
          }

          if (works.isNotEmpty) {
            children.add(pw.SizedBox(height: 8));
            children.add(pw.Text('Работы', style: _section(font)));
            int n = 0;
            for (final EstimateLine line in works) {
              n += 1;
              children.addAll(_estimateLineWidgets(font, line, n));
            }
          }

          children.addAll(
            _totalsCurrent(font, lines, estimateDiscountPercent, estimateDiscountRub),
          );
          return children;
        },
      ),
    );

    return doc.save();
  }

  static Future<Uint8List> buildFromSaved({
    required SavedEstimate estimate,
    required String statusLine,
    required PdfCompanyRequisites company,
    String? requestComment,
  }) async {
    final pw.Font font = await _loadRoboto();
    final pw.ImageProvider? logo = await _loadLogo();
    final pw.Document doc = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );

    final List<SavedEstimateItem> materials = estimate.items
        .where((SavedEstimateItem i) => i.category != 'work')
        .toList(growable: false);
    final List<SavedEstimateItem> works = estimate.items
        .where((SavedEstimateItem i) => i.category == 'work')
        .toList(growable: false);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 72, 40, 52),
        header: (pw.Context c) => _buildHeader(font, logo, company),
        footer: (pw.Context c) => _buildFooter(c, font),
        build: (pw.Context context) {
          final List<pw.Widget> children = <pw.Widget>[
            pw.Text(estimate.title, style: _title(font)),
            pw.Text('№ ${estimate.id} • $statusLine', style: _body(font)),
            pw.Text('Создана: ${estimate.createdAt}', style: _body(font)),
          ];

          if (requestComment != null && requestComment.trim().isNotEmpty) {
            children.add(pw.SizedBox(height: 8));
            children.add(pw.Text('Комментарий к заявке', style: _section(font)));
            children.add(pw.Text(requestComment.trim(), style: _body(font)));
          }

          children.addAll(_calculationBlock(font, estimate.calculation));

          if (materials.isNotEmpty) {
            children.add(pw.Text('Материалы', style: _section(font)));
            int n = 0;
            for (final SavedEstimateItem item in materials) {
              n += 1;
              children.addAll(_savedItemWidgets(font, item, n));
            }
          }

          if (works.isNotEmpty) {
            children.add(pw.SizedBox(height: 8));
            children.add(pw.Text('Работы', style: _section(font)));
            int n = 0;
            for (final SavedEstimateItem item in works) {
              n += 1;
              children.addAll(_savedItemWidgets(font, item, n));
            }
          }

          children.addAll(_totalsSaved(font, estimate));
          return children;
        },
      ),
    );

    return doc.save();
  }

  static String _formatNow() {
    final DateTime d = DateTime.now().toLocal();
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
