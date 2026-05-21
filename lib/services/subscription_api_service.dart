import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:termopaneli_app/config/api_config.dart';
import 'package:termopaneli_app/models/subscription_status.dart';
import 'package:termopaneli_app/services/api_user_blocked.dart';
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
  static Future<SubscriptionStatus?> fetchStatus() async {
    final String? token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    final http.Response res = await http
        .get(
          _uri('/api/v1/subscription/status.php', token: token),
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
    if (ApiUserBlocked.isUserBlockedResponse(res)) {
      await SessionService.clearToken();
      return null;
    }
    if (res.statusCode != 200) {
      throw Exception('Подписка: ответ ${res.statusCode}');
    }
    final Object? data = json.decode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Некорректный ответ');
    }
    return SubscriptionStatus.fromJson(data);
  }

  /// Заглушка оплаты: сервер пишет событие и возвращает `ok: false`, `code: acquiring_not_configured`.
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
    final Object? data = json.decode(res.body);
    if (data is! Map<String, dynamic>) {
      return (ok: false, code: 'bad_response', message: 'Ошибка сервера');
    }
    final bool ok = data['ok'] == true;
    final String? code = data['code']?.toString();
    final String? msg = data['message']?.toString();
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
    final Object? data = json.decode(res.body);
    if (data is! Map<String, dynamic>) {
      return (ok: false, message: 'Ошибка сервера');
    }
    if (res.statusCode == 200 && data['ok'] == true) {
      return (ok: true, message: null);
    }
    final String? msg = data['message']?.toString();
    return (ok: false, message: msg ?? 'Не удалось отменить');
  }
}
