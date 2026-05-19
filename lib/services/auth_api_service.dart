import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:termopaneli_app/config/api_config.dart';
import 'package:termopaneli_app/services/session_service.dart';

class PhoneVerifyResult {
  const PhoneVerifyResult({
    required this.ok,
    this.token,
    this.isNewUser = false,
    this.errorMessage,
  });

  final bool ok;
  final String? token;
  final bool isNewUser;
  final String? errorMessage;
}

class RegisterResult {
  const RegisterResult({
    required this.ok,
    this.token,
    this.errorMessage,
  });

  final bool ok;
  final String? token;
  final String? errorMessage;
}

/// PHP-скрипты в репозитории: `backend/public/api/v1/auth/*.php`
///
/// `GET .../session.php` — заголовок `Authorization: Bearer <token>`, ответ 200 при валидной сессии;
/// 401 — сессия недействительна (при вызове из [validateSession] локальный токен удаляется).
///
/// `POST .../request-sms.php` — JSON `{ "phone": "79991234567" }`, отправка OTP (smsc в config.php).
///
/// `POST .../verify-phone.php` — JSON `{ "phone": "79991234567", "code": "123456" }`.
/// Для существующего пользователя ответ содержит token,
/// для нового: `{ "is_new_user": true }`.
///
/// `POST .../register.php` — JSON с телефоном, кодом, ФИО, email и `accepted_user_agreement: true`;
/// создаёт пользователя и возвращает token.
abstract final class AuthApiService {
  AuthApiService._();

  static Uri _uri(String path) {
    final String base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) {
      throw StateError('API_BASE_URL');
    }
    final String normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return Uri.parse('$normalized$path');
  }

  /// Возвращает true, если токен принят сервером и пользователь существует.
  /// При ответе **401** сохранённый токен удаляется (сессия недействительна).
  /// Сетевые ошибки и 5xx: токен **не** трогаем — при следующем запуске или открытии профиля повторим проверку.
  static Future<bool> validateSession(String token) async {
    if (token.isEmpty) {
      return false;
    }
    if (ApiConfig.baseUrl.trim().isEmpty) {
      return false;
    }
    try {
      final http.Response res = await http
          .get(
            _uri('/api/v1/auth/session.php?token=${Uri.encodeComponent(token)}'),
            headers: <String, String>{
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 401) {
        await SessionService.clearToken();
        return false;
      }
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Проверка телефона и кода на сервере; выдача токена.
  static Future<PhoneVerifyResult> verifyPhone({
    required String phone,
    required String code,
  }) async {
    if (ApiConfig.baseUrl.trim().isEmpty) {
      return const PhoneVerifyResult(
        ok: false,
        errorMessage:
            'Не задан API_BASE_URL. Укажите базовый URL API: --dart-define=API_BASE_URL=https://...',
      );
    }
    try {
      final http.Response res = await http
          .post(
            _uri('/api/v1/auth/verify-phone.php'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, String>{
              'phone': phone,
              'code': code,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final dynamic data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final String? token = data['token'] as String?;
          final bool isNew = data['is_new_user'] == true;
          if (isNew) {
            return const PhoneVerifyResult(
              ok: true,
              isNewUser: true,
            );
          }
          if (token != null && token.isNotEmpty) {
            return PhoneVerifyResult(
              ok: true,
              token: token,
              isNewUser: false,
            );
          }
        }
        return const PhoneVerifyResult(
          ok: false,
          errorMessage: 'Некорректный ответ сервера',
        );
      }

      String? msg;
      try {
        final dynamic data = jsonDecode(res.body);
        if (data is Map && data['message'] != null) {
          msg = data['message'].toString();
        } else if (data is Map && data['error'] != null) {
          msg = data['error'].toString();
        }
      } catch (_) {
        msg = res.body.isNotEmpty ? res.body : null;
      }

      return PhoneVerifyResult(
        ok: false,
        errorMessage: msg ?? 'Ошибка ${res.statusCode}',
      );
    } catch (e) {
      return PhoneVerifyResult(
        ok: false,
        errorMessage: 'Нет связи с сервером: $e',
      );
    }
  }

  /// Запрос SMS-кода на сервере (см. `request-sms.php`).
  static Future<({bool ok, String? errorMessage})> requestSms({
    required String phone,
  }) async {
    if (ApiConfig.baseUrl.trim().isEmpty) {
      return (
        ok: false,
        errorMessage: 'Не задан API_BASE_URL',
      );
    }
    try {
      final http.Response res = await http
          .post(
            _uri('/api/v1/auth/request-sms.php'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, String>{'phone': phone}),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        return (ok: true, errorMessage: null);
      }

      String? msg;
      try {
        final dynamic data = jsonDecode(res.body);
        if (data is Map && data['message'] != null) {
          msg = data['message'].toString();
        } else if (data is Map && data['error'] != null) {
          msg = data['error'].toString();
        }
      } catch (_) {
        msg = res.body.isNotEmpty ? res.body : null;
      }

      return (
        ok: false,
        errorMessage: msg ?? 'Ошибка ${res.statusCode}',
      );
    } catch (e) {
      return (
        ok: false,
        errorMessage: 'Нет связи с сервером: $e',
      );
    }
  }

  static Future<RegisterResult> registerNewUser({
    required String phone,
    required String code,
    required String lastName,
    required String firstName,
    required String middleName,
    required String email,
    required bool acceptedUserAgreement,
  }) async {
    if (ApiConfig.baseUrl.trim().isEmpty) {
      return const RegisterResult(
        ok: false,
        errorMessage: 'Не задан API_BASE_URL',
      );
    }
    try {
      final http.Response res = await http
          .post(
            _uri('/api/v1/auth/register.php'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, Object?>{
              'phone': phone,
              'code': code,
              'last_name': lastName,
              'first_name': firstName,
              'middle_name': middleName,
              'email': email,
              'accepted_user_agreement': acceptedUserAgreement,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final dynamic data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final String? token = data['token'] as String?;
          if (token != null && token.isNotEmpty) {
            return RegisterResult(ok: true, token: token);
          }
        }
        return const RegisterResult(ok: false, errorMessage: 'Некорректный ответ сервера');
      }

      String? msg;
      try {
        final dynamic data = jsonDecode(res.body);
        if (data is Map && data['message'] != null) {
          msg = data['message'].toString();
        } else if (data is Map && data['error'] != null) {
          msg = data['error'].toString();
        }
      } catch (_) {
        msg = res.body.isNotEmpty ? res.body : null;
      }
      return RegisterResult(ok: false, errorMessage: msg ?? 'Ошибка ${res.statusCode}');
    } catch (e) {
      return RegisterResult(ok: false, errorMessage: 'Нет связи с сервером: $e');
    }
  }
}
