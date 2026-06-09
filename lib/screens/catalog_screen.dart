import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/services/catalog_api_service.dart';
import 'package:termopaneli_app/widgets/yandex_banner_ad.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _selectedCategory = 'all';
  String _sortMode = 'name_asc';
  String _selectedMaterial = 'all';
  String _selectedColor = 'all';
  String _selectedThickness = 'all';
  late Future<List<CatalogItem>> _catalogFuture;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _loadCatalog();
  }

  Future<List<CatalogItem>> _loadCatalog() {
    return CatalogApiService.fetchCatalog(
      category: _selectedCategory,
      material: _selectedMaterial == 'all' ? null : _selectedMaterial,
      color: _selectedColor == 'all' ? null : _selectedColor,
      thickness: _selectedThickness == 'all' ? null : _selectedThickness,
    );
  }

  void _selectCategory(String category) {
    if (category == _selectedCategory) {
      return;
    }
    setState(() {
      _selectedCategory = category;
      _catalogFuture = _loadCatalog();
    });
  }

  void _retryCatalog() {
    setState(() {
      _catalogFuture = _loadCatalog();
    });
  }

  List<CatalogItem> _visibleItems(List<CatalogItem> items) {
    final List<CatalogItem> filtered = List<CatalogItem>.from(items);

    filtered.sort((CatalogItem a, CatalogItem b) {
      switch (_sortMode) {
        case 'price_asc':
          return _priceOf(a).compareTo(_priceOf(b));
        case 'price_desc':
          return _priceOf(b).compareTo(_priceOf(a));
        case 'category':
          return (a.categoryLabel ?? a.category).compareTo(
            b.categoryLabel ?? b.category,
          );
        case 'name_desc':
          return b.title.compareTo(a.title);
        case 'name_asc':
        default:
          return a.title.compareTo(b.title);
      }
    });
    return filtered;
  }

  String _fieldValue(CatalogItem item, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = item.raw[key];
      final String text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  double _priceOf(CatalogItem item) {
    final String raw = item.price ?? '';
    final String normalized = raw
        .replaceAll(RegExp(r'[^0-9,.]'), '')
        .replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  Future<void> _showFilterSheet(List<CatalogItem> items) async {
    final List<String> materials = _uniqueValues(items, <String>['material']);
    final List<String> colors = _uniqueValues(items, <String>[
      'color',
      'color_description',
    ]);
    final List<String> thicknesses =
        CatalogApiService.uniqueThicknessFilterTokens(items);
    String material = _selectedMaterial;
    String color = _selectedColor;
    String thickness = _selectedThickness;
    final bool showThickness = thicknesses.isNotEmpty || thickness != 'all';

    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Фильтр', style: AppTextTheme.sectionTitle),
                    const SizedBox(height: 14),
                    _DropdownFilter(
                      label: 'Материал',
                      value: material,
                      values: materials,
                      onChanged: (String value) {
                        setSheetState(() => material = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    _DropdownFilter(
                      label: 'Цвет',
                      value: color,
                      values: colors,
                      onChanged: (String value) {
                        setSheetState(() => color = value);
                      },
                    ),
                    if (showThickness) ...[
                      const SizedBox(height: 12),
                      _DropdownFilter(
                        label: 'Толщина, мм',
                        value: thickness,
                        values: thicknesses,
                        compareOptions:
                            CatalogApiService.compareThicknessFilterTokens,
                        onChanged: (String value) {
                          setSheetState(() => thickness = value);
                        },
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedMaterial = 'all';
                                _selectedColor = 'all';
                                _selectedThickness = 'all';
                                _catalogFuture = _loadCatalog();
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Сбросить'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _selectedMaterial = material;
                                _selectedColor = color;
                                _selectedThickness = thickness;
                                _catalogFuture = _loadCatalog();
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Применить'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<String> _uniqueValues(List<CatalogItem> items, List<String> keys) {
    final Set<String> values = <String>{};
    for (final CatalogItem item in items) {
      final String value = _fieldValue(item, keys);
      if (value.isNotEmpty) {
        values.add(value);
      }
    }
    final List<String> sorted = values.toList()..sort();
    return sorted;
  }

  Future<void> _showSortSheet() async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SortTile(
                title: 'По названию А-Я',
                value: 'name_asc',
                groupValue: _sortMode,
              ),
              _SortTile(
                title: 'По названию Я-А',
                value: 'name_desc',
                groupValue: _sortMode,
              ),
              _SortTile(
                title: 'Сначала дешевле',
                value: 'price_asc',
                groupValue: _sortMode,
              ),
              _SortTile(
                title: 'Сначала дороже',
                value: 'price_desc',
                groupValue: _sortMode,
              ),
              _SortTile(
                title: 'По категории',
                value: 'category',
                groupValue: _sortMode,
              ),
            ],
          ),
        );
      },
    );
    if (selected != null && selected != _sortMode) {
      setState(() => _sortMode = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const YandexBannerAd(backgroundColor: Color(0xFFE6E6E6)),
          Container(
            height: 74,
            color: const Color(0xFFE6E6E6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomNavItem(
                  icon: Icons.grid_view_outlined,
                  label: 'Каталог',
                  isActive: true,
                  onTap: () {},
                ),
                _BottomNavItem(
                  icon: Icons.search,
                  label: 'Поиск',
                  isActive: false,
                  onTap: () => AppRouter.pushSearch(context),
                ),
                _BottomNavItem(
                  icon: Icons.person_outline,
                  label: 'Профиль',
                  isActive: false,
                  onTap: () => AppRouter.pushProfile(context),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Row(
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
                      'Каталог',
                      textAlign: TextAlign.center,
                      style: AppTextTheme.screenTitle,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<CatalogItem>>(
                future: _catalogFuture,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<CatalogItem>> snapshot,
                    ) {
                      final List<CatalogItem> items =
                          snapshot.data ?? const <CatalogItem>[];
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _TopActionButton(
                            icon: Icons.filter_alt_outlined,
                            text: _hasFilters ? 'Фильтр *' : 'Фильтр',
                            onTap: items.isEmpty
                                ? null
                                : () => _showFilterSheet(items),
                          ),
                          _TopActionButton(
                            icon: Icons.swap_vert,
                            text: 'Сортировка',
                            onTap: _showSortSheet,
                          ),
                        ],
                      );
                    },
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: CatalogApiService.categories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final CatalogCategory category =
                        CatalogApiService.categories[index];
                    return _CategoryChip(
                      label: category.label,
                      selected: category.code == _selectedCategory,
                      onTap: () => _selectCategory(category.code),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: FutureBuilder<List<CatalogItem>>(
                  future: _catalogFuture,
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<CatalogItem>> snapshot,
                      ) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'Не удалось загрузить каталог',
                                    textAlign: TextAlign.center,
                                    style: AppTextTheme.body32.copyWith(
                                      color: AppColors.headingText,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  FilledButton.tonal(
                                    onPressed: _retryCatalog,
                                    child: const Text('Повторить'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        final List<CatalogItem> items = _visibleItems(
                          snapshot.data ?? const <CatalogItem>[],
                        );
                        if (items.isEmpty) {
                          return const Center(
                            child: Text(
                              'Каталог пуст',
                              style: AppTextTheme.body32,
                            ),
                          );
                        }
                        return GridView.builder(
                          itemCount: items.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 18,
                                childAspectRatio: 0.82,
                              ),
                          itemBuilder: (BuildContext context, int index) {
                            return _CatalogCard(item: items[index]);
                          },
                        );
                      },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasFilters =>
      _selectedMaterial != 'all' ||
      _selectedColor != 'all' ||
      _selectedThickness != 'all';
}

class _DropdownFilter extends StatelessWidget {
  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.compareOptions,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  final Comparator<String>? compareOptions;

  @override
  Widget build(BuildContext context) {
    // Reserve `all` for «Все»; duplicate `DropdownMenuItem.value` breaks the dropdown assert.
    final Set<String> optionSet = <String>{
      for (final String v in values)
        if (v.isNotEmpty && v != 'all') v,
      if (value.isNotEmpty && value != 'all') value,
    };
    final List<String> options = optionSet.toList();
    if (compareOptions != null) {
      options.sort(compareOptions);
    } else {
      options.sort();
    }
    final String initialDropdownValue = value.isEmpty || value == 'all'
        ? 'all'
        : value;

    final List<DropdownMenuItem<String>> items = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(
        value: 'all',
        child: Text('Все', overflow: TextOverflow.ellipsis),
      ),
      ...options.map(
        (String option) => DropdownMenuItem<String>(
          value: option,
          child: Text(option, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];
    return DropdownButtonFormField<String>(
      initialValue: initialDropdownValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: (String? value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

class _SortTile extends StatelessWidget {
  const _SortTile({
    required this.title,
    required this.value,
    required this.groupValue,
  });

  final String title;
  final String value;
  final String groupValue;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: value == groupValue ? const Icon(Icons.check) : null,
      onTap: () => Navigator.pop(context, value),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryButtonBackground,
      backgroundColor: const Color(0xFFEDEDED),
      labelStyle: TextStyle(
        color: selected ? AppColors.primaryButtonText : AppColors.headingText,
        fontSize: AppTextSizes.s30,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppColors.headingText),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: AppColors.headingText,
                fontSize: AppTextSizes.s34,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.item});

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => AppRouter.pushProductDetails(context, item: item),
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5E5),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                border: Border.all(color: const Color(0xFFD0D0D0)),
              ),
              child: item.imageUrl == null
                  ? const Center(
                      child: Icon(
                        Icons.view_stream_rounded,
                        size: 96,
                        color: Color(0xFF8D8D8D),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      child: Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 64,
                                color: Color(0xFF8D8D8D),
                              ),
                            ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          if (item.categoryLabel != null) ...[
            Text(
              item.categoryLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF757575),
                fontSize: AppTextSizes.s28,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.headingText,
              fontSize: AppTextSizes.s36,
            ),
          ),
          if (item.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              item.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF5D5D5D),
                fontSize: AppTextSizes.s30,
              ),
            ),
          ],
          if (item.price != null) ...[
            const SizedBox(height: 2),
            Text(
              _formatPrice(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.headingText,
                fontSize: AppTextSizes.s30,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatPrice(CatalogItem item) {
    final String unit = item.unit == null || item.unit!.isEmpty
        ? ''
        : ' / ${item.unit}';
    return '${item.price} ₽$unit';
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = isActive
        ? AppColors.headingText
        : const Color(0xFF757575);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 4),
            Text(label, style: AppTextTheme.navLabel.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
