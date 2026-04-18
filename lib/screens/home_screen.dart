import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.headingText,
                      size: 22,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Дом',
                      textAlign: TextAlign.center,
                      style: AppTextTheme.screenTitle,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Мои фото',
                style: AppTextTheme.sectionTitle,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _AddPhotoTile(onTap: () => AppRouter.pushPersonalData(context)),
                  const SizedBox(width: 10),
                  _CheckerTile(onTap: () => AppRouter.pushProfile(context)),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Наши дома',
                style: AppTextTheme.sectionTitle,
              ),
              const SizedBox(height: 12),
              _HouseCard(onTap: () => AppRouter.pushEditing(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      child: Container(
        width: 124,
        height: 124,
        decoration: const BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        child: const Center(
          child: Icon(Icons.add, size: 58, color: Color(0xFF8D8D8D)),
        ),
      ),
    );
  }
}

class _CheckerTile extends StatelessWidget {
  const _CheckerTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      child: Container(
        width: 230,
        height: 124,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: CustomPaint(painter: _CheckerPainter()),
      ),
    );
  }
}

class _HouseCard extends StatelessWidget {
  const _HouseCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(4)),
      child: Container(
        width: 124,
        height: 124,
        decoration: BoxDecoration(
          color: const Color(0xFFECECEC),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          border: Border.all(color: const Color(0xFFD5D5D5)),
        ),
        child: const Center(
          child: Icon(
            Icons.house_rounded,
            size: 70,
            color: Color(0xFF6E7880),
          ),
        ),
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double cell = 10;
    final Paint light = Paint()..color = const Color(0xFFF5F5F5);
    final Paint dark = Paint()..color = const Color(0xFFE9E9E9);

    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final bool even = ((x / cell).floor() + (y / cell).floor()).isEven;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cell, cell),
          even ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
