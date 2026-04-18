import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TopActionButton(
                    icon: Icons.filter_alt_outlined,
                    text: 'Фильтр',
                    onTap: () => AppRouter.pushHome(context),
                  ),
                  _TopActionButton(
                    icon: Icons.swap_vert,
                    text: 'Сортировка',
                    onTap: () => AppRouter.pushHome(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 18,
                  childAspectRatio: 0.82,
                  children: const [
                    _CatalogCard(),
                    _CatalogCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
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
  final VoidCallback onTap;

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
  const _CatalogCard();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => AppRouter.pushProductDetails(context),
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
              child: const Center(
                child: Icon(
                  Icons.view_stream_rounded,
                  size: 96,
                  color: Color(0xFF8D8D8D),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Термопанель',
            style: TextStyle(
              color: AppColors.headingText,
              fontSize: AppTextSizes.s36,
            ),
          ),
        ],
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
    final Color color = isActive ? AppColors.headingText : const Color(0xFF757575);
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
