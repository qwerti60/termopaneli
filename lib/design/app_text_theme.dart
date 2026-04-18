import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';

abstract final class AppTextTheme {
  AppTextTheme._();

  static const TextStyle screenTitle = TextStyle(
    color: AppColors.headingText,
    fontSize: AppTextSizes.s36,
    fontWeight: AppTextWeights.medium,
  );

  static const TextStyle profileName = TextStyle(
    color: AppColors.headingText,
    fontSize: AppTextSizes.s42,
    fontWeight: AppTextWeights.medium,
  );

  static const TextStyle sectionTitle = TextStyle(
    color: AppColors.headingText,
    fontSize: AppTextSizes.s38,
    fontWeight: AppTextWeights.regular,
  );

  static const TextStyle sectionTitleBold = TextStyle(
    color: AppColors.headingText,
    fontSize: AppTextSizes.s38,
    fontWeight: AppTextWeights.bold,
  );

  static const TextStyle body36 = TextStyle(
    color: AppColors.headingText,
    fontSize: AppTextSizes.s36,
  );

  static const TextStyle body35 = TextStyle(
    color: AppColors.headingText,
    fontSize: AppTextSizes.s35,
  );

  static const TextStyle body34 = TextStyle(
    color: AppColors.headingText,
    fontSize: AppTextSizes.s34,
  );

  static const TextStyle body33 = TextStyle(
    color: AppColors.headingText,
    fontSize: AppTextSizes.s33,
  );

  static const TextStyle body32 = TextStyle(
    color: AppColors.headingText,
    fontSize: AppTextSizes.s32,
  );

  static const TextStyle body28 = TextStyle(
    color: AppColors.headingText,
    fontSize: AppTextSizes.s28,
  );

  static const TextStyle body26 = TextStyle(
    color: AppColors.headingText,
    fontSize: AppTextSizes.s26,
  );

  static const TextStyle body24 = TextStyle(
    color: AppColors.headingText,
    fontSize: AppTextSizes.s24,
  );

  static const TextStyle body37 = TextStyle(
    color: AppColors.headingText,
    fontSize: AppTextSizes.s37,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontSize: AppTextSizes.s34,
    height: AppLineHeights.tight,
  );

  static const TextStyle proTitle = TextStyle(
    color: AppColors.onAccent,
    fontSize: AppTextSizes.s34,
  );

  static const TextStyle proSubtitle = TextStyle(
    color: AppColors.onAccent,
    fontSize: AppTextSizes.s22,
  );

  static const TextStyle hint32 = TextStyle(
    color: AppColors.hintText,
    fontSize: AppTextSizes.s32,
  );

  static const TextStyle navLabel = TextStyle(
    fontSize: AppTextSizes.s22,
  );
}
