import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/services/catalog_api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<CatalogItem>> _catalogFuture;
  String _selectedMaterial = 'all';
  String _selectedColor = 'all';
  String _selectedThickness = 'all';

  @override
  void initState() {
    super.initState();
    _catalogFuture = _loadCatalog();
    _searchController.addListener(_onSearchChanged);
  }

  Future<List<CatalogItem>> _loadCatalog() {
    return CatalogApiService.fetchCatalog(
      limit: 500,
      category: 'all',
      material: _selectedMaterial == 'all' ? null : _selectedMaterial,
      color: _selectedColor == 'all' ? null : _selectedColor,
      thickness: _selectedThickness == 'all' ? null : _selectedThickness,
    );
  }

  void _onSearchChanged() {
    setState(() {});
  }

  void _retryCatalog() {
    setState(() {
      _catalogFuture = _loadCatalog();
    });
  }

  bool get _hasFilters =>
      _selectedMaterial != 'all' ||
      _selectedColor != 'all' ||
      _selectedThickness != 'all';

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
    final bool showThickness =
        thicknesses.isNotEmpty || thickness != 'all';

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
                    _SearchDropdownFilter(
                      label: 'Материал',
                      value: material,
                      values: materials,
                      onChanged: (String value) {
                        setSheetState(() => material = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    _SearchDropdownFilter(
                      label: 'Цвет',
                      value: color,
                      values: colors,
                      onChanged: (String value) {
                        setSheetState(() => color = value);
                      },
                    ),
                    if (showThickness) ...[
                      const SizedBox(height: 12),
                      _SearchDropdownFilter(
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

  Future<void> _openFilterSheet() async {
    try {
      final List<CatalogItem> items = await _catalogFuture;
      if (!mounted) {
        return;
      }
      await _showFilterSheet(items);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<CatalogItem> _searchResults(List<CatalogItem> items) {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return const <CatalogItem>[];
    }
    return items
        .where((CatalogItem item) {
          final String haystack = <String>[
            item.title,
            item.subtitle ?? '',
            item.categoryLabel ?? '',
            item.category,
            _fieldValue(item, <String>['sku', 'article', 'code', 'model_code']),
            _fieldValue(item, <String>['material']),
            _fieldValue(item, <String>['color', 'color_description']),
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      bottomNavigationBar: Container(
        height: 74,
        color: const Color(0xFFE6E6E6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomNavItem(
              icon: Icons.grid_view_outlined,
              label: 'Каталог',
              isActive: false,
              onTap: () => AppRouter.pushCatalog(context),
            ),
            _BottomNavItem(
              icon: Icons.search,
              label: 'Поиск',
              isActive: true,
              onTap: () {},
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
                      'Поиск',
                      textAlign: TextAlign.center,
                      style: AppTextTheme.screenTitle,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: AppColors.pageBackground,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(4),
                          ),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(4),
                          ),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => FocusScope.of(context).unfocus(),
                          icon: const Icon(
                            Icons.search,
                            color: Color(0xFF7E7E7E),
                          ),
                        ),
                        hintText: 'Название, артикул, цвет...',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF7E7E7E),
                        fontSize: AppTextSizes.s36,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Фильтр по материалу, цвету и толщине',
                    onPressed: _openFilterSheet,
                    icon: Badge(
                      isLabelVisible: _hasFilters,
                      smallSize: 8,
                      child: const Icon(
                        Icons.filter_alt_outlined,
                        color: AppColors.headingText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Text(
                                    'Не удалось загрузить каталог для поиска',
                                    textAlign: TextAlign.center,
                                    style: AppTextTheme.body32,
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
                        final String query = _searchController.text.trim();
                        if (query.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                _hasFilters
                                    ? 'Введите название, артикул, цвет или материал.\n'
                                        'Активен фильтр API — список уже сужен по материалу, цвету и при необходимости толщине (как в каталоге).'
                                    : 'Введите название, артикул, цвет или материал.\n'
                                        'При необходимости сузьте выборку кнопкой фильтра.',
                                textAlign: TextAlign.center,
                                style: AppTextTheme.body32,
                              ),
                            ),
                          );
                        }
                        final List<CatalogItem> results = _searchResults(
                          snapshot.data ?? const <CatalogItem>[],
                        );
                        if (results.isEmpty) {
                          final String extra = _hasFilters
                              ? '\n\nПопробуйте сбросить фильтр (материал, цвет, толщина) или изменить запрос.'
                              : '';
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Ничего не найдено по запросу «$query».$extra',
                                textAlign: TextAlign.center,
                                style: AppTextTheme.body32,
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (context, index) =>
                              Divider(color: Colors.grey.shade300, height: 1),
                          itemBuilder: (BuildContext context, int index) {
                            final CatalogItem item = results[index];
                            return _SearchResultItem(
                              item: item,
                              onTap: () => AppRouter.pushProductDetails(
                                context,
                                item: item,
                              ),
                            );
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
}

class _SearchDropdownFilter extends StatelessWidget {
  const _SearchDropdownFilter({
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
    final String initialDropdownValue =
        value.isEmpty || value == 'all' ? 'all' : value;

    final List<DropdownMenuItem<String>> items = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(
        value: 'all',
        child: Text('Все', overflow: TextOverflow.ellipsis),
      ),
      ...options.map(
        (String v) => DropdownMenuItem<String>(
          value: v,
          child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];
    return DropdownButtonFormField<String>(
      initialValue: initialDropdownValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: (String? v) {
        if (v != null) {
          onChanged(v);
        }
      },
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  const _SearchResultItem({required this.item, required this.onTap});

  final CatalogItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5E5),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
                border: Border.all(color: const Color(0xFFD0D0D0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: item.imageUrl == null
                  ? const Icon(
                      Icons.view_stream_rounded,
                      color: Color(0xFF8D8D8D),
                    )
                  : Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFF8D8D8D),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextTheme.body34.copyWith(
                      color: const Color(0xFF6F6F6F),
                    ),
                  ),
                  if (item.categoryLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.categoryLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8D8D8D),
                        fontSize: AppTextSizes.s28,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
