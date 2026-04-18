import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';

class EditingScreen extends StatefulWidget {
  const EditingScreen({super.key});

  @override
  State<EditingScreen> createState() => _EditingScreenState();
}

class _EditingScreenState extends State<EditingScreen> {
  int _selectedSection = 0;
  int _selectedMaterial = 0;

  static const List<String> _sections = <String>[
    'Термопанели',
    'Цоколь',
    'Углы',
    'Стропила',
    'Софиты',
    'Откосы на окна',
  ];

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
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Row(
                        children: [
                          Text(
                            'Ширина 2.00 м',
                            style: AppTextTheme.body36,
                          ),
                          SizedBox(width: 18),
                          Text(
                            'Высота 2.00 м',
                            style: AppTextTheme.body36,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 320,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _GridPainter(),
                        child: const Center(
                          child: SizedBox(
                            width: 160,
                            height: 160,
                            child: ColoredBox(color: Color(0xFF9B9B9B)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _sections.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final bool isSelected = _selectedSection == index;
                          return OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedSection = index;
                              });
                              if (_sections[index] == 'Откосы на окна') {
                                AppRouter.pushWindowSlopes(context);
                                return;
                              }
                              AppRouter.pushEditingSection(
                                context,
                                _sections[index],
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isSelected
                                  ? AppColors.primaryButtonBackground
                                  : AppColors.pageBackground,
                              foregroundColor: isSelected
                                  ? AppColors.onAccent
                                  : AppColors.headingText,
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primaryButtonBackground
                                    : const Color(0xFFC9C9C9),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(4)),
                              ),
                            ),
                            child: Text(
                              _sections[index],
                              style: AppTextTheme.body32,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _MaterialCard(
                              title: 'Светлая',
                              iconColor: const Color(0xFFB9B9B9),
                              isSelected: _selectedMaterial == 0,
                              onTap: () {
                                setState(() {
                                  _selectedMaterial = 0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MaterialCard(
                              title: 'Красная',
                              iconColor: const Color(0xFFD0775D),
                              isSelected: _selectedMaterial == 1,
                              onTap: () {
                                setState(() {
                                  _selectedMaterial = 1;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: TextButton(
                        onPressed: () => AppRouter.pushEstimate(context),
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
                          'Сформировать смету',
                          textAlign: TextAlign.center,
                          style: AppTextTheme.buttonLabel,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.title,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFE7E7E7),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(
            color: isSelected ? AppColors.headingText : const Color(0xFFD0D0D0),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Icon(
                Icons.view_stream_rounded,
                size: 70,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.headingText,
                fontSize: AppTextSizes.s30,
              ),
            ),
          ],
        ),
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
