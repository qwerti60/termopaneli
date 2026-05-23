import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_sizes.dart';
import 'package:termopaneli_app/design/app_text_styles.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/models/subscription_status.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/services/pro_subscription_grace.dart';
import 'package:termopaneli_app/services/session_service.dart';
import 'package:termopaneli_app/services/subscription_api_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _selectedIndex = 2;
  bool _loading = true;
  bool _needsLogin = false;
  String? _error;
  SubscriptionStatus? _status;
  bool _checkoutBusy = false;
  bool _cancelBusy = false;

  static const List<_PlanData> _plans = <_PlanData>[
    _PlanData(code: '1m', title: 'Подписка на 1 месяц', price: '349'),
    _PlanData(code: '3m', title: 'Подписка на 3 месяца', price: '999'),
    _PlanData(code: '6m', title: 'Подписка на 6 месяцев', price: '1 999'),
    _PlanData(code: '1y', title: 'Подписка на 1 год', price: '3 999'),
  ];

  /// Уже есть PRO / активная подписка — повторное оформление через checkout запрещено (см. API 409).
  bool get _hasActiveProOrSubscription =>
      _status != null && (_status!.isPro || _status!.subscription != null);

  /// Блокировка кнопки «Перейти к оплате» (есть активный PRO, не гость и не экран ошибки).
  bool get _purchaseButtonLocked =>
      !_needsLogin &&
      _error == null &&
      !_loading &&
      _hasActiveProOrSubscription;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final String? token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _needsLogin = true;
        _status = null;
        _error = null;
      });
      return;
    }
    setState(() => _needsLogin = false);
    try {
      final SubscriptionStatus? s =
          await SubscriptionApiService.fetchStatus(bustCache: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = s;
        _loading = false;
        _error = null;
      });
      if (s != null && (s.isPro || s.subscription != null)) {
        await ProSubscriptionGrace.grantMinutes(24 * 60);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _onCheckout() async {
    final String? token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите в аккаунт, чтобы оформить подписку')),
      );
      return;
    }
    if (_hasActiveProOrSubscription) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Сначала отмените текущую подписку PRO, затем можно оформить новую.',
          ),
        ),
      );
      return;
    }
    final _PlanData plan = _plans[_selectedIndex];
    setState(() => _checkoutBusy = true);
    final ({bool ok, String? code, String? message}) r =
        await SubscriptionApiService.checkoutStub(plan.code);
    if (!mounted) {
      return;
    }
    setState(() => _checkoutBusy = false);
    final String text = r.message ??
        (r.ok
            ? 'Оплата прошла'
            : 'Онлайн-оплата пока недоступна. Обратитесь в офис или дождитесь подключения эквайринга.');
    final String dialogTitle = r.ok
        ? 'Готово'
        : (r.code == 'already_subscribed' ? 'Подписка' : 'Оплата');
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(dialogTitle),
        content: SingleChildScrollView(child: Text(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
    if (r.ok && mounted) {
      await _load();
    }
  }

  Future<void> _onCancelSubscription() async {
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Отменить подписку?'),
        content: const Text(
          'PRO будет отключён после подтверждения. Повторно оформить подписку можно позже (когда заработает оплата).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отменить подписку')),
        ],
      ),
    );
    if (go != true || !mounted) {
      return;
    }
    setState(() => _cancelBusy = true);
    final ({bool ok, String? message}) r =
        await SubscriptionApiService.cancelSubscription();
    if (!mounted) {
      return;
    }
    setState(() => _cancelBusy = false);
    if (r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Подписка отменена')),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.message ?? 'Не удалось отменить')),
      );
    }
  }

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
              const SizedBox(height: 4),
              const Text(
                'Пока не подключён эквайринг: по кнопке «Перейти к оплате» подписка PRO оформляется сразу на выбранный срок (без списания денег).',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: AppTextSizes.s24,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(child: _buildBody()),
              Padding(
                padding: const EdgeInsets.only(bottom: 14, top: 10),
                child: TextButton(
                  onPressed:
                      _checkoutBusy || _purchaseButtonLocked ? null : _onCheckout,
                  style: TextButton.styleFrom(
                    fixedSize: const Size(double.infinity, 33),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.center,
                    foregroundColor: AppColors.primaryButtonText,
                    backgroundColor: _purchaseButtonLocked
                        ? const Color(0xFF94A3B8)
                        : AppColors.primaryButtonBackground,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                  child: _checkoutBusy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Перейти к оплате',
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (_needsLogin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Войдите в аккаунт, чтобы видеть статус подписки и оформить PRO.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => AppRouter.pushProfile(context),
              child: const Text('В профиль'),
            ),
          ],
        ),
      );
    }
    final ActiveSubscription? sub = _status?.subscription;
    final bool showProLite = _status?.isPro == true && sub == null;
    final bool showCancel = _status != null &&
        (_status!.isPro || _status!.subscription != null);
    final bool blockNewSubscription =
        !_needsLogin && _error == null && showCancel;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sub != null) ...[
            _ActiveSubscriptionCard(sub: sub),
            const SizedBox(height: 10),
          ] else if (showProLite) ...[
            const _ProWithoutSubscriptionCard(),
            const SizedBox(height: 10),
          ],
          if (blockNewSubscription) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'При активной подписке PRO повторное оформление недоступно. Чтобы выбрать другой тариф, сначала отмените текущую подписку.',
                style: TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: AppTextSizes.s24,
                  height: 1.35,
                ),
              ),
            ),
          ],
          for (int i = 0; i < _plans.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _PlanCard(
              plan: _plans[i],
              isSelected: _selectedIndex == i,
              onSelect: blockNewSubscription
                  ? null
                  : () => setState(() => _selectedIndex = i),
            ),
          ],
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'После подключения эквайринга оплата будет списываться через платёжный шлюз. Отмена текущей подписки — кнопкой ниже.',
              style: TextStyle(
                color: AppColors.headingText,
                fontSize: AppTextSizes.s22,
              ),
            ),
          ),
          if (showCancel) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _cancelBusy ? null : _onCancelSubscription,
              child: _cancelBusy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Отменить подписку'),
            ),
          ],
        ],
      ),
    );
  }
}

/// PRO в профиле есть, а объект подписки в ответе API ещё не пришёл — не блокируем отмену.
class _ProWithoutSubscriptionCard extends StatelessWidget {
  const _ProWithoutSubscriptionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: const Color(0xFF0369A1)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRO активен',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: AppTextSizes.s36,
              color: AppColors.headingText,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Статус подписки обновится при следующем запросе. Отмена — кнопкой ниже.',
            style: TextStyle(fontSize: AppTextSizes.s24, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _ActiveSubscriptionCard extends StatelessWidget {
  const _ActiveSubscriptionCard({required this.sub});

  final ActiveSubscription sub;

  @override
  Widget build(BuildContext context) {
    final String? exp = sub.expiresAt;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: const Color(0xFF0369A1)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Текущая подписка PRO',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: AppTextSizes.s36,
              color: AppColors.headingText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub.planTitle,
            style: const TextStyle(fontSize: AppTextSizes.s30, color: AppColors.headingText),
          ),
          if (exp != null && exp.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Действует до: $exp (UTC на сервере)',
                style: const TextStyle(fontSize: AppTextSizes.s24, color: Color(0xFF64748B)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanData {
  const _PlanData({
    required this.code,
    required this.title,
    required this.price,
  });

  final String code;
  final String title;
  final String price;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    this.onSelect,
  });

  final _PlanData plan;
  final bool isSelected;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final bool locked = onSelect == null;
    final Color cardBg =
        isSelected ? AppColors.pageBackground : AppColors.primaryButtonBackground;
    final Color cardBorder = isSelected ? AppColors.headingText : Colors.transparent;
    final Color textColor = isSelected ? AppColors.headingText : AppColors.onAccent;
    final Color buttonBg =
        isSelected ? AppColors.primaryButtonBackground : AppColors.pageBackground;
    final Color buttonFg =
        isSelected ? AppColors.onAccent : AppColors.headingText;

    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Container(
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
                  ' за период',
                  style: TextStyle(color: textColor, fontSize: AppTextSizes.s28),
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
      ),
    );
  }
}
