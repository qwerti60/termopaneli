import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';

class MyDataScreen extends StatefulWidget {
  const MyDataScreen({super.key});

  @override
  State<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends State<MyDataScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Иван');
  final TextEditingController _surnameController =
      TextEditingController(text: 'Иванов');
  final TextEditingController _phoneController =
      TextEditingController(text: '+7 (999) 888 77-66');

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
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
              _DataField(controller: _nameController),
              const SizedBox(height: 12),
              _DataField(controller: _surnameController),
              const SizedBox(height: 12),
              _DataField(controller: _phoneController),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextButton(
                  onPressed: () => AppRouter.pushLoginReplacing(context),
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

class _DataField extends StatelessWidget {
  const _DataField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
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
    );
  }
}
