import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/services/catalog_api_service.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    this.item,
  });

  final CatalogItem? item;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  bool _showCharacteristics = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
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
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                        child: Image.network(
                          widget.item!.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '5 000 ₽ /шт',
                    style: TextStyle(
                      color: AppColors.headingText,
                      fontSize: AppTextSizes.s48,
                      fontWeight: AppTextWeights.medium,
                    ),
                  ),
                ),
              ),
              if (widget.item?.subtitle != null && widget.item!.subtitle!.isNotEmpty)
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
                        onTap: () => setState(() => _showCharacteristics = false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TabButton(
                        text: 'Характеристики',
                        selected: _showCharacteristics,
                        onTap: () => setState(() => _showCharacteristics = true),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_showCharacteristics) ...[
                const _SpecRow('Вид панели', 'С клинкерной плиткой'),
                const _SpecRow('Цвет', 'Амстердам шейд рельеф'),
                const _SpecRow('Назначение', 'Фасадная'),
                const _SpecRow('Размер панели, м', '245x65x7'),
                const _SpecRow('Площадь панели, м^2', '0.61'),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Фасадные термопанели с клинкерной плиткой подходят для '
                    'наружной отделки дома, обеспечивают долговечность и '
                    'теплоизоляцию.',
                    style: TextStyle(
                      color: AppColors.headingText,
                      fontSize: AppTextSizes.s32,
                      height: AppLineHeights.normal,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
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
        backgroundColor:
            selected ? AppColors.primaryButtonBackground : AppColors.pageBackground,
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
          Text(
            right,
            style: const TextStyle(
              color: AppColors.headingText,
              fontSize: AppTextSizes.s37,
            ),
          ),
        ],
      ),
    );
  }
}
