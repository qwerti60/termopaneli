import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/models/user_profile.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/services/profile_api_service.dart';
import 'package:termopaneli_app/services/session_service.dart';

class MyDataScreen extends StatefulWidget {
  const MyDataScreen({super.key});

  @override
  State<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends State<MyDataScreen> {
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final String? token = await SessionService.getToken();
    if (!mounted) {
      return;
    }
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите в аккаунт, чтобы изменить данные')),
      );
      Navigator.of(context).pop();
      return;
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final UserProfile? p = await ProfileApiService.fetchMe();
      if (!mounted) {
        return;
      }
      if (p == null) {
        setState(() {
          _loading = false;
          _loadError = 'Нет сессии. Войдите снова.';
        });
        return;
      }
      _lastNameController.text = p.lastName;
      _firstNameController.text = p.firstName;
      _middleNameController.text = p.middleName;
      _emailController.text = p.email;
      _phoneController.text = _formatPhone(p.phone);
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = _userFacingErrorMessage(e);
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

  Future<void> _save() async {
    final String last = _lastNameController.text.trim();
    final String first = _firstNameController.text.trim();
    final String middle = _middleNameController.text.trim();
    final String mail = _emailController.text.trim();
    if (last.isEmpty || first.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите фамилию и имя')),
      );
      return;
    }
    if (mail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите эл. почту')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ProfileApiService.updateProfile(
        lastName: last,
        firstName: first,
        middleName: middle,
        email: mail,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные сохранены')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_userFacingErrorMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
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
                      'Мои данные',
                      textAlign: TextAlign.center,
                      style: AppTextTheme.screenTitle,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _loadError != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _loadError!,
                                textAlign: TextAlign.center,
                                style: AppTextTheme.body32.copyWith(
                                  color: const Color(0xFFB71C1C),
                                ),
                              ),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Повторить'),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _LabeledField(
                                  label: 'Фамилия',
                                  controller: _lastNameController,
                                ),
                                const SizedBox(height: 12),
                                _LabeledField(
                                  label: 'Имя',
                                  controller: _firstNameController,
                                ),
                                const SizedBox(height: 12),
                                _LabeledField(
                                  label: 'Отчество',
                                  controller: _middleNameController,
                                  hint: 'Необязательно',
                                ),
                                const SizedBox(height: 12),
                                _LabeledField(
                                  label: 'Эл. почта',
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 12),
                                _LabeledField(
                                  label: 'Телефон',
                                  controller: _phoneController,
                                  readOnly: true,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Смена номера — позже через повторный вход по SMS.',
                                  style: AppTextTheme.body32.copyWith(
                                    fontSize: AppTextSizes.s34,
                                    color: const Color(0xFF757575),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                FilledButton(
                                  onPressed: _saving ? null : _save,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primaryButtonBackground,
                                    foregroundColor: AppColors.primaryButtonText,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primaryButtonText,
                                          ),
                                        )
                                      : const Text(
                                          'Сохранить',
                                          style: TextStyle(
                                            fontSize: AppTextSizes.s42,
                                            fontWeight: AppTextWeights.medium,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextButton(
                  onPressed: () => AppRouter.logoutToGuestCatalog(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF3B30),
                    textStyle: const TextStyle(
                      fontSize: AppTextSizes.s38,
                      fontWeight: AppTextWeights.regular,
                    ),
                  ),
                  child: const Text('Выйти из аккаунта'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.readOnly = false,
    this.hint,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextTheme.body32.copyWith(
            fontWeight: AppTextWeights.medium,
            color: AppColors.headingText,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.pageBackground,
            contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
          ),
          style: const TextStyle(color: AppColors.headingText, fontSize: AppTextSizes.s42),
        ),
      ],
    );
  }
}
