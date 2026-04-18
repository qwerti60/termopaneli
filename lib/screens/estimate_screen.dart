import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';

class EstimateScreen extends StatefulWidget {
  const EstimateScreen({super.key});

  @override
  State<EstimateScreen> createState() => _EstimateScreenState();
}

class _EstimateScreenState extends State<EstimateScreen> {
  bool _materialsSelected = true;

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
                      'Смета 1',
                      textAlign: TextAlign.center,
                      style: AppTextTheme.screenTitle,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Text(
                      '22.10.24',
                      style: TextStyle(
                        color: AppColors.headingText,
                        fontSize: AppTextSizes.s34,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      text: 'Материалы',
                      isSelected: _materialsSelected,
                      onTap: () => setState(() => _materialsSelected = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TabButton(
                      text: 'Работы',
                      isSelected: !_materialsSelected,
                      onTap: () => setState(() => _materialsSelected = false),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const _EstimateHeaderRow(),
                  const Divider(height: 1, color: Color(0xFFC9C9C9)),
                  for (int i = 1; i <= 5; i++) _EstimateDataRow(index: i),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: isSelected ? AppColors.onAccent : AppColors.headingText,
        backgroundColor:
            isSelected ? AppColors.primaryButtonBackground : AppColors.pageBackground,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          side: BorderSide(
            color: isSelected
                ? AppColors.primaryButtonBackground
                : const Color(0xFFC9C9C9),
          ),
        ),
      ),
      child: Text(text, style: const TextStyle(fontSize: AppTextSizes.s38)),
    );
  }
}

class _EstimateHeaderRow extends StatelessWidget {
  const _EstimateHeaderRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('№', style: AppTextTheme.body33),
          ),
          Expanded(
            child: Text('Наименование', style: AppTextTheme.body33),
          ),
          SizedBox(
            width: 40,
            child: Text('Ед.', style: AppTextTheme.body33),
          ),
          SizedBox(
            width: 46,
            child: Text('Кол-во', style: AppTextTheme.body33),
          ),
        ],
      ),
    );
  }
}

class _EstimateDataRow extends StatelessWidget {
  const _EstimateDataRow({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$index',
              textAlign: TextAlign.center,
              style: AppTextTheme.body33,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('Наименование', style: AppTextTheme.body33),
            ),
          ),
          const SizedBox(
            width: 40,
            child: Text(
              'шт',
              textAlign: TextAlign.center,
              style: AppTextTheme.body33,
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              '$index',
              textAlign: TextAlign.center,
              style: AppTextTheme.body33,
            ),
          ),
        ],
      ),
    );
  }
}
