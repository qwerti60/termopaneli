import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/services/estimate_api_service.dart';
import 'package:termopaneli_app/services/estimate_service.dart';

class EstimateScreen extends StatefulWidget {
  const EstimateScreen({super.key});

  @override
  State<EstimateScreen> createState() => _EstimateScreenState();
}

class _EstimateScreenState extends State<EstimateScreen> {
  bool _materialsSelected = true;
  bool _isSaving = false;
  late Future<List<SavedEstimate>> _savedEstimatesFuture;

  @override
  void initState() {
    super.initState();
    _savedEstimatesFuture = EstimateApiService.fetchSaved();
  }

  String _money(double value) {
    if (value == 0) {
      return 'по запросу';
    }
    return '${value.toStringAsFixed(0)} ₽';
  }

  Future<void> _saveEstimate(List<EstimateLine> lines) async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    final SaveEstimateResult result = await EstimateApiService.saveCurrent(
      lines: lines,
      title: 'Смета ${DateTime.now().toLocal().toString().substring(0, 16)}',
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
                  if (!_materialsSelected) {
                    return const Center(
                      child: Text(
                        'Работы добавим следующим этапом',
                        style: AppTextTheme.body32,
                      ),
                    );
                  }
                  if (lines.isEmpty) {
                    return _EmptyEstimate(
                      onOpenCatalog: () => AppRouter.pushCatalog(context),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: lines.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (BuildContext context, int index) {
                            return _EstimateLineTile(
                              index: index + 1,
                              line: lines[index],
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEFEFEF),
                          border: Border(
                            top: BorderSide(color: Color(0xFFC9C9C9)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Итого',
                                    style: AppTextTheme.sectionTitle,
                                  ),
                                ),
                                Text(
                                  _money(EstimateService.total(lines)),
                                  style: AppTextTheme.sectionTitle,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _SavedEstimatesBlock(
                              future: _savedEstimatesFuture,
                              money: _money,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: EstimateService.clear,
                                    child: const Text('Очистить'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _isSaving
                                        ? null
                                        : () => _saveEstimate(lines),
                                    child: Text(
                                      _isSaving ? 'Сохранение...' : 'Сохранить',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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

class _SavedEstimatesBlock extends StatelessWidget {
  const _SavedEstimatesBlock({required this.future, required this.money});

  final Future<List<SavedEstimate>> future;
  final String Function(double value) money;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SavedEstimate>>(
      future: future,
      builder:
          (BuildContext context, AsyncSnapshot<List<SavedEstimate>> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox.shrink();
            }
            final List<SavedEstimate> estimates =
                snapshot.data ?? const <SavedEstimate>[];
            if (estimates.isEmpty) {
              return const SizedBox.shrink();
            }
            final SavedEstimate latest = estimates.first;
            return Container(
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
                ],
              ),
            );
          },
    );
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
