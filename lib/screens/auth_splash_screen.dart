import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/screens/catalog_screen.dart';
import 'package:termopaneli_app/services/auth_api_service.dart';
import 'package:termopaneli_app/services/session_service.dart';

/// При старте: открываем каталог. Если сохранён токен — проверяем его через
/// [AuthApiService.validateSession] (недействительный токен снимается при ответе 401 с сервера).
/// Вход по желанию — с экрана «Профиль» или при сохранении сметы / заявке (см. [AuthFlow.ensureLoggedIn]).
class AuthSplashScreen extends StatefulWidget {
  const AuthSplashScreen({super.key});

  @override
  State<AuthSplashScreen> createState() => _AuthSplashScreenState();
}

class _AuthSplashScreenState extends State<AuthSplashScreen> {
  late final Future<Widget> _firstScreen;

  @override
  void initState() {
    super.initState();
    _firstScreen = _resolveStart();
  }

  Future<Widget> _resolveStart() async {
    final String? token = await SessionService.getToken();
    debugPrint('AuthSplash: token exists = ${token != null && token.isNotEmpty}');
    if (token != null && token.isNotEmpty) {
      try {
        final bool sessionOk = await AuthApiService.validateSession(token);
        debugPrint('AuthSplash: session valid = $sessionOk');
      } catch (e, st) {
        debugPrint('AuthSplash: validateSession error $e $st');
      }
    }
    return const CatalogScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _firstScreen,
      builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.pageBackground,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        return snapshot.data ?? const CatalogScreen();
      },
    );
  }
}
