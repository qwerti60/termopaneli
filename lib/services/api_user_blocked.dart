import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:termopaneli_app/services/session_service.dart';

/// Ответ API при блокировке пользователя веб-админом: HTTP 403 и `code: user_blocked`.
abstract final class ApiUserBlocked {
  ApiUserBlocked._();

  static bool isUserBlockedResponse(http.Response res) {
    if (res.statusCode != 403) {
      return false;
    }
    try {
      final Object? data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) {
        return data['code'] == 'user_blocked';
      }
    } catch (_) {}
    return false;
  }

  static Future<void> clearTokenIfBlocked(http.Response res) async {
    if (isUserBlockedResponse(res)) {
      await SessionService.clearToken();
    }
  }
}
