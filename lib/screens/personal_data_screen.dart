import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';

class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

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
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '+7 (999) 888 77-66',
                textAlign: TextAlign.center,
                style: AppTextTheme.sectionTitleBold,
              ),
              const SizedBox(height: 24),
              _LightInputField(
                controller: _lastNameController,
                hintText: 'Фамилия',
              ),
              const SizedBox(height: 12),
              _LightInputField(
                controller: _firstNameController,
                hintText: 'Имя',
              ),
              const SizedBox(height: 12),
              _LightInputField(
                controller: _middleNameController,
                hintText: 'Отчество',
              ),
              const SizedBox(height: 12),
              _LightInputField(
                controller: _emailController,
                hintText: 'Эл. почта',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 34),
              TextButton(
                onPressed: () => AppRouter.pushPersonalDataConfirm(context),
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
    );
  }
}

class _LightInputField extends StatelessWidget {
  const _LightInputField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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
