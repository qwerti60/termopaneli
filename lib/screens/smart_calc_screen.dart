import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/models/user_profile.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/services/app_manifest_api_service.dart';
import 'package:termopaneli_app/services/profile_api_service.dart';
import 'package:termopaneli_app/services/session_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// SmartCalc во встроенном WebView. Доступ только при **PRO** ([UserProfile.isPro]).
class SmartCalcScreen extends StatefulWidget {
  const SmartCalcScreen({super.key});

  @override
  State<SmartCalcScreen> createState() => _SmartCalcScreenState();
}

enum _SmartGate { loading, notLoggedIn, notPro, noUrl, badUrl, ready, error }

class _SmartCalcScreenState extends State<SmartCalcScreen> {
  _SmartGate _gate = _SmartGate.loading;
  String? _errorDetail;
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final String? token = await SessionService.getToken();
    if (!mounted) {
      return;
    }
    if (token == null || token.isEmpty) {
      setState(() {
        _gate = _SmartGate.notLoggedIn;
      });
      return;
    }
    try {
      final UserProfile? profile = await ProfileApiService.fetchMe();
      if (!mounted) {
        return;
      }
      if (profile == null) {
        setState(() {
          _gate = _SmartGate.notLoggedIn;
        });
        return;
      }
      if (!profile.isPro) {
        setState(() {
          _gate = _SmartGate.notPro;
        });
        return;
      }
      final AppManifest? manifest =
          await AppManifestApiService.fetch(bypassCache: true);
      if (!mounted) {
        return;
      }
      final String url = manifest?.smartCalcUrl.trim() ?? '';
      if (url.isEmpty) {
        setState(() {
          _gate = _SmartGate.noUrl;
        });
        return;
      }
      final Uri? uri = Uri.tryParse(url);
      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        setState(() {
          _gate = _SmartGate.badUrl;
          _errorDetail = url;
        });
        return;
      }
      final WebViewController controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (NavigationRequest request) {
              final Uri? u = Uri.tryParse(request.url);
              if (u != null &&
                  u.hasScheme &&
                  (u.scheme == 'https' || u.scheme == 'http')) {
                return NavigationDecision.navigate;
              }
              return NavigationDecision.prevent;
            },
          ),
        )
        ..loadRequest(uri);
      setState(() {
        _controller = controller;
        _gate = _SmartGate.ready;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _gate = _SmartGate.error;
        _errorDetail = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('SmartCalc'),
      ),
      body: switch (_gate) {
        _SmartGate.loading => const Center(child: CircularProgressIndicator()),
        _SmartGate.notLoggedIn => _MessagePane(
            title: 'Нужен вход',
            body:
                'Войдите в аккаунт, чтобы пользоваться SmartCalc.',
            primaryLabel: 'В профиль',
            onPrimary: () {
              if (Navigator.of(context).canPop()) {
                Navigator.pop(context);
              } else {
                AppRouter.pushProfile(context);
              }
            },
          ),
        _SmartGate.notPro => _MessagePane(
            title: 'Только для PRO',
            body:
                'SmartCalc доступен при активной подписке PRO. Оформите подписку в разделе ниже.',
            primaryLabel: 'Управление подпиской',
            onPrimary: () async {
              await AppRouter.pushSubscription(context);
              if (!context.mounted) {
                return;
              }
              setState(() {
                _gate = _SmartGate.loading;
              });
              await _prepare();
            },
          ),
        _SmartGate.noUrl => _MessagePane(
            title: 'Ссылка не настроена',
            body:
                'Администратору сервера: задайте в config.php поле '
                'app_manifest.smartcalc_url (HTTPS-адрес SmartCalc). '
                'После сохранения подождите несколько минут или перезапустите приложение.',
            primaryLabel: 'Назад',
            onPrimary: () => Navigator.pop(context),
          ),
        _SmartGate.badUrl => _MessagePane(
            title: 'Некорректный URL',
            body:
                'В настройках сервера указан адрес не в формате http(s). '
                'Исправьте app_manifest.smartcalc_url.',
            detail: _errorDetail,
            primaryLabel: 'Назад',
            onPrimary: () => Navigator.pop(context),
          ),
        _SmartGate.error => _MessagePane(
            title: 'Ошибка',
            body: 'Не удалось открыть SmartCalc.',
            detail: _errorDetail,
            primaryLabel: 'Повторить',
            onPrimary: () {
              setState(() {
                _gate = _SmartGate.loading;
                _errorDetail = null;
                _controller = null;
              });
              _prepare();
            },
          ),
        _SmartGate.ready => _controller == null
            ? const Center(child: Text('Внутренняя ошибка'))
            : WebViewWidget(controller: _controller!),
      },
    );
  }
}

class _MessagePane extends StatelessWidget {
  const _MessagePane({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.detail,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
            if (detail != null && detail!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(
                detail!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const Spacer(),
            FilledButton(
              onPressed: onPrimary,
              child: Text(primaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
