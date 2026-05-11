import 'package:shared_preferences/shared_preferences.dart';

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
    await prefs.setString(_keyToken, token);
  }

  static Future<void> clearToken() async {
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
