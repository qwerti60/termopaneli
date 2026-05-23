import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/models/user_profile.dart';
import 'package:termopaneli_app/config/app_features.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/services/profile_api_service.dart';
import 'package:termopaneli_app/services/session_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  UserProfile? _profile;
  String? _error;
  bool _hasAdminToken = false;

  static final Uri _telegramChannelUri = Uri.parse('https://t.me/facade_panel');

  @override
  void initState() {
    super.initState();
    _refreshProfile();
    _loadAdminFlag();
  }

  Future<void> _loadAdminFlag() async {
    final String? t = await SessionService.getAdminApiToken();
    if (!mounted) {
      return;
    }
    setState(() {
      _hasAdminToken = t != null && t.trim().isNotEmpty;
    });
  }

  Future<void> _openSubscriptionScreen() async {
    await AppRouter.pushSubscription(context);
    if (!mounted) {
      return;
    }
    await _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final UserProfile? p = await ProfileApiService.fetchMe(bustCache: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = p;
        _loading = false;
      });
      await _loadAdminFlag();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = null;
        _loading = false;
        _error = _userFacingErrorMessage(e);
      });
    }
  }

  static String _userFacingErrorMessage(Object e) {
    final String raw = e.toString();
    const String prefix = 'Exception: ';
    if (raw.startsWith(prefix)) {
      return raw.substring(prefix.length);
    }
    return raw;
  }

  String _formatPhone(String phone) {
    final String d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.length == 11 && d.startsWith('7')) {
      final String a = d.substring(1, 4);
      final String b = d.substring(4, 7);
      final String c = d.substring(7, 9);
      final String e = d.substring(9, 11);
      return '+7 ($a) $b-$c-$e';
    }
    return phone;
  }

  Future<void> _openTelegramChannel() async {
    if (!await launchUrl(
      _telegramChannelUri,
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть Telegram')),
        );
      }
    }
  }

  Future<void> _onHeaderAction() async {
    if (_profile != null) {
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Выйти из аккаунта?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Выйти'),
            ),
          ],
        ),
      );
      if (ok == true && mounted) {
        await AppRouter.logoutToGuestCatalog(context);
      }
      return;
    }
    if (mounted) {
      AppRouter.pushLoginReplacing(context);
    }
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Личный кабинет',
                                  style: AppTextTheme.body32.copyWith(
                                    color: const Color(0xFF757575),
                                    fontSize: AppTextSizes.s28,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (_loading)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                else if (_error != null) ...[
                                  Text(
                                    'Не удалось загрузить профиль',
                                    style: AppTextTheme.profileName.copyWith(
                                      fontSize: AppTextSizes.s34,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _error!,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextTheme.body32.copyWith(
                                      color: const Color(0xFFB71C1C),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _refreshProfile,
                                    child: const Text('Повторить'),
                                  ),
                                ] else if (_profile != null) ...[
                                  Text(
                                    _profile!.displayName,
                                    style: AppTextTheme.profileName,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatPhone(_profile!.phone),
                                    style: AppTextTheme.body32.copyWith(
                                      color: const Color(0xFF757575),
                                    ),
                                  ),
                                  if (_profile!.email.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _profile!.email,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextTheme.body32.copyWith(
                                        color: const Color(0xFF757575),
                                      ),
                                    ),
                                  ],
                                  if (_profile!.isPro) ...[
                                    const SizedBox(height: 8),
                                    Chip(
                                      avatar: const Icon(
                                        Icons.verified,
                                        size: 18,
                                        color: Color(0xFF2E7D32),
                                      ),
                                      label: const Text('PRO активна'),
                                      backgroundColor: const Color(0xFFE8F5E9),
                                      side: BorderSide.none,
                                      labelStyle: AppTextTheme.body32.copyWith(
                                        color: const Color(0xFF1B5E20),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ] else ...[
                                  Text(
                                    'Войдите в аккаунт',
                                    style: AppTextTheme.profileName,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Сохранение смет и заявки — после входа',
                                    style: AppTextTheme.body32.copyWith(
                                      color: const Color(0xFF757575),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: _profile != null ? 'Выйти' : 'Войти',
                            onPressed: _loading ? null : _onHeaderAction,
                            icon: Icon(
                              _profile != null
                                  ? Icons.logout_outlined
                                  : Icons.login_outlined,
                              size: 28,
                              color: AppColors.headingText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_loading && _profile != null && _profile!.isPro)
                      Container(
                        width: double.infinity,
                        color: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.workspace_premium_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Подписка PRO',
                                    style: AppTextTheme.proTitle.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Расширенные возможности сметы активны',
                                    style: AppTextTheme.proSubtitle.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _openSubscriptionScreen,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Подробнее'),
                            ),
                          ],
                        ),
                      )
                    else if (!_loading)
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
                                    'Расширенный расчёт и приоритет обработки заявок',
                                    style: AppTextTheme.proSubtitle,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: _openSubscriptionScreen,
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
                    _SectionCaption(title: 'Сметы и заявки'),
                    _MenuItem(
                      icon: Icons.folder_open_outlined,
                      title: 'Сохранённые сметы',
                      subtitle: 'Черновики и отправленные',
                      onTap: () => AppRouter.pushSavedEstimates(context),
                    ),
                    _MenuItem(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'Мои заявки',
                      subtitle: 'Статус обращений по сметам',
                      onTap: () => AppRouter.pushMyEstimateRequests(context),
                    ),
                    _SectionCaption(title: 'Профиль'),
                    _MenuItem(
                      icon: Icons.badge_outlined,
                      title: 'Мои данные',
                      subtitle: 'ФИО и электронная почта',
                      onTap: () {
                        SessionService.getToken().then((String? t) {
                          if (!context.mounted) {
                            return;
                          }
                          if (t == null || t.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Войдите в аккаунт, чтобы изменить данные',
                                ),
                              ),
                            );
                            return;
                          }
                          AppRouter.pushMyData(context).then((Object? saved) {
                            if (!context.mounted) {
                              return;
                            }
                            if (saved == true) {
                              _refreshProfile();
                            }
                          });
                        });
                      },
                    ),
                    _MenuItem(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Заявки (админ)',
                      subtitle: _hasAdminToken
                          ? 'Вход выполнен (токен на устройстве)'
                          : 'Вход логином администратора или секрет из config',
                      onTap: () => AppRouter.pushAdminRequests(context).then((_) {
                        if (context.mounted) {
                          _loadAdminFlag();
                        }
                      }),
                    ),
                    _SectionCaption(title: 'Сервисы'),
                    _MenuItem(
                      icon: Icons.view_in_ar_outlined,
                      title: 'Дом/Примерка',
                      subtitle: 'Фото, шаблон дома, маска, панель из каталога',
                      onTap: () => AppRouter.pushPanelFit(context),
                    ),
                    _MenuItem(
                      icon: Icons.calculate_outlined,
                      title: 'Смета и расчёт',
                      subtitle: 'Каталог, материалы и работы',
                      onTap: () => AppRouter.pushEstimate(context),
                    ),
                    if (kHomeScreenEnabled)
                      _MenuItem(
                        icon: Icons.home_outlined,
                        title: 'Дом',
                        subtitle: 'Подбор и оформление',
                        onTap: () => AppRouter.pushHome(context),
                      ),
                    _MenuItem(
                      icon: Icons.card_membership_outlined,
                      title: 'Управление подпиской',
                      subtitle: 'PRO и тарифы',
                      onTap: () async {
                        await _openSubscriptionScreen();
                      },
                    ),
                    if (_profile != null)
                      _MenuItem(
                        icon: Icons.functions_outlined,
                        title: 'SmartCalc',
                        subtitle: _profile!.isPro
                            ? 'Расчёт во встроенном браузере (PRO)'
                            : 'Доступно с подпиской PRO (проверка на сервере)',
                        onTap: () async {
                          // Не ветвить по устаревшему _profile.isPro: после оформления подписки
                          // экран SmartCalc сам запросит me.php и откроет WebView или экран PRO.
                          await AppRouter.pushSmartCalc(context);
                          if (mounted) {
                            await _refreshProfile();
                          }
                        },
                      ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: OutlinedButton.icon(
                        onPressed: _openTelegramChannel,
                        icon: const Icon(Icons.telegram, color: Color(0xFF229ED9)),
                        label: const Text('Канал в Telegram'),
                      ),
                    ),
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

class _SectionCaption extends StatelessWidget {
  const _SectionCaption({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: AppTextSizes.s26,
          letterSpacing: 0.6,
          color: Color(0xFF8A8A8A),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Icon(icon, size: 26, color: const Color(0xFF5C5C5C)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextTheme.sectionTitle),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextTheme.body32.copyWith(
                      color: const Color(0xFF8A8A8A),
                      fontSize: AppTextSizes.s28,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 34, color: Color(0xFF8D8D8D)),
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
