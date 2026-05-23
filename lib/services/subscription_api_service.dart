import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:termopaneli_app/config/api_config.dart';
import 'package:termopaneli_app/models/subscription_status.dart';
import 'package:termopaneli_app/services/api_user_blocked.dart';
import 'package:termopaneli_app/services/pro_subscription_grace.dart';
import 'package:termopaneli_app/services/session_service.dart';

abstract final class SubscriptionApiService {
  SubscriptionApiService._();

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

  /// `null` — нет токена или 401; иначе статус подписки.
  /// [bustCache]: заголовки против промежуточного кэша (как у профиля).
  static Future<SubscriptionStatus?> fetchStatus({bool bustCache = false}) async {
    final String? token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    if (bustCache) {
      headers['Cache-Control'] = 'no-cache';
      headers['Pragma'] = 'no-cache';
    }
    final http.Response res = await http
        .get(
          _uri('/api/v1/subscription/status.php', token: token),
          headers: headers,
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) {
      await SessionService.clearToken();
      return null;
    }
    if (ApiUserBlocked.isUserBlockedResponse(res)) {
      await SessionService.clearToken();
      return null;
    }
    if (res.statusCode == 404) {
      throw Exception(
        'Подписка недоступна (404). На сервер нужно залить каталог '
        '`public/api/v1/subscription/` (файлы status.php, checkout.php, cancel.php) '
        'и выполнить миграцию `backend/sql/migrate_user_subscriptions.sql`. '
        'Проверьте, что в API_BASE_URL указан корень API (часто …/tp_api).',
      );
    }
    if (res.statusCode != 200) {
      throw Exception('Подписка: ответ сервера ${res.statusCode}');
    }
    final String raw = res.body.trim();
    if (raw.isEmpty) {
      throw Exception('Подписка: пустой ответ сервера');
    }
    if (!raw.startsWith('{') && !raw.startsWith('[')) {
      final String head = raw.length > 120 ? '${raw.substring(0, 120)}…' : raw;
      throw Exception(
        'Подписка: сервер вернул не JSON. Начало ответа: $head',
      );
    }
    final Object? data = json.decode(raw);
    if (data is! Map) {
      throw Exception('Некорректный ответ');
    }
    return SubscriptionStatus.fromJson(Map<String, dynamic>.from(data));
  }

  /// Оформление подписки без эквайринга: при успехе сервер возвращает `ok: true` и активирует PRO на срок тарифа.
  static Future<({bool ok, String? code, String? message})> checkoutStub(
    String planCode,
  ) async {
    final String? token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      return (ok: false, code: 'no_token', message: 'Нужно войти в аккаунт');
    }
    final http.Response res = await http
        .post(
          _uri('/api/v1/subscription/checkout.php', token: token),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(<String, String>{'plan_code': planCode}),
        )
        .timeout(const Duration(seconds: 25));
    if (ApiUserBlocked.isUserBlockedResponse(res)) {
      await SessionService.clearToken();
      return (ok: false, code: 'user_blocked', message: 'Аккаунт заблокирован');
    }
    final String raw = res.body.trim();
    if (raw.isEmpty) {
      return (ok: false, code: 'bad_response', message: 'Пустой ответ сервера');
    }
    if (!raw.startsWith('{') && !raw.startsWith('[')) {
      return (ok: false, code: 'bad_response', message: 'Сервер вернул не JSON (ошибка PHP?)');
    }
    final Object? decoded = json.decode(raw);
    if (decoded is! Map) {
      return (ok: false, code: 'bad_response', message: 'Ошибка сервера');
    }
    final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);
    final bool ok = data['ok'] == true;
    final String? code = data['code']?.toString();
    final String? msg = data['message']?.toString();
    if (ok && res.statusCode == 200) {
      await ProSubscriptionGrace.grantMinutes(30);
    }
    return (ok: ok, code: code, message: msg);
  }

  /// Отмена активной подписки на сервере.
  static Future<({bool ok, String? message})> cancelSubscription() async {
    final String? token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      return (ok: false, message: 'Нужно войти в аккаунт');
    }
    final http.Response res = await http
        .post(
          _uri('/api/v1/subscription/cancel.php', token: token),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 25));
    if (ApiUserBlocked.isUserBlockedResponse(res)) {
      await SessionService.clearToken();
      return (ok: false, message: 'Аккаунт заблокирован');
    }
    final String rawCancel = res.body.trim();
    if (rawCancel.isEmpty) {
      return (ok: false, message: 'Пустой ответ сервера');
    }
    if (!rawCancel.startsWith('{') && !rawCancel.startsWith('[')) {
      return (ok: false, message: 'Сервер вернул не JSON');
    }
    final Object? decodedCancel = json.decode(rawCancel);
    if (decodedCancel is! Map) {
      return (ok: false, message: 'Ошибка сервера');
    }
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(decodedCancel);
    if (res.statusCode == 200 && data['ok'] == true) {
      await ProSubscriptionGrace.clear();
      return (ok: true, message: null);
    }
    final String? msg = data['message']?.toString();
    return (ok: false, message: msg ?? 'Не удалось отменить');
  }
}
