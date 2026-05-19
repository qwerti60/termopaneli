import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/services/catalog_api_service.dart';
import 'package:termopaneli_app/services/estimate_service.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, this.item});

  final CatalogItem? item;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  bool _showCharacteristics = true;
  int _quantity = 1;

  static const String _defaultThermoPanelDescription =
      'Фасадные термопанели с клинкерной плиткой подходят для '
      'наружной отделки дома, обеспечивают долговечность и '
      'теплоизоляцию.';

  String _descriptionBody() {
    final CatalogItem? item = widget.item;
    if (item == null) {
      return _defaultThermoPanelDescription;
    }
    final String? fromRaw = item.raw['description']?.toString().trim();
    if (fromRaw != null && fromRaw.isNotEmpty) {
      return fromRaw;
    }
    if (item.category != 'panel') {
      final String sub = item.subtitle?.trim() ?? '';
      if (sub.isNotEmpty) {
        return sub;
      }
      return 'Описание уточняйте у менеджера.';
    }
    return _defaultThermoPanelDescription;
  }

  String? _formatMmField(String key) {
    final dynamic v = widget.item?.raw[key];
    if (v == null) {
      return null;
    }
    if (v is num) {
      if (v == 0) {
        return null;
      }
      final double d = v.toDouble();
      if (d == d.roundToDouble()) {
        return '${d.round()}';
      }
      return d.toString();
    }
    final String s = v.toString().trim();
    if (s.isEmpty || s == 'null') {
      return null;
    }
    return s;
  }

  String? _dimensionHint() {
    final CatalogItem? item = widget.item;
    if (item == null) {
      return null;
    }
    return CatalogApiService.catalogMaterialEstimateDimensionHint(item);
  }

  Future<void> _onAddToEstimate() async {
    final CatalogItem item = widget.item!;
    final String? hint =
        CatalogApiService.catalogMaterialEstimateDimensionHint(item);
    if (hint != null && mounted) {
      final bool? go = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Проверьте размеры'),
          content: Text(hint),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Добавить в смету'),
            ),
          ],
        ),
      );
      if (go != true || !mounted) {
        return;
      }
    }
    EstimateService.addItem(
      item,
      quantity: _quantity,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Добавлено в смету')),
    );
    AppRouter.pushEstimate(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.pageBackground,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.headingText,
          ),
        ),
        centerTitle: true,
        title: const Text('Карточка товара', style: AppTextTheme.sectionTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 300,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7E7E7),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  border: Border.all(color: const Color(0xFFD1D1D1)),
                ),
                child: widget.item?.imageUrl == null
                    ? const Center(
                        child: Icon(
                          Icons.view_stream_rounded,
                          size: 200,
                          color: Color(0xFF8D8D8D),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8),
                        ),
                        child: Image.network(
                          widget.item!.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 120,
                                  color: Color(0xFF8D8D8D),
                                ),
                              ),
                        ),
                      ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.item?.title ??
                      'Фасадная термопанель с клинкерной плиткой\nКерамин 40 мм',
                  style: AppTextTheme.sectionTitle.copyWith(
                    fontSize: AppTextSizes.s40,
                    fontWeight: AppTextWeights.medium,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _priceText(widget.item),
                    style: const TextStyle(
                      color: AppColors.headingText,
                      fontSize: AppTextSizes.s48,
                      fontWeight: AppTextWeights.medium,
                    ),
                  ),
                ),
              ),
              if (widget.item?.subtitle != null &&
                  widget.item!.subtitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    widget.item!.subtitle!,
                    style: const TextStyle(
                      color: Color(0xFF5D5D5D),
                      fontSize: AppTextSizes.s30,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        text: 'Описание',
                        selected: !_showCharacteristics,
                        onTap: () =>
                            setState(() => _showCharacteristics = false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TabButton(
                        text: 'Характеристики',
                        selected: _showCharacteristics,
                        onTap: () =>
                            setState(() => _showCharacteristics = true),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_showCharacteristics) ...[
                _SpecRow(
                  'Категория',
                  widget.item?.categoryLabel ?? 'Термопанели',
                ),
                _SpecRow(
                  'Артикул',
                  _rawValue('sku', fallback: 'Не указан'),
                ),
                _SpecRow(
                  'Материал',
                  _rawValue('material', fallback: 'Термопанель'),
                ),
                _SpecRow(
                  'Цвет',
                  _firstRawValue(<String>[
                    'color_description',
                    'color',
                    'description',
                    'collection_style',
                    'collection',
                  ], fallback: 'Не указан'),
                ),
                _SpecRow(
                  'Фактура',
                  _rawValue('texture', fallback: 'Не указана'),
                ),
                if (_formatMmField('width_mm') != null)
                  _SpecRow('Ширина, мм', _formatMmField('width_mm')!),
                if (_formatMmField('length_mm') != null)
                  _SpecRow('Длина, мм', _formatMmField('length_mm')!),
                if (_formatMmField('thickness_mm') != null)
                  _SpecRow('Толщина, мм', _formatMmField('thickness_mm')!),
                _SpecRow('Ед. измерения', widget.item?.unit ?? 'шт'),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    _descriptionBody(),
                    style: const TextStyle(
                      color: AppColors.headingText,
                      fontSize: AppTextSizes.s32,
                      height: AppLineHeights.normal,
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    const Text('Количество', style: AppTextTheme.body35),
                    const Spacer(),
                    IconButton(
                      onPressed: _quantity <= 1
                          ? null
                          : () => setState(() => _quantity--),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$_quantity',
                      style: const TextStyle(
                        color: AppColors.headingText,
                        fontSize: AppTextSizes.s40,
                        fontWeight: AppTextWeights.medium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _quantity++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
              Builder(
                builder: (BuildContext context) {
                  final String? dimHint = _dimensionHint();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (dimHint != null) ...[
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(8)),
                              border: Border.all(color: const Color(0xFFFFC107)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Color(0xFF8D6E00),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      dimHint,
                                      style: const TextStyle(
                                        color: Color(0xFF5D4037),
                                        fontSize: AppTextSizes.s30,
                                        height: AppLineHeights.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (widget.item != null &&
                            widget.item!.category == 'panel' &&
                            (widget.item!.imageUrl ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: OutlinedButton.icon(
                              onPressed: () {
                                AppRouter.pushPanelFit(
                                  context,
                                  textureImageUrl: widget.item!.imageUrl,
                                  panelTitle: widget.item!.title,
                                );
                              },
                              icon: const Icon(Icons.layers_outlined),
                              label: const Text('Примерка на фасаде'),
                              style: OutlinedButton.styleFrom(
                                fixedSize: const Size(double.infinity, 44),
                              ),
                            ),
                          ),
                        TextButton(
                          onPressed:
                              widget.item == null ? null : _onAddToEstimate,
                          style: TextButton.styleFrom(
                            fixedSize: const Size(double.infinity, 44),
                            foregroundColor: AppColors.primaryButtonText,
                            backgroundColor: AppColors.primaryButtonBackground,
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(6)),
                            ),
                          ),
                          child: const Text(
                            'Добавить в смету',
                            style: AppTextTheme.buttonLabel,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _priceText(CatalogItem? item) {
    if (item == null || item.price == null || item.price!.isEmpty) {
      return 'Цена по запросу';
    }
    final String unit = item.unit == null || item.unit!.isEmpty
        ? ''
        : ' /${item.unit}';
    return '${item.price} ₽$unit';
  }

  String _rawValue(String key, {required String fallback}) {
    final dynamic value = widget.item?.raw[key];
    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }
    return value.toString();
  }

  String _firstRawValue(List<String> keys, {required String fallback}) {
    for (final String key in keys) {
      final dynamic value = widget.item?.raw[key];
      final String text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return fallback;
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: selected ? AppColors.onAccent : AppColors.headingText,
        backgroundColor: selected
            ? AppColors.primaryButtonBackground
            : AppColors.pageBackground,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          side: BorderSide(
            color: selected
                ? AppColors.primaryButtonBackground
                : const Color(0xFFC9C9C9),
          ),
        ),
      ),
      child: Text(text, style: AppTextTheme.body35),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow(this.left, this.right);

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              style: const TextStyle(
                color: AppColors.headingText,
                fontSize: AppTextSizes.s37,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              right,
              textAlign: TextAlign.right,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.headingText,
                fontSize: AppTextSizes.s37,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
