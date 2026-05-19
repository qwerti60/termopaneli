import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:termopaneli_app/config/api_config.dart';

class AdminAuthLoginResult {
  const AdminAuthLoginResult({
    required this.ok,
    this.token,
    this.login,
    this.errorMessage,
  });

  final bool ok;
  final String? token;
  final String? login;
  final String? errorMessage;
}

abstract final class AdminAuthApiService {
  AdminAuthApiService._();

  static String _normalizedBase() {
    final String base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) {
      throw StateError('API_BASE_URL');
    }
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  static Uri _loginUri() {
    return Uri.parse('${_normalizedBase()}/api/v1/admin/auth/login.php');
  }

  static Uri _logoutUri(String bearer) {
    return Uri.parse('${_normalizedBase()}/api/v1/admin/auth/logout.php')
        .replace(queryParameters: <String, String>{'token': bearer});
  }

  static Future<AdminAuthLoginResult> login({
    required String login,
    required String password,
  }) async {
    final String l = login.trim();
    if (l.isEmpty || password.isEmpty) {
      return const AdminAuthLoginResult(
        ok: false,
        errorMessage: 'Введите логин и пароль',
      );
    }
    try {
      final http.Response res = await http
          .post(
            _loginUri(),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, String>{
              'login': l,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final dynamic data = _decodeBody(res.body);
      if (res.statusCode == 200 && data is Map<String, dynamic>) {
        final String? t = data['token']?.toString();
        if (t == null || t.length < 32) {
          return const AdminAuthLoginResult(
            ok: false,
            errorMessage: 'Пустой ответ сервера',
          );
        }
        return AdminAuthLoginResult(
          ok: true,
          token: t,
          login: data['login']?.toString(),
        );
      }
      return AdminAuthLoginResult(
        ok: false,
        errorMessage: _messageFrom(data) ?? 'Ошибка ${res.statusCode}',
      );
    } catch (e) {
      return AdminAuthLoginResult(
        ok: false,
        errorMessage: 'Нет связи с сервером: $e',
      );
    }
  }

  /// Сбрасывает session token в БД (Bearer из [login]). Статический `admin_api_token` не трогает.
  static Future<bool> logout(String bearer) async {
    final String t = bearer.trim();
    if (t.isEmpty) {
      return true;
    }
    try {
      final http.Response res = await http
          .post(
            _logoutUri(t),
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization': 'Bearer $t',
            },
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static dynamic _decodeBody(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static String? _messageFrom(dynamic data) {
    if (data is Map) {
      return (data['message'] ?? data['error'])?.toString();
    }
    if (data is String && data.isNotEmpty) {
      return data;
    }
    return null;
  }
}
