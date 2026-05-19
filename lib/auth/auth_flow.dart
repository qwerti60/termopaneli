import 'package:flutter/material.dart';
import 'package:termopaneli_app/auth/pending_registration.dart';
import 'package:termopaneli_app/routes/routes.dart';
import 'package:termopaneli_app/screens/login_screen.dart';
import 'package:termopaneli_app/services/auth_api_service.dart';
import 'package:termopaneli_app/services/session_service.dart';

/// После успешной проверки SMS:
/// - существующий пользователь -> токен + профиль
/// - новый пользователь -> переход к заполнению данных для регистрации
abstract final class AuthFlow {
  AuthFlow._();

  /// Соответствие гостевому режиму (App Store): вход не обязателен для каталога и сметы.
  /// Для действий с аккаунтом на сервере показываем диалог и при согласии открываем экран входа.
  static Future<bool> ensureLoggedIn(
    BuildContext context, {
    required String title,
    required String body,
  }) async {
    final String? token = await SessionService.getToken();
    if (token != null && token.isNotEmpty) {
      return true;
    }
    if (!context.mounted) {
      return false;
    }
    final bool? go = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Не сейчас'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Войти'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) {
      return false;
    }
    // Явный push: с [MaterialApp.home] именованные маршруты не всегда открывают Login.
    await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const LoginScreen(),
      ),
    );
    if (!context.mounted) {
      return false;
    }
    final String? after = await SessionService.getToken();
    if (!context.mounted) {
      return false;
    }
    if (after == null || after.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вход не выполнен')),
      );
      return false;
    }
    return true;
  }

  static Future<void> completeSmsSignIn(
    BuildContext context, {
    required String normalizedPhone,
    required String smsCode,
  }) async {
    final PhoneVerifyResult result = await AuthApiService.verifyPhone(
      phone: normalizedPhone,
      code: smsCode,
    );

    if (!context.mounted) {
      return;
    }

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Не удалось войти')),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }

    if (result.isNewUser) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.personalData,
        (_) => false,
        arguments: PendingRegistration(
          phone: normalizedPhone,
          smsCode: smsCode,
        ),
      );
      return;
    }

    if (result.token == null || result.token!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сервер не вернул токен')));
      return;
    }

    await SessionService.saveToken(result.token!);
    if (!context.mounted) {
      return;
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.profile, (_) => false);
  }
}
