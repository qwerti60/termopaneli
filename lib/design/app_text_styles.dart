import 'package:flutter/material.dart';

abstract final class AppTextWeights {
  AppTextWeights._();

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight bold = FontWeight.w700;
}

abstract final class AppLineHeights {
  AppLineHeights._();

  static const double tight = 1;
  static const double normal = 1.25;
}

abstract final class AppLetterSpacings {
  AppLetterSpacings._();

  static const double normal = 0;
}
