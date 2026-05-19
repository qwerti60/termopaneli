import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/services/estimate_api_service.dart';
import 'package:termopaneli_app/services/session_service.dart';

/// Заявки по сметам текущего пользователя (строки `estimate_requests` из `estimates/list.php`).
class MyEstimateRequestsScreen extends StatefulWidget {
  const MyEstimateRequestsScreen({super.key});

  @override
  State<MyEstimateRequestsScreen> createState() =>
      _MyEstimateRequestsScreenState();
}

class _RequestsLoadResult {
  const _RequestsLoadResult({
    this.estimates,
    this.notSignedIn = false,
    this.errorMessage,
  });

  final List<SavedEstimate>? estimates;
  final bool notSignedIn;
  final String? errorMessage;
}

class _MyEstimateRequestsScreenState extends State<MyEstimateRequestsScreen> {
  late Future<_RequestsLoadResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_RequestsLoadResult> _load() async {
    final String? token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      return const _RequestsLoadResult(notSignedIn: true);
    }
    try {
      final List<SavedEstimate> all = await EstimateApiService.fetchSaved();
      final List<SavedEstimate> withRequest = all
          .where((SavedEstimate e) => e.hasEstimateRequest)
          .toList(growable: false);
      return _RequestsLoadResult(estimates: withRequest);
    } catch (e) {
      return _RequestsLoadResult(errorMessage: '$e');
    }
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  String _money(double value) {
    if (value == 0) {
      return 'по запросу';
    }
    return '${value.toStringAsFixed(0)} ₽';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.pageBackground,
        foregroundColor: AppColors.headingText,
        elevation: 0,
        title: const Text('Мои заявки', style: AppTextTheme.screenTitle),
      ),
      body: FutureBuilder<_RequestsLoadResult>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<_RequestsLoadResult> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final _RequestsLoadResult? r = snap.data;
          if (r == null) {
            return const Center(child: Text('Нет данных'));
          }
          if (r.notSignedIn) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Войдите в аккаунт, чтобы видеть заявки по сметам.',
                      textAlign: TextAlign.center,
                      style: AppTextTheme.body32,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => AppRouter.pushLoginReplacing(context),
                      child: const Text('Войти'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (r.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r.errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTextTheme.body32.copyWith(
                        color: const Color(0xFFB71C1C),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }
          final List<SavedEstimate> list = r.estimates ?? const <SavedEstimate>[];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Пока нет заявок. Откройте сохранённую смету и отправьте её как заявку.',
                      textAlign: TextAlign.center,
                      style: AppTextTheme.body32,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => AppRouter.pushSavedEstimates(context),
                      child: const Text('К сохранённым сметам'),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _load();
              });
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final SavedEstimate e = list[index];
                final String? when = e.requestCreatedAt?.trim();
                final String sub = when != null && when.isNotEmpty
                    ? '${e.statusSummary}\n$when'
                    : e.statusSummary;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  title: Text(
                    e.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextTheme.body34.copyWith(
                      color: AppColors.headingText,
                    ),
                  ),
                  subtitle: Text(
                    sub,
                    style: AppTextTheme.body32.copyWith(
                      color: const Color(0xFF757575),
                    ),
                  ),
                  trailing: Text(
                    _money(e.totalAmount),
                    style: AppTextTheme.body33,
                  ),
                  onTap: () => AppRouter.pushEstimate(context, estimate: e),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
