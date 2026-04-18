import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';

class WindowSlopesScreen extends StatelessWidget {
  const WindowSlopesScreen({super.key});

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
                  const Expanded(
                    child: Text(
                      'Редактирование',
                      textAlign: TextAlign.center,
                      style: AppTextTheme.screenTitle,
                    ),
                  ),
                  IconButton(
                    onPressed: () => AppRouter.pushEstimate(context),
                    icon: const Icon(
                      Icons.ios_share_outlined,
                      size: 24,
                      color: AppColors.headingText,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 320,
              width: double.infinity,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(double.infinity, 320),
                    painter: _GridPainter(),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: const BoxDecoration(
                          color: Color(0xFFC4C4C4),
                          border: Border.fromBorderSide(
                            BorderSide(color: Color(0xFF6C6C6C), width: 2),
                          ),
                        ),
                        child: Stack(
                          children: const [
                            Positioned(top: -14, left: 70, child: _HandleDot()),
                            Positioned(bottom: -14, left: 70, child: _HandleDot()),
                            Positioned(left: -14, top: 70, child: _HandleDot()),
                            Positioned(right: -14, top: 70, child: _HandleDot()),
                            Positioned(
                              left: 54,
                              top: 52,
                              child: Text('64см^2', style: AppTextTheme.body24),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 98,
                    top: 20,
                    child: Text('8', style: AppTextTheme.body28),
                  ),
                  const Positioned(
                    left: 98,
                    bottom: 28,
                    child: Text('8', style: AppTextTheme.body28),
                  ),
                  const Positioned(
                    left: 46,
                    top: 140,
                    child: Text('8', style: AppTextTheme.body28),
                  ),
                  const Positioned(
                    right: 46,
                    top: 140,
                    child: Text('8', style: AppTextTheme.body28),
                  ),
                  Positioned(
                    left: 16,
                    top: 12,
                    child: _TopGhostButton(
                      text: 'Вид 1',
                      onTap: () => AppRouter.pushEditing(context),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    top: 12,
                    child: Row(
                      children: [
                        _TopGhostButton(text: '+1', onTap: () {}),
                        const SizedBox(width: 6),
                        _TopGhostButton(icon: Icons.undo, onTap: () {}),
                        const SizedBox(width: 6),
                        _TopGhostButton(icon: Icons.redo, onTap: () {}),
                        const SizedBox(width: 6),
                        _TopGhostButton(text: '3D', onTap: () {}),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: const [
                  _ToolTile(icon: Icons.grid_view_rounded, active: false),
                  SizedBox(width: 8),
                  _ToolTile(icon: Icons.window_outlined, active: true),
                  SizedBox(width: 8),
                  _ToolTile(icon: Icons.home_outlined, active: false),
                  SizedBox(width: 8),
                  _ToolTile(icon: Icons.copy_outlined, active: false),
                  SizedBox(width: 8),
                  _ToolTile(icon: Icons.content_cut, active: false),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primaryButtonBackground,
                    foregroundColor: AppColors.onAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(110, 30),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                  ),
                  child: const Text('Откосы на окна', style: TextStyle(fontSize: AppTextSizes.s26)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 104,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7E7E7),
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                    border: Border.all(color: const Color(0xFFD0D0D0)),
                  ),
                  child: const Icon(Icons.crop_square, color: Color(0xFFAEAEAE), size: 42),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HandleDot extends StatelessWidget {
  const _HandleDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: const Color(0xFFD3D3D3),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF6C6C6C)),
      ),
    );
  }
}

class _TopGhostButton extends StatelessWidget {
  const _TopGhostButton({this.text, this.icon, required this.onTap});

  final String? text;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE9E9E9),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          border: Border.all(color: const Color(0xFFC8C8C8)),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, size: 16, color: AppColors.headingText)
              : Text(text ?? '', style: AppTextTheme.body26),
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.icon, required this.active});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: active ? AppColors.primaryButtonBackground : const Color(0xFFD6D6D6),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Icon(
        icon,
        size: 34,
        color: active ? AppColors.onAccent : AppColors.headingText,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double cell = 40;
    final Paint linePaint = Paint()
      ..color = const Color(0xFFC7C7C7)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
