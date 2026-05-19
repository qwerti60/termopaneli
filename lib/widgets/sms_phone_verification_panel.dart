import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:termopaneli_app/config/api_config.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/services/auth_api_service.dart';
import 'package:termopaneli_app/services/smsc_service.dart';
import 'package:termopaneli_app/utils/ru_phone_input_formatter.dart';

typedef SmsVerifiedCallback =
    Future<void> Function(String normalizedPhone, String smsCode);

/// Телефон → «Прислать sms-код» → код → «Продолжить».
class SmsPhoneVerificationPanel extends StatefulWidget {
  const SmsPhoneVerificationPanel({
    super.key,
    required this.title,
    required this.onCodeVerified,
  });

  final String title;
  final SmsVerifiedCallback onCodeVerified;

  @override
  State<SmsPhoneVerificationPanel> createState() =>
      _SmsPhoneVerificationPanelState();
}

class _SmsPhoneVerificationPanelState extends State<SmsPhoneVerificationPanel> {
  static const int _resendCooldownSeconds = 60;
  static const int _maxWrongCodeAttempts = 3;

  final Random _random = Random();
  final GlobalKey<FormFieldState<String>> _phoneFieldKey =
      GlobalKey<FormFieldState<String>>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  bool _isSendingCode = false;

  /// Код из SMS, если отправка только через SmscService (без PHP).
  String? _sentCode;

  /// OTP запрошен через `request-sms.php`, проверка только на сервере.
  bool _otpViaServer = false;
  String? _lastNormalizedPhone;
  int _wrongCodeAttempts = 0;
  int _secondsUntilResend = 0;
  Timer? _resendTimer;

  String? _normalizePhone(String value) {
    final String digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 &&
        (digits.startsWith('7') || digits.startsWith('8'))) {
      return '7${digits.substring(1)}';
    }
    if (digits.length == 10) {
      return '7$digits';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите номер телефона';
    }
    final String digits = value.replaceAll(RegExp(r'\D'), '');
    // Пока набирают меньше 9 цифр — не показываем «некорректный номер», чтобы не мешать вводу.
    if (digits.length < 9) {
      return null;
    }
    if (_normalizePhone(value) == null) {
      return 'Введите корректный номер РФ';
    }
    return null;
  }

  void _onPhoneChanged() {
    final String? normalized = _normalizePhone(_phoneController.text);
    if (normalized != _lastNormalizedPhone) {
      _lastNormalizedPhone = normalized;
      setState(() {
        _sentCode = null;
        _otpViaServer = false;
        _wrongCodeAttempts = 0;
        _codeController.clear();
      });
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _secondsUntilResend = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsUntilResend <= 1) {
        t.cancel();
        setState(() => _secondsUntilResend = 0);
        return;
      }
      setState(() => _secondsUntilResend--);
    });
  }

  Future<void> _requestSmsCode() async {
    if (_secondsUntilResend > 0 || _isSendingCode) {
      return;
    }

    if (_phoneFieldKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _isSendingCode = true);

    final String normalizedPhone = _normalizePhone(_phoneController.text)!;
    final String devStaticOtpCode = ApiConfig.devStaticOtpCode.trim();

    if (devStaticOtpCode.isNotEmpty) {
      setState(() {
        _isSendingCode = false;
        _otpViaServer = true;
        _sentCode = null;
        _wrongCodeAttempts = 0;
        _codeController.clear();
        _startResendCooldown();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Получение SMS временно отключено. Используйте код $devStaticOtpCode',
          ),
        ),
      );
      return;
    }

    if (ApiConfig.baseUrl.trim().isNotEmpty) {
      final ({bool ok, String? errorMessage}) smsResult =
          await AuthApiService.requestSms(phone: normalizedPhone);

      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingCode = false;
        if (smsResult.ok) {
          _otpViaServer = true;
          _sentCode = null;
          _wrongCodeAttempts = 0;
          _codeController.clear();
          _startResendCooldown();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            smsResult.ok
                ? 'Код отправлен на $normalizedPhone'
                : (smsResult.errorMessage ?? 'Ошибка отправки SMS'),
          ),
        ),
      );
      return;
    }

    final String code = (100000 + _random.nextInt(900000)).toString();

    final SmsSendResult result = await SmscService.sendCode(
      phone: normalizedPhone,
      code: code,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSendingCode = false;
      if (result.isSuccess) {
        _otpViaServer = false;
        _sentCode = code;
        _wrongCodeAttempts = 0;
        _codeController.clear();
        _startResendCooldown();
      }
    });

    final String message = result.isSuccess
        ? 'Код отправлен на $normalizedPhone'
        : (result.errorMessage ?? 'Ошибка отправки SMS');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    final bool hasRequestedCode = _otpViaServer || _sentCode != null;
    if (!hasRequestedCode) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сначала получите SMS-код')));
      return;
    }
    if (!_otpViaServer && _wrongCodeAttempts >= _maxWrongCodeAttempts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запросите новый код по SMS')),
      );
      return;
    }

    final String code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите код из SMS')));
      return;
    }

    final String? normalized = _normalizePhone(_phoneController.text);
    if (normalized == null) {
      return;
    }

    if (!_otpViaServer) {
      if (code != _sentCode) {
        setState(() => _wrongCodeAttempts++);
        final int left = _maxWrongCodeAttempts - _wrongCodeAttempts;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              left > 0
                  ? 'Неверный код. Осталось попыток: $left'
                  : 'Превышен лимит попыток. Запросите новый код.',
            ),
          ),
        );
        return;
      }
    }

    try {
      await widget.onCodeVerified(normalized, code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _lastNormalizedPhone = _normalizePhone(_phoneController.text);
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String _resendButtonLabel() {
    if (_isSendingCode) {
      return 'Отправка...';
    }
    if (_secondsUntilResend > 0) {
      return 'Повторить через $_secondsUntilResend с';
    }
    return 'Прислать sms-код';
  }

  @override
  Widget build(BuildContext context) {
    final bool resendBlocked = _isSendingCode || _secondsUntilResend > 0;
    final bool continueBlocked =
        !_otpViaServer && _wrongCodeAttempts >= _maxWrongCodeAttempts;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: AppTextTheme.sectionTitleBold,
        ),
        const SizedBox(height: 24),
        TextFormField(
          key: _phoneFieldKey,
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          inputFormatters: <TextInputFormatter>[RuPhoneInputFormatter()],
          validator: _phoneValidator,
          decoration: const InputDecoration(
            hintText: '+7 (999) 888-77-66',
            hintStyle: AppTextTheme.hint32,
            isCollapsed: true,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            filled: true,
            fillColor: AppColors.inputBackground,
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: resendBlocked ? null : _requestSmsCode,
          style: TextButton.styleFrom(
            fixedSize: const Size(double.infinity, 33),
            padding: EdgeInsets.zero,
            alignment: Alignment.center,
            foregroundColor: AppColors.primaryButtonText,
            backgroundColor: AppColors.primaryButtonBackground,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
          child: Text(
            _resendButtonLabel(),
            textAlign: TextAlign.center,
            style: AppTextTheme.buttonLabel,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          buildCounter:
              (
                BuildContext context, {
                required int currentLength,
                required bool isFocused,
                required int? maxLength,
              }) => const SizedBox.shrink(),
          decoration: const InputDecoration(
            hintText: 'Код',
            hintStyle: AppTextTheme.hint32,
            isCollapsed: true,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            filled: true,
            fillColor: AppColors.inputBackground,
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ),
        const SizedBox(height: 34),
        TextButton(
          onPressed: continueBlocked ? null : () => _continue(),
          style: TextButton.styleFrom(
            fixedSize: const Size(double.infinity, 33),
            padding: EdgeInsets.zero,
            alignment: Alignment.center,
            foregroundColor: AppColors.primaryButtonText,
            backgroundColor: AppColors.primaryButtonBackground,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
          child: const Text(
            'Продолжить',
            textAlign: TextAlign.center,
            style: AppTextTheme.buttonLabel,
          ),
        ),
      ],
    );
  }
}
