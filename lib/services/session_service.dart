import 'package:shared_preferences/shared_preferences.dart';
import 'package:termopaneli_app/services/pro_subscription_grace.dart';

abstract final class SessionService {
  SessionService._();

  static const String _keyToken = 'auth_token';
  static const String _keyAdminApiToken = 'admin_api_token';

  static Future<String?> getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<void> saveToken(String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? prev = prefs.getString(_keyToken);
    if (prev != null && prev != token) {
      await ProSubscriptionGrace.clear();
    }
    await prefs.setString(_keyToken, token);
  }

  static Future<void> clearToken() async {
    await ProSubscriptionGrace.clear();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
  }

  static Future<String?> getAdminApiToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAdminApiToken);
  }

  static Future<void> saveAdminApiToken(String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAdminApiToken, token.trim());
  }

  static Future<void> clearAdminApiToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAdminApiToken);
  }
}
