import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:termopaneli_app/auth/auth_flow.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/services/catalog_api_service.dart';
import 'package:termopaneli_app/services/estimate_api_service.dart';
import 'package:termopaneli_app/screens/estimate_pdf_preview_screen.dart';
import 'package:termopaneli_app/services/company_pdf_api_service.dart';
import 'package:termopaneli_app/services/estimate_pdf_export.dart';
import 'package:termopaneli_app/services/estimate_service.dart';
import 'package:termopaneli_app/services/estimate_share_text.dart';
import 'package:termopaneli_app/services/work_price_api_service.dart';

class _OpeningDraft {
  _OpeningDraft();

  bool isWindow = true;
  final TextEditingController widthController = TextEditingController();
  final TextEditingController heightController = TextEditingController();

  double get widthM => _parse(widthController.text);
  double get heightM => _parse(heightController.text);
  double get areaM2 => widthM * heightM;
  double get perimeterLm {
    if (widthM <= 0 || heightM <= 0) {
      return 0;
    }
    return 2 * (widthM + heightM);
  }

  void dispose() {
    widthController.dispose();
    heightController.dispose();
  }

  static double _parse(String value) {
    return double.tryParse(value.replaceAll(',', '.').trim()) ?? 0;
  }
}

class EstimateScreen extends StatefulWidget {
  const EstimateScreen({super.key, this.initialEstimate});

  final SavedEstimate? initialEstimate;

  @override
  State<EstimateScreen> createState() => _EstimateScreenState();
}

class _EstimateScreenState extends State<EstimateScreen> {
  bool _materialsSelected = true;
  bool _isSaving = false;
  int? _submittingEstimateId;
  late Future<List<SavedEstimate>> _savedEstimatesFuture;
  late Future<List<CatalogItem>> _workPricesFuture;
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _wastePercentController =
      TextEditingController(text: '5');
  final TextEditingController _openingAreaController = TextEditingController();
  final TextEditingController _openingPerimeterController =
      TextEditingController();
  final TextEditingController _windowCountController = TextEditingController();
  final TextEditingController _cornerLengthController = TextEditingController();
  final TextEditingController _sealingLengthController =
      TextEditingController();
  final List<_OpeningDraft> _openings = <_OpeningDraft>[];
  double _estimateDiscountPercent = 0;
  double _estimateDiscountRub = 0;

  @override
  void initState() {
    super.initState();
    _savedEstimatesFuture = EstimateApiService.fetchSaved();
    _workPricesFuture = WorkPriceApiService.fetchWorkPrices();
    final SavedEstimate? initialEstimate = widget.initialEstimate;
    if (initialEstimate != null) {
      _restoreEstimate(initialEstimate);
    }
  }

  @override
  void dispose() {
    _areaController.dispose();
    _wastePercentController.dispose();
    _openingAreaController.dispose();
    _openingPerimeterController.dispose();
    _windowCountController.dispose();
    _cornerLengthController.dispose();
    _sealingLengthController.dispose();
    for (final _OpeningDraft opening in _openings) {
      opening.dispose();
    }
    super.dispose();
  }

  String _money(double value) {
    if (value == 0) {
      return 'по запросу';
    }
    return '${value.toStringAsFixed(0)} ₽';
  }

  void _restoreEstimate(SavedEstimate estimate) {
    EstimateService.replaceAll(EstimateApiService.linesFromSaved(estimate));
    final Map<String, dynamic> calculation = estimate.calculation;
    _areaController.text = _stringFromCalculation(
      calculation['facade_area_m2'],
    );
    _openingAreaController.text = _stringFromCalculation(
      calculation['opening_area_m2'],
    );
    _openingPerimeterController.text = _stringFromCalculation(
      calculation['opening_perimeter_lm'],
    );
    _windowCountController.text = _stringFromCalculation(
      calculation['window_count'],
    );
    _cornerLengthController.text = _stringFromCalculation(
      calculation['corner_length_lm'],
    );
    _sealingLengthController.text = _stringFromCalculation(
      calculation['sealing_length_lm'],
    );
    _estimateDiscountPercent = _doubleFromCalc(calculation, 'estimate_discount_percent');
    _estimateDiscountRub = _doubleFromCalc(calculation, 'estimate_discount_rub');
    final Object? cw = calculation['cutting_waste_percent'];
    _wastePercentController.text = cw == null ? '0' : _stringFromCalculation(cw);

    final Object? openings = calculation['openings'];
    if (openings is List) {
      for (final Object? value in openings) {
        if (value is Map) {
          final _OpeningDraft opening = _OpeningDraft();
          opening.isWindow = '${value['type'] ?? 'window'}' != 'door';
          opening.widthController.text = _stringFromCalculation(
            value['width_m'],
          );
          opening.heightController.text = _stringFromCalculation(
            value['height_m'],
          );
          _openings.add(opening);
        }
      }
      _syncOpeningTotals();
    }
  }

  String _stringFromCalculation(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is num) {
      return _formatNumber(value.toDouble());
    }
    return '$value';
  }

  double _doubleFromCalc(Map<String, dynamic> map, String key) {
    final Object? v = map[key];
    if (v == null) {
      return 0;
    }
    if (v is num) {
      return v.toDouble();
    }
    return double.tryParse(v.toString().replaceAll(',', '.').trim()) ?? 0;
  }

  Future<void> _saveEstimate(List<EstimateLine> lines) async {
    if (_isSaving) {
      return;
    }
    final bool ok = await AuthFlow.ensureLoggedIn(
      context,
      title: 'Вход для сохранения',
      body:
          'По правилам App Store приложение доступно без учётной записи: каталог, '
          'сборка сметы и PDF не требуют входа.\n\n'
          'Чтобы сохранить смету на сервере и видеть её в «Сметах», войдите или '
          'зарегистрируйтесь.',
    );
    if (!ok || !mounted) {
      return;
    }
    setState(() => _isSaving = true);
    final SaveEstimateResult result = await EstimateApiService.saveCurrent(
      lines: lines,
      title: 'Смета ${DateTime.now().toLocal().toString().substring(0, 16)}',
      calculation: _calculationPayload(),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
      if (result.ok) {
        _savedEstimatesFuture = EstimateApiService.fetchSaved();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok
              ? 'Смета сохранена'
              : (result.errorMessage ?? 'Не удалось сохранить смету'),
        ),
      ),
    );
  }

  void _refreshSaved() {
    setState(() {
      _savedEstimatesFuture = EstimateApiService.fetchSaved();
    });
  }

  double? _readArea() {
    final String raw = _areaController.text.replaceAll(',', '.').trim();
    return double.tryParse(raw);
  }

  double _readOptionalDouble(TextEditingController controller) {
    final String raw = controller.text.replaceAll(',', '.').trim();
    if (raw.isEmpty) {
      return 0;
    }
    return double.tryParse(raw) ?? 0;
  }

  int _readOptionalInt(TextEditingController controller) {
    final String raw = controller.text.trim();
    if (raw.isEmpty) {
      return 0;
    }
    return int.tryParse(raw) ?? 0;
  }

  String _formatNumber(double value) {
    if (value == 0) {
      return '';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  double get _openingsAreaM2 {
    return _openings.fold<double>(
      0,
      (double sum, _OpeningDraft opening) => sum + opening.areaM2,
    );
  }

  double get _openingsPerimeterLm {
    return _openings.fold<double>(
      0,
      (double sum, _OpeningDraft opening) => sum + opening.perimeterLm,
    );
  }

  int get _windowCount {
    return _openings.where((_OpeningDraft opening) => opening.isWindow).length;
  }

  double _readCuttingWastePercent() {
    final String raw = _wastePercentController.text.replaceAll(',', '.').trim();
    if (raw.isEmpty) {
      return 0;
    }
    final double? v = double.tryParse(raw);
    if (v == null) {
      return 0;
    }
    return v.clamp(0, 50);
  }

  Map<String, Object?> _calculationPayload() {
    final EstimateCalculationInput? input = _readCalculationInput(
      showError: false,
    );
    return <String, Object?>{
      'facade_area_m2': input?.facadeAreaM2 ?? _readArea() ?? 0,
      'opening_area_m2': input?.openingAreaM2 ?? 0,
      'opening_perimeter_lm': input?.openingPerimeterLm ?? 0,
      'window_count': input?.windowCount ?? 0,
      'corner_length_lm': input?.cornerLengthLm ?? 0,
      'sealing_length_lm': input?.sealingLengthLm ?? 0,
      'openings': _openings
          .map(
            (_OpeningDraft opening) => <String, Object?>{
              'type': opening.isWindow ? 'window' : 'door',
              'width_m': opening.widthM,
              'height_m': opening.heightM,
              'area_m2': opening.areaM2,
              'perimeter_lm': opening.perimeterLm,
            },
          )
          .toList(growable: false),
      'estimate_discount_percent': _estimateDiscountPercent,
      'estimate_discount_rub': _estimateDiscountRub,
      'cutting_waste_percent': _readCuttingWastePercent(),
    };
  }

  void _syncOpeningTotals() {
    if (_openings.isEmpty) {
      return;
    }
    _openingAreaController.text = _formatNumber(_openingsAreaM2);
    _openingPerimeterController.text = _formatNumber(_openingsPerimeterLm);
    _windowCountController.text = _windowCount > 0 ? '$_windowCount' : '';
  }

  void _addOpening() {
    setState(() {
      _openings.add(_OpeningDraft());
      _syncOpeningTotals();
    });
  }

  void _removeOpening(int index) {
    if (index < 0 || index >= _openings.length) {
      return;
    }
    setState(() {
      final _OpeningDraft removed = _openings.removeAt(index);
      removed.dispose();
      if (_openings.isEmpty) {
        _openingAreaController.clear();
        _openingPerimeterController.clear();
        _windowCountController.clear();
      } else {
        _syncOpeningTotals();
      }
    });
  }

  void _setOpeningType(int index, bool isWindow) {
    if (index < 0 || index >= _openings.length) {
      return;
    }
    setState(() {
      _openings[index].isWindow = isWindow;
      _syncOpeningTotals();
    });
  }

  void _onOpeningSizeChanged() {
    setState(_syncOpeningTotals);
  }

  EstimateCalculationInput? _readCalculationInput({bool showError = true}) {
    final double? facadeArea = _readArea();
    if (facadeArea == null || facadeArea <= 0) {
      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите площадь фасада больше 0')),
        );
      }
      return null;
    }
    return EstimateCalculationInput(
      facadeAreaM2: facadeArea,
      openingAreaM2: _openings.isEmpty
          ? _readOptionalDouble(_openingAreaController)
          : _openingsAreaM2,
      openingPerimeterLm: _openings.isEmpty
          ? _readOptionalDouble(_openingPerimeterController)
          : _openingsPerimeterLm,
      windowCount: _openings.isEmpty
          ? _readOptionalInt(_windowCountController)
          : _windowCount,
      cornerLengthLm: _readOptionalDouble(_cornerLengthController),
      sealingLengthLm: _readOptionalDouble(_sealingLengthController),
      cuttingWastePercent: _readCuttingWastePercent(),
    );
  }

  void _applyAreaToCurrentEstimate() {
    final EstimateCalculationInput? input = _readCalculationInput();
    if (input == null) {
      return;
    }
    final int changed = EstimateService.applyArea(input);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          changed > 0
              ? 'Количество пересчитано по площади'
              : 'В смете нет позиций для автоматического расчета',
        ),
      ),
    );
  }

  void _addWorkItem(CatalogItem item) {
    final EstimateCalculationInput? input = _readCalculationInput(
      showError: false,
    );
    final int quantity = input == null
        ? 1
        : EstimateService.quantityForWork(item, input);
    if (quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Недостаточно данных для количества (площадь фасада, проёмы, окна).',
          ),
        ),
      );
      return;
    }
    EstimateService.addItem(item, quantity: quantity);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Работа добавлена: ${item.title}')));
  }

  void _addSlopeEbbFromOpenings(List<CatalogItem> items) {
    if (_openings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте проёмы в блоке «Окна и двери»')),
      );
      return;
    }
    final EstimateCalculationInput? input = _readCalculationInput();
    if (input == null) {
      return;
    }
    CatalogItem? slope;
    CatalogItem? ebb;
    for (final CatalogItem item in items) {
      final String sku = '${item.raw['sku'] ?? ''}'.trim();
      if (sku == 'WORK-SLOPE-LM') {
        slope = item;
      } else if (sku == 'WORK-EBB-PCS') {
        ebb = item;
      }
    }
    int added = 0;
    final List<String> notes = <String>[];
    if (slope != null) {
      final int q = EstimateService.quantityForWork(slope, input);
      if (q >= 1) {
        EstimateService.addItem(slope, quantity: q);
        added += 1;
      } else {
        notes.add('откосы не добавлены (нет периметра проёмов)');
      }
    }
    if (ebb != null) {
      final int q = EstimateService.quantityForWork(ebb, input);
      if (q >= 1) {
        EstimateService.addItem(ebb, quantity: q);
        added += 1;
      } else {
        notes.add('отлив не добавлен (нет окон в списке)');
      }
    }
    if (!mounted) {
      return;
    }
    final String base = added > 0
        ? 'В смету добавлено позиций: $added'
        : 'Нечего добавить по текущим размерам';
    final String msg = notes.isEmpty ? base : '$base. ${notes.join('; ')}';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _addSlopeEbbPerOpening(List<CatalogItem> items) {
    if (_openings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте проёмы в блоке «Окна и двери»')),
      );
      return;
    }
    CatalogItem? slope;
    CatalogItem? ebb;
    for (final CatalogItem item in items) {
      final String sku = '${item.raw['sku'] ?? ''}'.trim();
      if (sku == 'WORK-SLOPE-LM') {
        slope = item;
      } else if (sku == 'WORK-EBB-PCS') {
        ebb = item;
      }
    }
    int added = 0;
    for (int i = 0; i < _openings.length; i++) {
      final _OpeningDraft o = _openings[i];
      final double p = o.perimeterLm;
      if (slope != null && p > 0) {
        final int q = p.ceil();
        final String typeRu = o.isWindow ? 'окно' : 'дверь';
        final CatalogItem row = slope.withMergedRaw(
          title: '${slope.title} (проём ${i + 1})',
          subtitle:
              '$typeRu • ${_formatOpeningLm(o.widthM)}×${_formatOpeningLm(o.heightM)} м',
          rawPatch: <String, dynamic>{'line_instance': 'opening_${i}_slope'},
        );
        EstimateService.addItem(row, quantity: q);
        added += 1;
      }
      if (ebb != null && o.isWindow) {
        final CatalogItem row = ebb.withMergedRaw(
          title: '${ebb.title} (проём ${i + 1})',
          subtitle:
              'окно • ${_formatOpeningLm(o.widthM)}×${_formatOpeningLm(o.heightM)} м',
          rawPatch: <String, dynamic>{'line_instance': 'opening_${i}_ebb'},
        );
        EstimateService.addItem(row, quantity: 1);
        added += 1;
      }
    }
    if (!mounted) {
      return;
    }
    if (added == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Нет строк: задайте ширину и высоту проёмов; отлив только для типа «Окно».',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Добавлено отдельных строк: $added')));
  }

  void _onEditWorkLineNote(EstimateLine line) {
    _showWorkLineNoteDialog(line);
  }

  Future<void> _showWorkLineNoteDialog(EstimateLine line) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => _WorkLineNoteDialog(
        initialText: '${line.item.raw['line_note'] ?? ''}',
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    EstimateService.updateWorkLineNote(line, result);
  }

  void _onEditWorkLineDiscount(EstimateLine line) {
    _showWorkLineDiscountDialog(line);
  }

  Future<void> _showWorkLineDiscountDialog(EstimateLine line) async {
    final Map<String, double>? result = await showDialog<Map<String, double>>(
      context: context,
      builder: (BuildContext ctx) => _WorkLineDiscountDialog(
        initialPercent: _lineDiscountPercent(line),
        initialFixedRub: _lineDiscountFixed(line),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    EstimateService.updateWorkLineDiscount(
      line,
      percent: result['pct'] ?? 0,
      fixedRub: result['fix'] ?? 0,
    );
  }

  double _lineDiscountPercent(EstimateLine line) {
    final Object? v = line.item.raw['line_discount_percent'];
    if (v == null) {
      return 0;
    }
    if (v is num) {
      return v.toDouble();
    }
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }

  double _lineDiscountFixed(EstimateLine line) {
    final Object? v = line.item.raw['line_discount_fixed_rub'];
    if (v == null) {
      return 0;
    }
    if (v is num) {
      return v.toDouble();
    }
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }

  Future<void> _showLineQuantityDialog(EstimateLine line) async {
    final int? result = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => _LineQuantityDialog(
        initialQuantity: line.quantity,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    EstimateService.updateQuantity(line, result);
  }

  void _onEditLineQuantity(EstimateLine line) {
    _showLineQuantityDialog(line);
  }

  double _catalogListUnitPrice(EstimateLine line) {
    final Object? rawPrice =
        line.item.raw['price'] ?? line.item.raw['price_m2'];
    if (rawPrice is num) {
      return rawPrice.toDouble();
    }
    final String s = '${rawPrice ?? line.item.price ?? ''}'
        .replaceAll(RegExp(r'[^0-9,.]'), '')
        .replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  Future<void> _showLineUnitPriceDialog(EstimateLine line) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => _LineUnitPriceDialog(
        initialUnitPriceRub: line.price,
        catalogHintRub: _catalogListUnitPrice(line),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    if (result.isEmpty) {
      EstimateService.updateLineUnitPrice(line, null);
      return;
    }
    final double? v = double.tryParse(result.replaceAll(',', '.'));
    if (v == null || v <= 0) {
      return;
    }
    EstimateService.updateLineUnitPrice(line, v);
  }

  void _onEditLineUnitPrice(EstimateLine line) {
    _showLineUnitPriceDialog(line);
  }

  Future<void> _showEstimateDiscountDialog() async {
    final Map<String, double>? result = await showDialog<Map<String, double>>(
      context: context,
      builder: (BuildContext ctx) => _EstimateDiscountDialog(
        initialPercent: _estimateDiscountPercent,
        initialFixedRub: _estimateDiscountRub,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _estimateDiscountPercent = result['pct'] ?? 0;
      _estimateDiscountRub = result['fix'] ?? 0;
    });
  }

  void _clearEstimate() {
    setState(() {
      _estimateDiscountPercent = 0;
      _estimateDiscountRub = 0;
      _wastePercentController.text = '5';
    });
    EstimateService.clear();
  }

  void _addDefaultWorks(List<CatalogItem> items) {
    final EstimateCalculationInput? input = _readCalculationInput();
    if (input == null) {
      return;
    }
    int added = 0;
    for (final CatalogItem item in items) {
      if (item.raw['is_default'] == true || item.raw['is_default'] == 1) {
        final int q = EstimateService.quantityForWork(item, input);
        if (q < 1) {
          continue;
        }
        EstimateService.addItem(item, quantity: q);
        added += 1;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added > 0 ? 'Работы добавлены' : 'Нет типовых работ'),
      ),
    );
  }

  Future<void> _submitEstimate(SavedEstimate estimate) async {
    if (_submittingEstimateId != null) {
      return;
    }
    final bool ok = await AuthFlow.ensureLoggedIn(
      context,
      title: 'Вход для заявки',
      body:
          'Отправить смету как заявку можно после входа в аккаунт. До входа '
          'доступны каталог, расчёт сметы и экспорт (текст/PDF); сохранение '
          'сметы на сервере — после входа.',
    );
    if (!ok || !mounted) {
      return;
    }
    setState(() => _submittingEstimateId = estimate.id);
    final SaveEstimateResult result = await EstimateApiService.submitSaved(
      estimate.id,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _submittingEstimateId = null;
      if (result.ok) {
        _savedEstimatesFuture = EstimateApiService.fetchSaved();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok
              ? 'Смета отправлена как заявка'
              : (result.errorMessage ?? 'Не удалось отправить заявку'),
        ),
      ),
    );
  }

  void _showSavedEstimates(List<SavedEstimate> estimates) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.pageBackground,
      builder: (BuildContext context) {
        return _SavedEstimatesSheet(
          estimates: estimates,
          money: _money,
          submittingEstimateId: _submittingEstimateId,
          onOpen: _showSavedEstimateDetails,
          onSubmit: _submitEstimate,
        );
      },
    );
  }

  void _showSavedEstimateDetails(SavedEstimate estimate) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.pageBackground,
      builder: (BuildContext context) {
        return _SavedEstimateDetailsSheet(
          estimate: estimate,
          money: _money,
          isSubmitting: _submittingEstimateId == estimate.id,
          onSubmit: () => _submitEstimate(estimate),
          onShare: () => _shareSavedEstimate(estimate),
          onSharePdf: () => _shareSavedEstimatePdf(estimate),
        );
      },
    );
  }

  Future<void> _shareCurrentEstimate() async {
    final List<EstimateLine> lines = EstimateService.lines.value;
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте позиции в смету')),
      );
      return;
    }
    final String text = EstimateShareText.fromCurrentLines(
      lines: lines,
      title: 'Смета',
      estimateDiscountPercent: _estimateDiscountPercent,
      estimateDiscountRub: _estimateDiscountRub,
      calculation: Map<String, dynamic>.from(_calculationPayload()),
    );
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'Смета'),
    );
  }

  Future<void> _shareSavedEstimate(SavedEstimate estimate) async {
    final String text = EstimateShareText.fromSaved(
      estimate: estimate,
      statusLine: _savedEstimateListSubtitle(estimate),
      requestComment: estimate.requestComment,
    );
    await SharePlus.instance.share(
      ShareParams(text: text, subject: estimate.title),
    );
  }

  Future<void> _shareCurrentEstimatePdf() async {
    final List<EstimateLine> lines = EstimateService.lines.value;
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте позиции в смету')),
      );
      return;
    }
    try {
      final company = await CompanyPdfApiService.fetchForPdf();
      final Uint8List bytes = await EstimatePdfExport.buildFromCurrentLines(
        lines: lines,
        company: company,
        title: 'Смета',
        estimateDiscountPercent: _estimateDiscountPercent,
        estimateDiscountRub: _estimateDiscountRub,
        calculation: Map<String, dynamic>.from(_calculationPayload()),
      );
      if (!mounted) {
        return;
      }
      final String name = 'smeta_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => EstimatePdfPreviewScreen(
            pdfBytes: bytes,
            shareFileName: name,
            shareSubject: 'Смета PDF',
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('PDF: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось создать PDF: $e')),
        );
      }
    }
  }

  Future<void> _shareSavedEstimatePdf(SavedEstimate estimate) async {
    try {
      final company = await CompanyPdfApiService.fetchForPdf();
      final Uint8List bytes = await EstimatePdfExport.buildFromSaved(
        estimate: estimate,
        statusLine: _savedEstimateListSubtitle(estimate),
        company: company,
        requestComment: estimate.requestComment,
      );
      if (!mounted) {
        return;
      }
      final String name = 'smeta_${estimate.id}.pdf';
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => EstimatePdfPreviewScreen(
            pdfBytes: bytes,
            shareFileName: name,
            shareSubject: estimate.title,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('PDF: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось создать PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              color: const Color(0xFFE1E1E1),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 22,
                      color: AppColors.headingText,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Смета 1',
                      textAlign: TextAlign.center,
                      style: AppTextTheme.screenTitle,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Поделиться текстом',
                        onPressed: _shareCurrentEstimate,
                        icon: const Icon(
                          Icons.share_outlined,
                          color: AppColors.headingText,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Поделиться PDF',
                        onPressed: _shareCurrentEstimatePdf,
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          color: AppColors.headingText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      text: 'Материалы',
                      isSelected: _materialsSelected,
                      onTap: () => setState(() => _materialsSelected = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TabButton(
                      text: 'Работы',
                      isSelected: !_materialsSelected,
                      onTap: () => setState(() => _materialsSelected = false),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: EstimateService.lines,
                builder: (BuildContext context, _) {
                  final List<EstimateLine> lines = EstimateService.lines.value;
                  final List<EstimateLine> materialLines =
                      EstimateService.materialLines(lines);
                  final List<EstimateLine> workLines =
                      EstimateService.workLines(lines);
                  if (_materialsSelected && materialLines.isEmpty) {
                    return _EmptyEstimate(
                      onOpenCatalog: () => AppRouter.pushCatalog(context),
                    );
                  }
                  if (_materialsSelected && materialLines.isNotEmpty) {
                    final List<EstimateLine> m = materialLines;
                    final int n = m.length;
                    final int sliverChildCount = n > 0 ? n * 2 - 1 : 0;
                    return CustomScrollView(
                      slivers: <Widget>[
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (BuildContext context, int index) {
                                if (index.isEven) {
                                  final int i = index ~/ 2;
                                  return _EstimateLineTile(
                                    index: i + 1,
                                    line: m[i],
                                    onEditLineNote: _onEditWorkLineNote,
                                    onEditLineDiscount: _onEditWorkLineDiscount,
                                    onEditLineQuantity: _onEditLineQuantity,
                                    onEditLineUnitPrice: _onEditLineUnitPrice,
                                  );
                                }
                                return const Divider(height: 1);
                              },
                              childCount: sliverChildCount,
                            ),
                          ),
                        ),
                        if (lines.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.paddingOf(context).bottom + 8,
                              ),
                              child: _EstimateFooter(
                                lines: lines,
                                isSaving: _isSaving,
                                money: _money,
                                areaController: _areaController,
                                openingAreaController: _openingAreaController,
                                wastePercentController: _wastePercentController,
                                savedEstimatesFuture: _savedEstimatesFuture,
                                estimateDiscountPercent: _estimateDiscountPercent,
                                estimateDiscountRub: _estimateDiscountRub,
                                onApplyArea: _applyAreaToCurrentEstimate,
                                onOpenSavedList: _showSavedEstimates,
                                onRefreshSaved: _refreshSaved,
                                onEstimateDiscount: _showEstimateDiscountDialog,
                                onClear: _clearEstimate,
                                onSave: () => _saveEstimate(lines),
                              ),
                            ),
                          ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: _WorkPricesPanel(
                          future: _workPricesFuture,
                          workLines: workLines,
                          areaController: _areaController,
                          openingAreaController: _openingAreaController,
                          wastePercentController: _wastePercentController,
                          openingPerimeterController:
                              _openingPerimeterController,
                          windowCountController: _windowCountController,
                          cornerLengthController: _cornerLengthController,
                          sealingLengthController: _sealingLengthController,
                          openings: _openings,
                          money: _money,
                          onApplyArea: _applyAreaToCurrentEstimate,
                          onAddDefaultWorks: _addDefaultWorks,
                          onAddWork: _addWorkItem,
                          onAddSlopeEbbFromOpenings: _addSlopeEbbFromOpenings,
                          onAddSlopeEbbPerOpening: _addSlopeEbbPerOpening,
                          onEditLineNote: _onEditWorkLineNote,
                          onEditLineDiscount: _onEditWorkLineDiscount,
                          onEditLineQuantity: _onEditLineQuantity,
                          onEditLineUnitPrice: _onEditLineUnitPrice,
                          onAddOpening: _addOpening,
                          onRemoveOpening: _removeOpening,
                          onOpeningTypeChanged: _setOpeningType,
                          onOpeningSizeChanged: _onOpeningSizeChanged,
                        ),
                      ),
                      if (lines.isNotEmpty)
                        Flexible(
                          fit: FlexFit.loose,
                          flex: 0,
                          child: SingleChildScrollView(
                            child: _EstimateFooter(
                              lines: lines,
                              isSaving: _isSaving,
                              money: _money,
                              areaController: _areaController,
                              openingAreaController: _openingAreaController,
                              wastePercentController: _wastePercentController,
                              savedEstimatesFuture: _savedEstimatesFuture,
                              estimateDiscountPercent: _estimateDiscountPercent,
                              estimateDiscountRub: _estimateDiscountRub,
                              onApplyArea: _applyAreaToCurrentEstimate,
                              onOpenSavedList: _showSavedEstimates,
                              onRefreshSaved: _refreshSaved,
                              onEstimateDiscount: _showEstimateDiscountDialog,
                              onClear: _clearEstimate,
                              onSave: () => _saveEstimate(lines),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyEstimate extends StatelessWidget {
  const _EmptyEstimate({required this.onOpenCatalog});

  final VoidCallback onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 72,
              color: Color(0xFF8D8D8D),
            ),
            const SizedBox(height: 12),
            const Text(
              'Смета пока пустая',
              textAlign: TextAlign.center,
              style: AppTextTheme.sectionTitle,
            ),
            const SizedBox(height: 8),
            const Text(
              'Откройте каталог, выберите товар и нажмите “Добавить в смету”.',
              textAlign: TextAlign.center,
              style: AppTextTheme.body32,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onOpenCatalog,
              child: const Text('Открыть каталог'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimateFooter extends StatelessWidget {
  const _EstimateFooter({
    required this.lines,
    required this.isSaving,
    required this.money,
    required this.areaController,
    required this.openingAreaController,
    required this.wastePercentController,
    required this.savedEstimatesFuture,
    required this.estimateDiscountPercent,
    required this.estimateDiscountRub,
    required this.onApplyArea,
    required this.onOpenSavedList,
    required this.onRefreshSaved,
    required this.onEstimateDiscount,
    required this.onClear,
    required this.onSave,
  });

  final List<EstimateLine> lines;
  final bool isSaving;
  final String Function(double value) money;
  final TextEditingController areaController;
  final TextEditingController openingAreaController;
  final TextEditingController wastePercentController;
  final Future<List<SavedEstimate>> savedEstimatesFuture;
  final double estimateDiscountPercent;
  final double estimateDiscountRub;
  final VoidCallback onApplyArea;
  final ValueChanged<List<SavedEstimate>> onOpenSavedList;
  final VoidCallback onRefreshSaved;
  final VoidCallback onEstimateDiscount;
  final VoidCallback onClear;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final double linesSum = EstimateService.total(lines);
    final double grand = EstimateService.total(
      lines,
      estimateDiscountPercent: estimateDiscountPercent,
      estimateDiscountRub: estimateDiscountRub,
    );
    final bool hasEstimateDiscount =
        estimateDiscountPercent > 0 || estimateDiscountRub > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFEFEFEF),
        border: Border(top: BorderSide(color: Color(0xFFC9C9C9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Итого', style: AppTextTheme.sectionTitle),
              ),
              Text(
                money(grand),
                style: AppTextTheme.sectionTitle,
              ),
            ],
          ),
          if (hasEstimateDiscount) ...[
            const SizedBox(height: 4),
            Text(
              EstimateShareText.estimateDiscountCaption(
                    lineItemsSum: linesSum,
                    totalAmount: grand,
                    calculation: <String, dynamic>{
                      'estimate_discount_percent': estimateDiscountPercent,
                      'estimate_discount_rub': estimateDiscountRub,
                    },
                  ) ??
                  'Скидка на смету',
              style: AppTextTheme.body32.copyWith(color: const Color(0xFF757575)),
            ),
            if ((grand - linesSum).abs() > 0.5) ...[
              const SizedBox(height: 2),
              Text(
                'Было ${money(linesSum)}',
                style: AppTextTheme.body32.copyWith(color: const Color(0xFF757575)),
              ),
            ],
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onEstimateDiscount,
              child: const Text('Скидка на смету'),
            ),
          ),
          const SizedBox(height: 6),
          _AreaCalculator(
            controller: areaController,
            openingAreaController: openingAreaController,
            wastePercentController: wastePercentController,
            onApply: onApplyArea,
          ),
          const SizedBox(height: 10),
          _SavedEstimatesBlock(
            future: savedEstimatesFuture,
            money: money,
            onOpenList: onOpenSavedList,
            onRefresh: onRefreshSaved,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onClear,
                  child: const Text('Очистить'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: isSaving ? null : onSave,
                  child: Text(isSaving ? 'Сохранение...' : 'Сохранить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkPricesPanel extends StatelessWidget {
  const _WorkPricesPanel({
    required this.future,
    required this.workLines,
    required this.areaController,
    required this.openingAreaController,
    required this.wastePercentController,
    required this.openingPerimeterController,
    required this.windowCountController,
    required this.cornerLengthController,
    required this.sealingLengthController,
    required this.openings,
    required this.money,
    required this.onApplyArea,
    required this.onAddDefaultWorks,
    required this.onAddWork,
    required this.onAddSlopeEbbFromOpenings,
    required this.onAddSlopeEbbPerOpening,
    required this.onEditLineNote,
    required this.onEditLineDiscount,
    required this.onEditLineQuantity,
    required this.onEditLineUnitPrice,
    required this.onAddOpening,
    required this.onRemoveOpening,
    required this.onOpeningTypeChanged,
    required this.onOpeningSizeChanged,
  });

  final Future<List<CatalogItem>> future;
  final List<EstimateLine> workLines;
  final TextEditingController areaController;
  final TextEditingController openingAreaController;
  final TextEditingController wastePercentController;
  final TextEditingController openingPerimeterController;
  final TextEditingController windowCountController;
  final TextEditingController cornerLengthController;
  final TextEditingController sealingLengthController;
  final List<_OpeningDraft> openings;
  final String Function(double value) money;
  final VoidCallback onApplyArea;
  final ValueChanged<List<CatalogItem>> onAddDefaultWorks;
  final ValueChanged<CatalogItem> onAddWork;
  final ValueChanged<List<CatalogItem>> onAddSlopeEbbFromOpenings;
  final ValueChanged<List<CatalogItem>> onAddSlopeEbbPerOpening;
  final ValueChanged<EstimateLine> onEditLineNote;
  final ValueChanged<EstimateLine> onEditLineDiscount;
  final ValueChanged<EstimateLine> onEditLineQuantity;
  final ValueChanged<EstimateLine> onEditLineUnitPrice;
  final VoidCallback onAddOpening;
  final ValueChanged<int> onRemoveOpening;
  final void Function(int index, bool isWindow) onOpeningTypeChanged;
  final VoidCallback onOpeningSizeChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CatalogItem>>(
      future: future,
      builder:
          (BuildContext context, AsyncSnapshot<List<CatalogItem>> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _WorkPricesError(message: '${snapshot.error}');
            }
            final List<CatalogItem> items =
                snapshot.data ?? const <CatalogItem>[];
            if (items.isEmpty) {
              return const Center(
                child: Text('Прайс работ пустой', style: AppTextTheme.body32),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _CalculationInputsCard(
                  areaController: areaController,
                  openingAreaController: openingAreaController,
                  wastePercentController: wastePercentController,
                  openingPerimeterController: openingPerimeterController,
                  windowCountController: windowCountController,
                  cornerLengthController: cornerLengthController,
                  sealingLengthController: sealingLengthController,
                  openings: openings,
                  onApply: onApplyArea,
                  onAddOpening: onAddOpening,
                  onRemoveOpening: onRemoveOpening,
                  onOpeningTypeChanged: onOpeningTypeChanged,
                  onOpeningSizeChanged: onOpeningSizeChanged,
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => onAddDefaultWorks(items),
                  child: const Text('Добавить типовые работы по площади'),
                ),
                if (openings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => onAddSlopeEbbFromOpenings(items),
                  child: const Text('В смету: откосы и отливы (сводно)'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => onAddSlopeEbbPerOpening(items),
                  child: const Text('В смету: откосы и отливы по каждому проёму'),
                ),
                ],
                if (workLines.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Добавленные работы',
                    style: AppTextTheme.sectionTitle,
                  ),
                  const SizedBox(height: 4),
                  ...workLines.asMap().entries.map(
                    (MapEntry<int, EstimateLine> entry) => _EstimateLineTile(
                      index: entry.key + 1,
                      line: entry.value,
                      onEditLineNote: onEditLineNote,
                      onEditLineDiscount: onEditLineDiscount,
                      onEditLineQuantity: onEditLineQuantity,
                      onEditLineUnitPrice: onEditLineUnitPrice,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Text('Прайс работ', style: AppTextTheme.sectionTitle),
                const SizedBox(height: 8),
                ...items.map(
                  (CatalogItem item) => _WorkPriceTile(
                    item: item,
                    money: money,
                    onAdd: () => onAddWork(item),
                  ),
                ),
              ],
            );
          },
    );
  }
}

class _WorkPricesError extends StatelessWidget {
  const _WorkPricesError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Не удалось загрузить прайс работ\n$message',
          textAlign: TextAlign.center,
          style: AppTextTheme.body32,
        ),
      ),
    );
  }
}

class _WorkPriceTile extends StatelessWidget {
  const _WorkPriceTile({
    required this.item,
    required this.money,
    required this.onAdd,
  });

  final CatalogItem item;
  final String Function(double value) money;
  final VoidCallback onAdd;

  double get _price {
    final String raw = item.price ?? '';
    final String normalized = raw
        .replaceAll(RegExp(r'[^0-9,.]'), '')
        .replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTextTheme.body34.copyWith(
                    color: AppColors.headingText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${money(_price)} / ${item.unit ?? 'шт'}',
                  style: AppTextTheme.body32,
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: AppTextSizes.s28,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onAdd, child: const Text('Добавить')),
        ],
      ),
    );
  }
}

class _AreaCalculator extends StatelessWidget {
  const _AreaCalculator({
    required this.controller,
    required this.openingAreaController,
    required this.wastePercentController,
    required this.onApply,
  });

  final TextEditingController controller;
  final TextEditingController openingAreaController;
  final TextEditingController wastePercentController;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Площадь фасада, м²',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: openingAreaController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Проемы, м²',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  controller: wastePercentController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Запас, %',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'К нетто площади (фасад минус проёмы). До 50%.',
                  softWrap: true,
                  style: AppTextTheme.body32.copyWith(
                    color: const Color(0xFF757575),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: onApply, child: const Text('Рассчитать')),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalculationInputsCard extends StatelessWidget {
  const _CalculationInputsCard({
    required this.areaController,
    required this.openingAreaController,
    required this.wastePercentController,
    required this.openingPerimeterController,
    required this.windowCountController,
    required this.cornerLengthController,
    required this.sealingLengthController,
    required this.openings,
    required this.onApply,
    required this.onAddOpening,
    required this.onRemoveOpening,
    required this.onOpeningTypeChanged,
    required this.onOpeningSizeChanged,
  });

  final TextEditingController areaController;
  final TextEditingController openingAreaController;
  final TextEditingController wastePercentController;
  final TextEditingController openingPerimeterController;
  final TextEditingController windowCountController;
  final TextEditingController cornerLengthController;
  final TextEditingController sealingLengthController;
  final List<_OpeningDraft> openings;
  final VoidCallback onApply;
  final VoidCallback onAddOpening;
  final ValueChanged<int> onRemoveOpening;
  final void Function(int index, bool isWindow) onOpeningTypeChanged;
  final VoidCallback onOpeningSizeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Параметры расчета', style: AppTextTheme.sectionTitle),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CalcField(
                  controller: areaController,
                  label: 'Фасад, м²',
                  decimal: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CalcField(
                  controller: openingAreaController,
                  label: 'Проемы, м²',
                  decimal: true,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 88,
                child: _CalcField(
                  controller: wastePercentController,
                  label: 'Запас, %',
                  decimal: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text('Окна и двери', style: AppTextTheme.body34),
              ),
              TextButton.icon(
                onPressed: onAddOpening,
                icon: const Icon(Icons.add),
                label: const Text('Добавить'),
              ),
            ],
          ),
          if (openings.isEmpty)
            const Text(
              'Можно ввести суммарные проемы вручную или добавить окна/двери списком.',
              style: AppTextTheme.body32,
            )
          else
            ...openings.asMap().entries.map(
              (MapEntry<int, _OpeningDraft> entry) => _OpeningRow(
                index: entry.key,
                opening: entry.value,
                onRemove: () => onRemoveOpening(entry.key),
                onTypeChanged: (bool isWindow) =>
                    onOpeningTypeChanged(entry.key, isWindow),
                onSizeChanged: onOpeningSizeChanged,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _CalcField(
                  controller: openingPerimeterController,
                  label: 'Периметр проемов, м',
                  decimal: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CalcField(
                  controller: windowCountController,
                  label: 'Окна, шт',
                  decimal: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _CalcField(
                  controller: cornerLengthController,
                  label: 'Углы, м',
                  decimal: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CalcField(
                  controller: sealingLengthController,
                  label: 'Примыкания, м',
                  decimal: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: onApply, child: const Text('Пересчитать')),
        ],
      ),
    );
  }
}

class _CalcField extends StatelessWidget {
  const _CalcField({
    required this.controller,
    required this.label,
    required this.decimal,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool decimal;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _OpeningRow extends StatelessWidget {
  const _OpeningRow({
    required this.index,
    required this.opening,
    required this.onRemove,
    required this.onTypeChanged,
    required this.onSizeChanged,
  });

  final int index;
  final _OpeningDraft opening;
  final VoidCallback onRemove;
  final ValueChanged<bool> onTypeChanged;
  final VoidCallback onSizeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Проем ${index + 1}',
                  style: AppTextTheme.body34.copyWith(
                    color: AppColors.headingText,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => onTypeChanged(!opening.isWindow),
                child: Text(opening.isWindow ? 'Окно' : 'Дверь'),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _CalcField(
                  controller: opening.widthController,
                  label: 'Ширина, м',
                  decimal: true,
                  onChanged: onSizeChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CalcField(
                  controller: opening.heightController,
                  label: 'Высота, м',
                  decimal: true,
                  onChanged: onSizeChanged,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              opening.perimeterLm > 0
                  ? 'Откосы: ${_formatOpeningLm(opening.perimeterLm)} п.м. • Отлив: ${opening.isWindow ? '1 шт' : '—'}'
                  : 'Укажите ширину и высоту — для расчёта откосов по этому проёму',
              style: const TextStyle(
                color: Color(0xFF757575),
                fontSize: AppTextSizes.s28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatOpeningLm(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

class _LineQuantityDialog extends StatefulWidget {
  const _LineQuantityDialog({required this.initialQuantity});

  final int initialQuantity;

  @override
  State<_LineQuantityDialog> createState() => _LineQuantityDialogState();
}

class _LineQuantityDialogState extends State<_LineQuantityDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialQuantity}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final int? q = int.tryParse(_controller.text.trim());
    if (q == null || q < 1) {
      setState(() => _error = 'Введите целое число не меньше 1');
      return;
    }
    if (q > 999999) {
      setState(() => _error = 'Слишком большое значение');
      return;
    }
    Navigator.of(context).pop(q);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Количество'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Штук',
          errorText: _error,
        ),
        onChanged: (_) => setState(() => _error = null),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _LineUnitPriceDialog extends StatefulWidget {
  const _LineUnitPriceDialog({
    required this.initialUnitPriceRub,
    required this.catalogHintRub,
  });

  final double initialUnitPriceRub;
  final double catalogHintRub;

  @override
  State<_LineUnitPriceDialog> createState() => _LineUnitPriceDialogState();
}

class _LineUnitPriceDialogState extends State<_LineUnitPriceDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    final double v = widget.initialUnitPriceRub;
    _controller = TextEditingController(
      text: v > 0 ? v.toString().replaceAll(RegExp(r'\.0$'), '') : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearToCatalog() {
    Navigator.of(context).pop('');
  }

  void _submit() {
    final String trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      Navigator.of(context).pop('');
      return;
    }
    final double? v = double.tryParse(trimmed.replaceAll(',', '.'));
    if (v == null || v <= 0) {
      setState(() => _error = 'Введите положительное число');
      return;
    }
    Navigator.of(context).pop(v.toString());
  }

  @override
  Widget build(BuildContext context) {
    final String hint = widget.catalogHintRub > 0
        ? 'Каталог: ${widget.catalogHintRub.round()} ₽ за ед. Оставьте поле пустым или нажмите «Как в каталоге», чтобы убрать ручную цену.'
        : 'Оставьте поле пустым или нажмите «Как в каталоге», чтобы брать цену из каталога.';
    return AlertDialog(
      title: const Text('Цена за единицу'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hint,
            style: const TextStyle(fontSize: AppTextSizes.s28, color: Color(0xFF757575)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '₽ за единицу',
              errorText: _error,
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: _clearToCatalog,
          child: const Text('Как в каталоге'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _WorkLineNoteDialog extends StatefulWidget {
  const _WorkLineNoteDialog({required this.initialText});

  final String initialText;

  @override
  State<_WorkLineNoteDialog> createState() => _WorkLineNoteDialogState();
}

class _WorkLineNoteDialogState extends State<_WorkLineNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Примечание к позиции'),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Например, доступ, условия монтажа…',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _WorkLineDiscountDialog extends StatefulWidget {
  const _WorkLineDiscountDialog({
    required this.initialPercent,
    required this.initialFixedRub,
  });

  final double initialPercent;
  final double initialFixedRub;

  @override
  State<_WorkLineDiscountDialog> createState() =>
      _WorkLineDiscountDialogState();
}

class _WorkLineDiscountDialogState extends State<_WorkLineDiscountDialog> {
  late final TextEditingController _percentController;
  late final TextEditingController _fixedController;

  @override
  void initState() {
    super.initState();
    _percentController = TextEditingController(
      text: widget.initialPercent > 0
          ? widget.initialPercent.toString().replaceAll('.', ',')
          : '',
    );
    _fixedController = TextEditingController(
      text: widget.initialFixedRub > 0
          ? widget.initialFixedRub.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _percentController.dispose();
    _fixedController.dispose();
    super.dispose();
  }

  void _save() {
    final double pct = double.tryParse(
          _percentController.text.replaceAll(',', '.').trim(),
        ) ??
        0;
    final double fix = double.tryParse(
          _fixedController.text.replaceAll(',', '.').trim(),
        ) ??
        0;
    Navigator.of(context).pop(<String, double>{
      'pct': pct.clamp(0, 100),
      'fix': fix < 0 ? 0 : fix,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Скидка на позицию'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Сначала применяется процент к сумме строки, затем вычитается фиксированная сумма (как в приложении).',
            style: TextStyle(fontSize: AppTextSizes.s28, color: Color(0xFF757575)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _percentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Процент, %',
              hintText: '0',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _fixedController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Фиксированно, ₽',
              hintText: '0',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _EstimateDiscountDialog extends StatefulWidget {
  const _EstimateDiscountDialog({
    required this.initialPercent,
    required this.initialFixedRub,
  });

  final double initialPercent;
  final double initialFixedRub;

  @override
  State<_EstimateDiscountDialog> createState() =>
      _EstimateDiscountDialogState();
}

class _EstimateDiscountDialogState extends State<_EstimateDiscountDialog> {
  late final TextEditingController _percentController;
  late final TextEditingController _fixedController;

  @override
  void initState() {
    super.initState();
    _percentController = TextEditingController(
      text: widget.initialPercent > 0
          ? widget.initialPercent.toString().replaceAll('.', ',')
          : '',
    );
    _fixedController = TextEditingController(
      text: widget.initialFixedRub > 0
          ? widget.initialFixedRub.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _percentController.dispose();
    _fixedController.dispose();
    super.dispose();
  }

  void _save() {
    final double pct = double.tryParse(
          _percentController.text.replaceAll(',', '.').trim(),
        ) ??
        0;
    final double fix = double.tryParse(
          _fixedController.text.replaceAll(',', '.').trim(),
        ) ??
        0;
    Navigator.of(context).pop(<String, double>{
      'pct': pct.clamp(0, 100),
      'fix': fix < 0 ? 0 : fix,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Скидка на смету'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Процент и фикс применяются к итогу после скидок по строкам.',
            style: TextStyle(fontSize: AppTextSizes.s28, color: Color(0xFF757575)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _percentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Процент, %',
              hintText: '0',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _fixedController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Фиксированно, ₽',
              hintText: '0',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _SavedEstimatesBlock extends StatelessWidget {
  const _SavedEstimatesBlock({
    required this.future,
    required this.money,
    required this.onOpenList,
    required this.onRefresh,
  });

  final Future<List<SavedEstimate>> future;
  final String Function(double value) money;
  final ValueChanged<List<SavedEstimate>> onOpenList;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SavedEstimate>>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<List<SavedEstimate>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final List<SavedEstimate> estimates =
            snapshot.data ?? const <SavedEstimate>[];
        if (estimates.isEmpty) {
          return const SizedBox.shrink();
        }
        final SavedEstimate latest = estimates.first;
        final String? latestDiscount = EstimateShareText.estimateDiscountCaption(
          lineItemsSum: latest.items.fold<double>(
            0,
            (double s, SavedEstimateItem i) => s + i.totalPrice,
          ),
          totalAmount: latest.totalAmount,
          calculation: latest.calculation,
        );
        return InkWell(
          onTap: () => onOpenList(estimates),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.save_outlined, color: AppColors.headingText),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Сохранено: ${estimates.length}. Последняя: ${latest.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.body32,
                      ),
                      if (latestDiscount != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          latestDiscount,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF8D6E63),
                            fontSize: AppTextSizes.s28,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(money(latest.totalAmount), style: AppTextTheme.body32),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SavedEstimatesSheet extends StatelessWidget {
  const _SavedEstimatesSheet({
    required this.estimates,
    required this.money,
    required this.submittingEstimateId,
    required this.onOpen,
    required this.onSubmit,
  });

  final List<SavedEstimate> estimates;
  final String Function(double value) money;
  final int? submittingEstimateId;
  final ValueChanged<SavedEstimate> onOpen;
  final ValueChanged<SavedEstimate> onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (BuildContext context, ScrollController scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Сохраненные сметы',
                        style: AppTextTheme.sectionTitle,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: estimates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final SavedEstimate estimate = estimates[index];
                    final bool isSubmitted = estimate.hasEstimateRequest;
                    final bool isSubmitting =
                        submittingEstimateId == estimate.id;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  estimate.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextTheme.body34.copyWith(
                                    color: AppColors.headingText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                money(estimate.totalAmount),
                                style: AppTextTheme.body34,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${estimate.itemsCount} поз. • ${_savedEstimateListSubtitle(estimate)}',
                            style: const TextStyle(
                              color: Color(0xFF757575),
                              fontSize: AppTextSizes.s28,
                            ),
                          ),
                          if (EstimateShareText.estimateDiscountCaption(
                                lineItemsSum: estimate.items.fold<double>(
                                  0,
                                  (double s, SavedEstimateItem i) =>
                                      s + i.totalPrice,
                                ),
                                totalAmount: estimate.totalAmount,
                                calculation: estimate.calculation,
                              )
                              case final String discountLine) ...[
                            const SizedBox(height: 2),
                            Text(
                              discountLine,
                              style: const TextStyle(
                                color: Color(0xFF8D6E63),
                                fontSize: AppTextSizes.s28,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => onOpen(estimate),
                                  child: const Text('Открыть'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: isSubmitted || isSubmitting
                                      ? null
                                      : () => onSubmit(estimate),
                                  child: Text(
                                    isSubmitted
                                        ? 'Заявка'
                                        : isSubmitting
                                        ? 'Отправка...'
                                        : 'В заявку',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SavedEstimateDetailsSheet extends StatelessWidget {
  const _SavedEstimateDetailsSheet({
    required this.estimate,
    required this.money,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onShare,
    required this.onSharePdf,
  });

  final SavedEstimate estimate;
  final String Function(double value) money;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final VoidCallback onShare;
  final VoidCallback onSharePdf;

  @override
  Widget build(BuildContext context) {
    final bool isSubmitted = estimate.hasEstimateRequest;
    final double linesSum = estimate.items.fold<double>(
      0,
      (double s, SavedEstimateItem i) => s + i.totalPrice,
    );
    final String? discountCaption = EstimateShareText.estimateDiscountCaption(
      lineItemsSum: linesSum,
      totalAmount: estimate.totalAmount,
      calculation: estimate.calculation,
    );
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (BuildContext context, ScrollController scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        estimate.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.sectionTitle,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Поделиться текстом',
                      onPressed: onShare,
                      icon: const Icon(Icons.share_outlined),
                    ),
                    IconButton(
                      tooltip: 'Поделиться PDF',
                      onPressed: onSharePdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      '${_savedEstimateListSubtitle(estimate)} • ${money(estimate.totalAmount)}',
                      style: AppTextTheme.body32,
                    ),
                    if (discountCaption != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        discountCaption,
                        style: const TextStyle(
                          color: Color(0xFF8D6E63),
                          fontSize: AppTextSizes.s28,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: estimate.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final SavedEstimateItem item = estimate.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            item.name,
                            style: AppTextTheme.body34.copyWith(
                              color: AppColors.headingText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.quantity} ${item.unit} • ${money(item.totalPrice)}',
                            style: AppTextTheme.body32,
                          ),
                          if (item.sku != null || item.color != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (item.sku != null) 'арт. ${item.sku}',
                                if (item.color != null) item.color!,
                              ].join(' • '),
                              style: const TextStyle(
                                color: Color(0xFF757575),
                                fontSize: AppTextSizes.s28,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton(
                  onPressed: isSubmitted || isSubmitting ? null : onSubmit,
                  child: Text(
                    isSubmitted
                        ? 'Уже отправлена как заявка'
                        : isSubmitting
                        ? 'Отправка...'
                        : 'Отправить как заявку',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _savedEstimateListSubtitle(SavedEstimate estimate) {
  if (estimate.hasEstimateRequest) {
    return _statusLabel('submitted');
  }
  if (estimate.status == 'submitted') {
    return 'заявка не на сервере — отправьте снова';
  }
  return _statusLabel(estimate.status);
}

String _statusLabel(String status) {
  switch (status) {
    case 'submitted':
      return 'заявка отправлена';
    case 'draft':
    case '':
      return 'черновик';
    default:
      return status;
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: isSelected
            ? AppColors.onAccent
            : AppColors.headingText,
        backgroundColor: isSelected
            ? AppColors.primaryButtonBackground
            : AppColors.pageBackground,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          side: BorderSide(
            color: isSelected
                ? AppColors.primaryButtonBackground
                : const Color(0xFFC9C9C9),
          ),
        ),
      ),
      child: Text(text, style: const TextStyle(fontSize: AppTextSizes.s38)),
    );
  }
}

class _EstimateLineTile extends StatelessWidget {
  const _EstimateLineTile({
    required this.index,
    required this.line,
    required this.onEditLineNote,
    required this.onEditLineDiscount,
    required this.onEditLineQuantity,
    required this.onEditLineUnitPrice,
  });

  final int index;
  final EstimateLine line;
  final ValueChanged<EstimateLine> onEditLineNote;
  final ValueChanged<EstimateLine> onEditLineDiscount;
  final ValueChanged<EstimateLine> onEditLineQuantity;
  final ValueChanged<EstimateLine> onEditLineUnitPrice;

  bool get _hasManualUnitPrice {
    final Object? o = line.item.raw['line_unit_price_rub'];
    if (o == null) {
      return false;
    }
    final double p = o is num
        ? o.toDouble()
        : double.tryParse(o.toString().replaceAll(',', '.').trim()) ?? 0;
    return p > 0;
  }

  String _money(double value) {
    if (value == 0) {
      return 'по запросу';
    }
    return '${value.toStringAsFixed(0)} ₽';
  }

  @override
  Widget build(BuildContext context) {
    final String unit = line.item.unit == null || line.item.unit!.isEmpty
        ? 'шт'
        : line.item.unit!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text('$index', style: AppTextTheme.body33),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextTheme.body34.copyWith(
                        color: AppColors.headingText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${line.item.categoryLabel ?? line.item.category} • $unit',
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: AppTextSizes.s28,
                      ),
                    ),
                    if ('${line.item.raw['line_note'] ?? ''}'.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Примечание: ${line.item.raw['line_note']}',
                          style: AppTextTheme.body32.copyWith(
                            color: const Color(0xFF5D4037),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (line.hasLineDiscount) ...[
                    Text(
                      _money(line.subtotal),
                      style: AppTextTheme.body33.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: const Color(0xFF9E9E9E),
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    _money(line.total),
                    style: const TextStyle(
                      color: AppColors.headingText,
                      fontSize: AppTextSizes.s32,
                      fontWeight: AppTextWeights.medium,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Цена: ${_money(line.price)}', style: AppTextTheme.body33),
                    if (_hasManualUnitPrice)
                      Text(
                        'цена за ед. задана вручную',
                        style: AppTextTheme.body32.copyWith(
                          color: const Color(0xFF757575),
                          fontSize: AppTextSizes.s26,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Примечание к позиции',
                onPressed: () => onEditLineNote(line),
                icon: const Icon(Icons.edit_note_outlined, size: 22),
              ),
              IconButton(
                tooltip: 'Скидка на позицию',
                onPressed: () => onEditLineDiscount(line),
                icon: const Icon(Icons.percent_outlined, size: 22),
              ),
              IconButton(
                tooltip: 'Цена за единицу',
                onPressed: () => onEditLineUnitPrice(line),
                icon: const Icon(Icons.payments_outlined, size: 22),
              ),
              IconButton(
                onPressed: () {
                  EstimateService.updateQuantity(line, line.quantity - 1);
                },
                icon: const Icon(Icons.remove_circle_outline),
              ),
              InkWell(
                onTap: () => onEditLineQuantity(line),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text('${line.quantity}', style: AppTextTheme.body34),
                ),
              ),
              IconButton(
                onPressed: () {
                  EstimateService.updateQuantity(line, line.quantity + 1);
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                onPressed: () => EstimateService.removeLine(line),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
