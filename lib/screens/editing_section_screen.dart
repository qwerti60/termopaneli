import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';

class EditingSectionScreen extends StatelessWidget {
  const EditingSectionScreen({required this.sectionName, super.key});

  final String sectionName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              color: const Color(0xFFE1E1E1),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 22,
                      color: AppColors.headingText,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      sectionName,
                      textAlign: TextAlign.center,
                      style: AppTextTheme.screenTitle,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.settings_suggest_outlined,
                        size: 72,
                        color: Color(0xFF8D8D8D),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Настройки секции "$sectionName"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.headingText,
                          fontSize: AppTextSizes.s34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: () => AppRouter.pushEditing(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.onAccent,
                          backgroundColor: AppColors.primaryButtonBackground,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: const Text(
                          'Вернуться к редактированию',
                          style: AppTextTheme.body28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
