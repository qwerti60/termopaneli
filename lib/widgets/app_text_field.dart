import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(3.0)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(3.0)),
          borderSide: BorderSide(color: AppColors.accent),
        ),
        prefixIcon: Icon(prefixIcon),
        hintText: hintText,
        fillColor: AppColors.inputBackground,
        filled: true,
      ),
    );
  }
}
