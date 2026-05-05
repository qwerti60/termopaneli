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
  late final Future<List<CatalogItem>> _catalogFuture;

  @override
  void initState() {
    super.initState();
    _catalogFuture = CatalogApiService.fetchCatalog(limit: 500);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {});
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
              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: AppColors.pageBackground,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => FocusScope.of(context).unfocus(),
                    icon: const Icon(Icons.search, color: Color(0xFF7E7E7E)),
                  ),
                  hintText: 'Название, артикул, цвет...',
                ),
                style: const TextStyle(
                  color: Color(0xFF7E7E7E),
                  fontSize: AppTextSizes.s36,
                ),
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
                          return const Center(
                            child: Text(
                              'Не удалось загрузить каталог для поиска',
                              style: AppTextTheme.body32,
                            ),
                          );
                        }
                        final String query = _searchController.text.trim();
                        if (query.isEmpty) {
                          return const Center(
                            child: Text(
                              'Введите название, артикул, цвет или материал',
                              textAlign: TextAlign.center,
                              style: AppTextTheme.body32,
                            ),
                          );
                        }
                        final List<CatalogItem> results = _searchResults(
                          snapshot.data ?? const <CatalogItem>[],
                        );
                        if (results.isEmpty) {
                          return const Center(
                            child: Text(
                              'Ничего не найдено',
                              style: AppTextTheme.body32,
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
