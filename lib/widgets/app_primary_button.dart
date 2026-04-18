import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({required this.text, required this.onPressed, super.key});

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        fixedSize: const Size(double.infinity, 29),
        foregroundColor: AppColors.onAccent,
        backgroundColor: AppColors.accent,
        shape: const BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
      onPressed: onPressed,
      child: Text(text),
    );
  }
}
