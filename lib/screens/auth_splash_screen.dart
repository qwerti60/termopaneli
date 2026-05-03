import 'package:flutter/material.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/screens/catalog_screen.dart';
import 'package:termopaneli_app/screens/login_screen.dart';
import 'package:termopaneli_app/services/auth_api_service.dart';
import 'package:termopaneli_app/services/session_service.dart';

/// При старте: токен + валидная сессия → каталог; иначе экран входа.
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
      final bool sessionOk = await AuthApiService.validateSession(token);
      debugPrint('AuthSplash: session valid = $sessionOk');
      if (sessionOk) {
        return const CatalogScreen();
      }
      // Не очищаем токен автоматически: при временной сетевой ошибке
      // иначе теряется сессия и пользователь вынужден входить заново.
    }
    return const LoginScreen();
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
        return snapshot.data ?? const LoginScreen();
      },
    );
  }
}
