import 'package:flutter/material.dart';
import 'package:termopaneli_app/auth/pending_registration.dart';
import 'package:termopaneli_app/routes/routes.dart';
import 'package:termopaneli_app/services/auth_api_service.dart';
import 'package:termopaneli_app/services/session_service.dart';

/// После успешной проверки SMS:
/// - существующий пользователь -> токен + профиль
/// - новый пользователь -> переход к заполнению данных для регистрации
abstract final class AuthFlow {
  AuthFlow._();

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

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.profile, (_) => false);
  }
}
