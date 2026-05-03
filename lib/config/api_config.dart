/// Базовый URL PHP API без завершающего слэша.
/// Переопределение: `--dart-define=API_BASE_URL=https://другой-домен.ru/tp_api`
abstract final class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ivnovav.ru/tp_api',
  );

  /// Временный режим без SMS: кнопка "Прислать sms-код" не вызывает отправку,
  /// а пользователь вводит этот код. Пустое значение включает обычную отправку.
  static const String devStaticOtpCode = String.fromEnvironment(
    'DEV_STATIC_OTP_CODE',
    defaultValue: '123456',
  );
}
