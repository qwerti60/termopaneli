import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _selectedIndex = 2;

  static const List<_PlanData> _plans = <_PlanData>[
    _PlanData(title: 'Подписка на 1 месяц', price: '349'),
    _PlanData(title: 'Подписка на 3 месяца', price: '999'),
    _PlanData(title: 'Подписка на 6 месяцев', price: '1 999'),
    _PlanData(title: 'Подписка на 1 год', price: '3 999'),
  ];

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
                  const Expanded(
                    child: Text(
                      'Оформить подписку',
                      style: TextStyle(
                        color: AppColors.headingText,
                        fontSize: AppTextSizes.s46,
                        fontWeight: AppTextWeights.medium,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      size: 34,
                      color: AppColors.headingText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _plans.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == _plans.length) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Автоматическое продление, отменить можно в любой момент',
                          style: TextStyle(
                            color: AppColors.headingText,
                            fontSize: AppTextSizes.s22,
                          ),
                        ),
                      );
                    }
                    final _PlanData plan = _plans[index];
                    return _PlanCard(
                      plan: plan,
                      isSelected: _selectedIndex == index,
                      onSelect: () => setState(() => _selectedIndex = index),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14, top: 10),
                child: TextButton(
                  onPressed: () => AppRouter.pushProfile(context),
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
                    'Продолжить',
                    textAlign: TextAlign.center,
                    style: AppTextTheme.buttonLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanData {
  const _PlanData({required this.title, required this.price});

  final String title;
  final String price;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onSelect,
  });

  final _PlanData plan;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final Color cardBg =
        isSelected ? AppColors.pageBackground : AppColors.primaryButtonBackground;
    final Color cardBorder = isSelected ? AppColors.headingText : Colors.transparent;
    final Color textColor = isSelected ? AppColors.headingText : AppColors.onAccent;
    final Color buttonBg =
        isSelected ? AppColors.primaryButtonBackground : AppColors.pageBackground;
    final Color buttonFg =
        isSelected ? AppColors.onAccent : AppColors.headingText;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.title,
            style: TextStyle(
              color: textColor,
              fontSize: AppTextSizes.s44,
              fontWeight: AppTextWeights.medium,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${plan.price}₽',
                style: TextStyle(
                  color: textColor,
                  fontSize: AppTextSizes.s42,
                  fontWeight: AppTextWeights.medium,
                ),
              ),
              Text(
                ' /мес.',
                style: TextStyle(color: textColor, fontSize: AppTextSizes.s36),
              ),
              const Spacer(),
              TextButton(
                onPressed: onSelect,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(86, 36),
                  backgroundColor: buttonBg,
                  foregroundColor: buttonFg,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
                child: const Text('Выбрать', style: TextStyle(fontSize: AppTextSizes.s35)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
