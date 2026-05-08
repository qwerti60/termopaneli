import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/routes/app_router.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
              isActive: false,
              onTap: () => AppRouter.pushSearch(context),
            ),
            _BottomNavItem(
              icon: Icons.person_outline,
              label: 'Профиль',
              isActive: true,
              onTap: () {},
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Иван',
                              style: AppTextTheme.profileName,
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                AppRouter.pushLoginReplacing(context),
                            icon: const Icon(
                              Icons.notifications_none_outlined,
                              size: 28,
                              color: AppColors.headingText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      color: AppColors.primaryButtonBackground,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Версия PRO',
                                  style: AppTextTheme.proTitle,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Возможность детально рассчитать смету',
                                  style: AppTextTheme.proSubtitle,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () =>
                                AppRouter.pushSubscription(context),
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.pageBackground,
                              foregroundColor: AppColors.headingText,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(4),
                                ),
                              ),
                            ),
                            child: const Text(
                              'Улучшить',
                              style: AppTextTheme.proSubtitle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _MenuItem(
                      title: 'Мои данные',
                      onTap: () => AppRouter.pushMyData(context),
                    ),
                    _MenuItem(
                      title: 'Сметы',
                      onTap: () => AppRouter.pushSavedEstimates(context),
                    ),
                    _MenuItem(
                      title: 'Дом',
                      onTap: () => AppRouter.pushHome(context),
                    ),
                    _MenuItem(
                      title: 'Управление подпиской',
                      onTap: () => AppRouter.pushSubscription(context),
                    ),
                    _MenuItem(
                      title: 'Умный калькулятор',
                      onTap: () => AppRouter.pushLoginReplacing(context),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SocialButton(
                            color: const Color(0xFF7360F2),
                            icon: Icons.forum_outlined,
                            onTap: () => AppRouter.pushPersonalData(context),
                          ),
                          _SocialButton(
                            color: const Color(0xFF2FBF55),
                            icon: Icons.call,
                            onTap: () => AppRouter.pushRegistration(context),
                          ),
                          _SocialButton(
                            color: const Color(0xFF2FAAE6),
                            icon: Icons.send,
                            onTap: () => AppRouter.pushHome(context),
                          ),
                          _SocialButton(
                            color: const Color(0xFF247BDE),
                            icon: Icons.people,
                            onTap: () =>
                                AppRouter.pushPersonalDataConfirm(context),
                          ),
                          _SocialButton(
                            color: const Color(0xFFFF0000),
                            icon: Icons.play_arrow,
                            onTap: () => AppRouter.pushLoginReplacing(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Expanded(child: Text(title, style: AppTextTheme.sectionTitle)),
            const Icon(Icons.chevron_right, size: 34, color: Color(0xFF8D8D8D)),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
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
