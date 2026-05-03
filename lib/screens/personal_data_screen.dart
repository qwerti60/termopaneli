import 'package:flutter/material.dart';
import 'package:termopaneli_app/auth/pending_registration.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';

class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({
    super.key,
    required this.pending,
  });

  final PendingRegistration pending;

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _lastNameController.text = widget.pending.lastName;
    _firstNameController.text = widget.pending.firstName;
    _middleNameController.text = widget.pending.middleName;
    _emailController.text = widget.pending.email;
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PendingRegistration pending = widget.pending;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  pending.phone.isEmpty ? 'Личные данные' : pending.phone,
                  textAlign: TextAlign.center,
                  style: AppTextTheme.sectionTitleBold,
                ),
                const SizedBox(height: 24),
                _LightInputField(
                  controller: _lastNameController,
                  hintText: 'Фамилия',
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 12),
                _LightInputField(
                  controller: _firstNameController,
                  hintText: 'Имя',
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 12),
                _LightInputField(
                  controller: _middleNameController,
                  hintText: 'Отчество',
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 12),
                _LightInputField(
                  controller: _emailController,
                  hintText: 'Эл. почта',
                  keyboardType: TextInputType.emailAddress,
                  validator: _emailValidator,
                ),
                const SizedBox(height: 34),
                TextButton(
                  onPressed: () {
                    if (_formKey.currentState?.validate() != true) {
                      return;
                    }
                    final PendingRegistration updated = pending.copyWith(
                      lastName: _lastNameController.text.trim(),
                      firstName: _firstNameController.text.trim(),
                      middleName: _middleNameController.text.trim(),
                      email: _emailController.text.trim(),
                    );
                    AppRouter.pushPersonalDataConfirm(
                      context,
                      pending: updated,
                    );
                  },
                  style: TextButton.styleFrom(
                    fixedSize: const Size(double.infinity, 33),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.center,
                    foregroundColor: AppColors.primaryButtonText,
                    backgroundColor: AppColors.primaryButtonBackground,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                  child: const Text(
                    'Продолжить',
                    textAlign: TextAlign.center,
                    style: AppTextTheme.buttonLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    final String email = value.trim();
    if (!email.contains('@') || !email.contains('.')) {
      return 'Некорректный email';
    }
    return null;
  }
}

class _LightInputField extends StatelessWidget {
  const _LightInputField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextTheme.body32,
        isCollapsed: true,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        filled: true,
        fillColor: AppColors.inputBackground,
        border: const OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
    );
  }
}
