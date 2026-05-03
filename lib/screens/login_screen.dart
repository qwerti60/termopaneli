import 'package:flutter/material.dart';
import 'package:termopaneli_app/auth/auth_flow.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/widgets/sms_phone_verification_panel.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SmsPhoneVerificationPanel(
            title: 'Авторизация',
            onCodeVerified: (String phone, String code) =>
                AuthFlow.completeSmsSignIn(
              context,
              normalizedPhone: phone,
              smsCode: code,
            ),
          ),
        ),
      ),
    );
  }
}
