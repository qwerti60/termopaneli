import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/services/catalog_api_service.dart';
import 'package:termopaneli_app/services/estimate_api_service.dart';
import 'package:termopaneli_app/services/estimate_service.dart';
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
  final TextEditingController _openingAreaController = TextEditingController();
  final TextEditingController _openingPerimeterController =
      TextEditingController();
  final TextEditingController _windowCountController = TextEditingController();
  final TextEditingController _cornerLengthController = TextEditingController();
  final TextEditingController _sealingLengthController =
      TextEditingController();
  final List<_OpeningDraft> _openings = <_OpeningDraft>[];

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

  Future<void> _saveEstimate(List<EstimateLine> lines) async {
    if (_isSaving) {
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
    );
  }

  void _applyAreaToCurrentEstimate() {
    final EstimateCalculationInput? input = _readCalculationInput();
    if (input == null) {
      return;
    }
    final int changed = EstimateService.applyArea(input.netFacadeAreaM2);
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
    EstimateService.addItem(item, quantity: quantity);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Работа добавлена: ${item.title}')));
  }

  void _addDefaultWorks(List<CatalogItem> items) {
    final EstimateCalculationInput? input = _readCalculationInput();
    if (input == null) {
      return;
    }
    int added = 0;
    for (final CatalogItem item in items) {
      if (item.raw['is_default'] == true || item.raw['is_default'] == 1) {
        EstimateService.addItem(
          item,
          quantity: EstimateService.quantityForWork(item, input),
        );
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
        );
      },
    );
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
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Text(
                      '22.10.24',
                      style: TextStyle(
                        color: AppColors.headingText,
                        fontSize: AppTextSizes.s34,
                      ),
                    ),
                  ),
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
                  final List<EstimateLine> visibleLines = _materialsSelected
                      ? materialLines
                      : workLines;
                  if (_materialsSelected && materialLines.isEmpty) {
                    return _EmptyEstimate(
                      onOpenCatalog: () => AppRouter.pushCatalog(context),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: _materialsSelected
                            ? _EstimateLinesList(lines: visibleLines)
                            : _WorkPricesPanel(
                                future: _workPricesFuture,
                                workLines: workLines,
                                areaController: _areaController,
                                openingAreaController: _openingAreaController,
                                openingPerimeterController:
                                    _openingPerimeterController,
                                windowCountController: _windowCountController,
                                cornerLengthController: _cornerLengthController,
                                sealingLengthController:
                                    _sealingLengthController,
                                openings: _openings,
                                money: _money,
                                onApplyArea: _applyAreaToCurrentEstimate,
                                onAddDefaultWorks: _addDefaultWorks,
                                onAddWork: _addWorkItem,
                                onAddOpening: _addOpening,
                                onRemoveOpening: _removeOpening,
                                onOpeningTypeChanged: _setOpeningType,
                                onOpeningSizeChanged: _onOpeningSizeChanged,
                              ),
                      ),
                      if (lines.isNotEmpty)
                        _EstimateFooter(
                          lines: lines,
                          isSaving: _isSaving,
                          money: _money,
                          areaController: _areaController,
                          openingAreaController: _openingAreaController,
                          savedEstimatesFuture: _savedEstimatesFuture,
                          onApplyArea: _applyAreaToCurrentEstimate,
                          onOpenSavedList: _showSavedEstimates,
                          onRefreshSaved: _refreshSaved,
                          onClear: EstimateService.clear,
                          onSave: () => _saveEstimate(lines),
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

class _EstimateLinesList extends StatelessWidget {
  const _EstimateLinesList({required this.lines});

  final List<EstimateLine> lines;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: lines.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        return _EstimateLineTile(index: index + 1, line: lines[index]);
      },
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
    required this.savedEstimatesFuture,
    required this.onApplyArea,
    required this.onOpenSavedList,
    required this.onRefreshSaved,
    required this.onClear,
    required this.onSave,
  });

  final List<EstimateLine> lines;
  final bool isSaving;
  final String Function(double value) money;
  final TextEditingController areaController;
  final TextEditingController openingAreaController;
  final Future<List<SavedEstimate>> savedEstimatesFuture;
  final VoidCallback onApplyArea;
  final ValueChanged<List<SavedEstimate>> onOpenSavedList;
  final VoidCallback onRefreshSaved;
  final VoidCallback onClear;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
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
                money(EstimateService.total(lines)),
                style: AppTextTheme.sectionTitle,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AreaCalculator(
            controller: areaController,
            openingAreaController: openingAreaController,
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
    required this.openingPerimeterController,
    required this.windowCountController,
    required this.cornerLengthController,
    required this.sealingLengthController,
    required this.openings,
    required this.money,
    required this.onApplyArea,
    required this.onAddDefaultWorks,
    required this.onAddWork,
    required this.onAddOpening,
    required this.onRemoveOpening,
    required this.onOpeningTypeChanged,
    required this.onOpeningSizeChanged,
  });

  final Future<List<CatalogItem>> future;
  final List<EstimateLine> workLines;
  final TextEditingController areaController;
  final TextEditingController openingAreaController;
  final TextEditingController openingPerimeterController;
  final TextEditingController windowCountController;
  final TextEditingController cornerLengthController;
  final TextEditingController sealingLengthController;
  final List<_OpeningDraft> openings;
  final String Function(double value) money;
  final VoidCallback onApplyArea;
  final ValueChanged<List<CatalogItem>> onAddDefaultWorks;
  final ValueChanged<CatalogItem> onAddWork;
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
    required this.onApply,
  });

  final TextEditingController controller;
  final TextEditingController openingAreaController;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Row(
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
          const SizedBox(width: 10),
          FilledButton(onPressed: onApply, child: const Text('Рассчитать')),
        ],
      ),
    );
  }
}

class _CalculationInputsCard extends StatelessWidget {
  const _CalculationInputsCard({
    required this.areaController,
    required this.openingAreaController,
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
        ],
      ),
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
        return InkWell(
          onTap: () => onOpenList(estimates),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.save_outlined, color: AppColors.headingText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Сохранено: ${estimates.length}. Последняя: ${latest.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextTheme.body32,
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
                    final bool isSubmitted = estimate.status == 'submitted';
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
                            '${estimate.itemsCount} поз. • ${_statusLabel(estimate.status)}',
                            style: const TextStyle(
                              color: Color(0xFF757575),
                              fontSize: AppTextSizes.s28,
                            ),
                          ),
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
  });

  final SavedEstimate estimate;
  final String Function(double value) money;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bool isSubmitted = estimate.status == 'submitted';
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${_statusLabel(estimate.status)} • ${money(estimate.totalAmount)}',
                  style: AppTextTheme.body32,
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
  const _EstimateLineTile({required this.index, required this.line});

  final int index;
  final EstimateLine line;

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
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Цена: ${_money(line.price)}', style: AppTextTheme.body33),
              const Spacer(),
              IconButton(
                onPressed: () {
                  EstimateService.updateQuantity(line, line.quantity - 1);
                },
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('${line.quantity}', style: AppTextTheme.body34),
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
