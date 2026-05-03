import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:termopaneli_app/config/smsc_auth.dart';

class SmsSendResult {
  const SmsSendResult({
    required this.isSuccess,
    this.errorMessage,
  });

  final bool isSuccess;
  final String? errorMessage;
}

class SmscService {
  static const String _loginFromDefine = String.fromEnvironment('SMSC_LOGIN');
  static const String _password = String.fromEnvironment('SMSC_PASSWORD');
  static const String _sender = String.fromEnvironment('SMSC_SENDER');

  static String get _login =>
      _loginFromDefine.isNotEmpty ? _loginFromDefine : kSmscLogin;

  static Future<SmsSendResult> sendCode({
    required String phone,
    required String code,
  }) async {
    if (_password.isEmpty) {
      return const SmsSendResult(
        isSuccess: false,
        errorMessage:
            'Не задан пароль SMSC. Запустите с --dart-define=SMSC_PASSWORD=... '
            'или скриптом run_smsc_local.sh (см. run_smsc_local.example.sh).',
      );
    }

    final Uri uri = Uri.https('smsc.ru', '/sys/send.php', <String, String>{
      'login': _login,
      'psw': _password,
      'phones': phone,
      'mes': 'Код подтверждения: $code',
      'fmt': '3',
      if (_sender.isNotEmpty) 'sender': _sender,
    });

    try {
      final http.Response response = await http.get(uri);
      final dynamic data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        return SmsSendResult(
          isSuccess: false,
          errorMessage: 'Ошибка HTTP ${response.statusCode}',
        );
      }

      if (data is Map<String, dynamic>) {
        if (data['error'] != null) {
          return SmsSendResult(
            isSuccess: false,
            errorMessage: data['error'].toString(),
          );
        }

        if (data['id'] != null) {
          return const SmsSendResult(isSuccess: true);
        }
      }

      return const SmsSendResult(
        isSuccess: false,
        errorMessage: 'Неожиданный ответ SMSC.',
      );
    } catch (_) {
      return const SmsSendResult(
        isSuccess: false,
        errorMessage: 'Не удалось отправить SMS. Проверьте интернет.',
      );
    }
  }
}
