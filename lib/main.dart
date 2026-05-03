import 'package:flutter/material.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/screens/auth_splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Фасадные термопанели',
      debugShowCheckedModeBanner: false,
      home: const AuthSplashScreen(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
