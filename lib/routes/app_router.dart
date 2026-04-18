import 'package:flutter/material.dart';
import 'package:termopaneli_app/routes/routes.dart';
import 'package:termopaneli_app/screens/catalog_screen.dart';
import 'package:termopaneli_app/screens/estimate_screen.dart';
import 'package:termopaneli_app/screens/editing_screen.dart';
import 'package:termopaneli_app/screens/editing_section_screen.dart';
import 'package:termopaneli_app/screens/home_screen.dart';
import 'package:termopaneli_app/screens/login_screen.dart';
import 'package:termopaneli_app/screens/my_data_screen.dart';
import 'package:termopaneli_app/screens/personal_data_confirm_screen.dart';
import 'package:termopaneli_app/screens/personal_data_screen.dart';
import 'package:termopaneli_app/screens/profile_screen.dart';
import 'package:termopaneli_app/screens/product_details_screen.dart';
import 'package:termopaneli_app/screens/registration_screen.dart';
import 'package:termopaneli_app/screens/search_screen.dart';
import 'package:termopaneli_app/screens/subscription_screen.dart';
import 'package:termopaneli_app/screens/window_slopes_screen.dart';

/// Централизованная генерация маршрутов и навигация по имени.
abstract final class AppRouter {
  AppRouter._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case AppRoutes.registration:
        return MaterialPageRoute<void>(
          builder: (_) => const RegistrationScreen(),
          settings: settings,
        );
      case AppRoutes.personalData:
        return MaterialPageRoute<void>(
          builder: (_) => const PersonalDataScreen(),
          settings: settings,
        );
      case AppRoutes.personalDataConfirm:
        return MaterialPageRoute<void>(
          builder: (_) => const PersonalDataConfirmScreen(),
          settings: settings,
        );
      case AppRoutes.profile:
        return MaterialPageRoute<void>(
          builder: (_) => const ProfileScreen(),
          settings: settings,
        );
      case AppRoutes.home:
        return MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      case AppRoutes.editing:
        return MaterialPageRoute<void>(
          builder: (_) => const EditingScreen(),
          settings: settings,
        );
      case AppRoutes.subscription:
        return MaterialPageRoute<void>(
          builder: (_) => const SubscriptionScreen(),
          settings: settings,
        );
      case AppRoutes.catalog:
        return MaterialPageRoute<void>(
          builder: (_) => const CatalogScreen(),
          settings: settings,
        );
      case AppRoutes.search:
        return MaterialPageRoute<void>(
          builder: (_) => const SearchScreen(),
          settings: settings,
        );
      case AppRoutes.myData:
        return MaterialPageRoute<void>(
          builder: (_) => const MyDataScreen(),
          settings: settings,
        );
      case AppRoutes.estimate:
        return MaterialPageRoute<void>(
          builder: (_) => const EstimateScreen(),
          settings: settings,
        );
      case AppRoutes.windowSlopes:
        return MaterialPageRoute<void>(
          builder: (_) => const WindowSlopesScreen(),
          settings: settings,
        );
      case AppRoutes.productDetails:
        return MaterialPageRoute<void>(
          builder: (_) => const ProductDetailsScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
    }
  }

  static Future<T?> pushRegistration<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.registration);
  }

  static Future<T?> pushPersonalData<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.personalData);
  }

  static Future<T?> pushPersonalDataConfirm<T extends Object?>(
    BuildContext context,
  ) {
    return Navigator.pushNamed<T>(context, AppRoutes.personalDataConfirm);
  }

  static Future<T?> pushProfile<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.profile);
  }

  static Future<T?> pushHome<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.home);
  }

  static Future<T?> pushEditing<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.editing);
  }

  static Future<T?> pushEditingSection<T extends Object?>(
    BuildContext context,
    String sectionName,
  ) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute<T>(
        builder: (_) => EditingSectionScreen(sectionName: sectionName),
      ),
    );
  }

  static Future<T?> pushSubscription<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.subscription);
  }

  static Future<T?> pushCatalog<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.catalog);
  }

  static Future<T?> pushSearch<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.search);
  }

  static Future<T?> pushMyData<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.myData);
  }

  static Future<T?> pushEstimate<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.estimate);
  }

  static Future<T?> pushWindowSlopes<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.windowSlopes);
  }

  static Future<T?> pushProductDetails<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.productDetails);
  }

  static Future<T?> pushLoginReplacing<T extends Object?>(BuildContext context) {
    return Navigator.pushNamedAndRemoveUntil<T>(
      context,
      AppRoutes.login,
      (_) => false,
    );
  }
}
