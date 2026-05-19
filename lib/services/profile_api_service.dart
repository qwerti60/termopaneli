import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:termopaneli_app/config/api_config.dart';
import 'package:termopaneli_app/models/user_profile.dart';
import 'package:termopaneli_app/services/session_service.dart';

abstract final class ProfileApiService {
  ProfileApiService._();

  static Uri _uri(String path, {String? token}) {
    final String base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) {
      throw StateError('API_BASE_URL');
    }
    final String normalized =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final Uri uri = Uri.parse('$normalized$path');
    if (token == null || token.isEmpty) {
      return uri;
    }
    return uri.replace(
      queryParameters: <String, String>{...uri.queryParameters, 'token': token},
    );
  }

  /// `null` — нет токена или 401; иначе профиль.
  static Future<UserProfile?> fetchMe() async {
    final String? token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    final http.Response res = await http
        .get(
          _uri('/api/v1/profile/me.php', token: token),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) {
      await SessionService.clearToken();
      return null;
    }
    if (res.statusCode == 404) {
      throw Exception(
        'Профиль недоступен (404). На сервер нужно залить '
        '`public/api/v1/profile/me.php` или проверить, что в API_BASE_URL '
        'указан каталог с этим API (часто …/tp_api).',
      );
    }
    if (res.statusCode != 200) {
      throw Exception('Профиль: ответ сервера ${res.statusCode}');
    }
    final Object? data = json.decode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Некорректный ответ профиля');
    }
    return UserProfile.fromJson(data);
  }

  /// Инвалидирует токен на сервере (если доступен `auth/logout.php`). Ошибки сети игнорируются.
  static Future<void> logoutRemote() async {
    final String? token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      await http
          .post(
            _uri('/api/v1/auth/logout.php', token: token),
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  /// Обновляет ФИО и email; телефон на сервере не меняется.
  /// При 401 токен очищается.
  static Future<UserProfile> updateProfile({
    required String lastName,
    required String firstName,
    required String middleName,
    required String email,
  }) async {
    final String? token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('Нет сессии');
    }
    final http.Response res = await http
        .post(
          _uri('/api/v1/profile/update.php', token: token),
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(<String, String>{
            'last_name': lastName,
            'first_name': firstName,
            'middle_name': middleName,
            'email': email,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) {
      await SessionService.clearToken();
      throw Exception('Сессия истекла. Войдите снова.');
    }
    if (res.statusCode != 200) {
      String msg = 'Ответ сервера ${res.statusCode}';
      try {
        final Object? decoded = json.decode(res.body);
        if (decoded is Map<String, dynamic>) {
          final Object? m = decoded['message'] ?? decoded['error'];
          if (m != null && '$m'.trim().isNotEmpty) {
            msg = '$m'.trim();
          }
        }
      } catch (_) {}
      throw Exception(msg);
    }
    final Object? data = json.decode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Некорректный ответ профиля');
    }
    return UserProfile.fromJson(data);
  }
}
