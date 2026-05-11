import 'package:flutter/material.dart';
import 'package:termopaneli_app/auth/pending_registration.dart';
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
import 'package:termopaneli_app/screens/admin_requests_screen.dart';
import 'package:termopaneli_app/screens/saved_estimates_screen.dart';
import 'package:termopaneli_app/services/catalog_api_service.dart';
import 'package:termopaneli_app/services/estimate_api_service.dart';
import 'package:termopaneli_app/services/session_service.dart';
import 'package:termopaneli_app/screens/search_screen.dart';
import 'package:termopaneli_app/screens/subscription_screen.dart';
import 'package:termopaneli_app/screens/window_slopes_screen.dart';

/// Централизованная генерация маршрутов и навигация по имени.
abstract final class AppRouter {
  AppRouter._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final Object? args = settings.arguments;
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
        final PendingRegistration pending = args is PendingRegistration
            ? args
            : const PendingRegistration(phone: '', smsCode: '');
        return MaterialPageRoute<void>(
          builder: (_) => PersonalDataScreen(pending: pending),
          settings: settings,
        );
      case AppRoutes.personalDataConfirm:
        final PendingRegistration pending = args is PendingRegistration
            ? args
            : const PendingRegistration(phone: '', smsCode: '');
        return MaterialPageRoute<void>(
          builder: (_) => PersonalDataConfirmScreen(pending: pending),
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
        final SavedEstimate? estimate = args is SavedEstimate ? args : null;
        return MaterialPageRoute<void>(
          builder: (_) => EstimateScreen(initialEstimate: estimate),
          settings: settings,
        );
      case AppRoutes.savedEstimates:
        return MaterialPageRoute<void>(
          builder: (_) => const SavedEstimatesScreen(),
          settings: settings,
        );
      case AppRoutes.adminRequests:
        return MaterialPageRoute<void>(
          builder: (_) => const AdminRequestsScreen(),
          settings: settings,
        );
      case AppRoutes.windowSlopes:
        return MaterialPageRoute<void>(
          builder: (_) => const WindowSlopesScreen(),
          settings: settings,
        );
      case AppRoutes.productDetails:
        final CatalogItem? item = args is CatalogItem ? args : null;
        return MaterialPageRoute<void>(
          builder: (_) => ProductDetailsScreen(item: item),
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

  static Future<T?> pushPersonalData<T extends Object?>(
    BuildContext context, {
    PendingRegistration pending = const PendingRegistration(
      phone: '',
      smsCode: '',
    ),
  }) {
    return Navigator.pushNamed<T>(
      context,
      AppRoutes.personalData,
      arguments: pending,
    );
  }

  static Future<T?> pushPersonalDataConfirm<T extends Object?>(
    BuildContext context, {
    PendingRegistration pending = const PendingRegistration(
      phone: '',
      smsCode: '',
    ),
  }) {
    return Navigator.pushNamed<T>(
      context,
      AppRoutes.personalDataConfirm,
      arguments: pending,
    );
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

  static Future<T?> pushCatalogReplacing<T extends Object?>(
    BuildContext context,
  ) {
    return Navigator.pushNamedAndRemoveUntil<T>(
      context,
      AppRoutes.catalog,
      (_) => false,
    );
  }

  static Future<T?> pushSearch<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.search);
  }

  static Future<T?> pushMyData<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.myData);
  }

  static Future<T?> pushEstimate<T extends Object?>(
    BuildContext context, {
    SavedEstimate? estimate,
  }) {
    return Navigator.pushNamed<T>(
      context,
      AppRoutes.estimate,
      arguments: estimate,
    );
  }

  static Future<T?> pushSavedEstimates<T extends Object?>(
    BuildContext context,
  ) {
    return Navigator.pushNamed<T>(context, AppRoutes.savedEstimates);
  }

  static Future<T?> pushAdminRequests<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.adminRequests);
  }

  static Future<T?> pushWindowSlopes<T extends Object?>(BuildContext context) {
    return Navigator.pushNamed<T>(context, AppRoutes.windowSlopes);
  }

  static Future<T?> pushProductDetails<T extends Object?>(
    BuildContext context, {
    CatalogItem? item,
  }) {
    return Navigator.pushNamed<T>(
      context,
      AppRoutes.productDetails,
      arguments: item,
    );
  }

  static Future<T?> pushLoginReplacing<T extends Object?>(
    BuildContext context,
  ) async {
    await SessionService.clearToken();
    if (!context.mounted) {
      return null;
    }
    return Navigator.pushNamedAndRemoveUntil<T>(
      context,
      AppRoutes.login,
      (_) => false,
    );
  }
}
