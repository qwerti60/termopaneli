import 'package:shared_preferences/shared_preferences.dart';

/// После успешного [SubscriptionApiService.checkoutStub] даём доступ к PRO на устройстве,
/// пока сервер не начнёт стабильно отдавать is_pro в me/status (см. SmartCalc).
abstract final class ProSubscriptionGrace {
  ProSubscriptionGrace._();

  static const String _keyUntilMs = 'pro_subscription_grace_until_ms';

  static Future<void> grantMinutes(int minutes) async {
    if (minutes < 1) {
      return;
    }
    final DateTime until = DateTime.now().add(Duration(minutes: minutes));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUntilMs, until.millisecondsSinceEpoch);
  }

  static Future<bool> isActive() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? ms = prefs.getInt(_keyUntilMs);
    if (ms == null) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch < ms;
  }

  static Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUntilMs);
  }
}
