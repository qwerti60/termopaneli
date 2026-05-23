/// Имена маршрутов приложения — единственное место для строковых путей.
abstract final class AppRoutes {
  AppRoutes._();

  /// Не `'/'`: у [MaterialApp] задан `home`, иначе [Navigator.pushNamed] на `'/'` не открывает экран входа.
  static const String login = '/login';
  static const String registration = '/registration';
  static const String personalData = '/personal-data';
  static const String personalDataConfirm = '/personal-data-confirm';
  static const String profile = '/profile';
  /// Если `kHomeScreenEnabled == false` (`lib/config/app_features.dart`), маршрут [home] открывает экран примерки вместо отдельного «Дом».
  static const String home = '/home';
  static const String editing = '/editing';
  static const String subscription = '/subscription';
  static const String smartCalc = '/smart-calc';
  static const String catalog = '/catalog';
  static const String search = '/search';
  static const String myData = '/my-data';
  static const String estimate = '/estimate';
  static const String savedEstimates = '/saved-estimates';
  static const String myEstimateRequests = '/my-estimate-requests';
  static const String adminLogin = '/admin-login';
  static const String adminRequests = '/admin-requests';
  static const String windowSlopes = '/window-slopes';
  static const String productDetails = '/product-details';
  static const String panelFit = '/panel-fit';
}
