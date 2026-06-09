import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:termopaneli_app/config/ads_config.dart';
import 'package:termopaneli_app/routes/app_router.dart';
import 'package:termopaneli_app/screens/auth_splash_screen.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initMobileAds();
  runApp(const MyApp());
}

Future<void> _initMobileAds() async {
  if (!AdsConfig.yandexAdsEnabled ||
      kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return;
  }

  await YandexAds.setLocationTracking(false);
  await YandexAds.initialize();
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
