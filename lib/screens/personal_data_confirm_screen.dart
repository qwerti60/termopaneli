import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:termopaneli_app/auth/pending_registration.dart';
import 'package:termopaneli_app/config/legal_urls.dart';
import 'package:termopaneli_app/design/app_colors.dart';
import 'package:termopaneli_app/design/app_text_theme.dart';
import 'package:termopaneli_app/routes/routes.dart';
import 'package:termopaneli_app/services/auth_api_service.dart';
import 'package:termopaneli_app/services/session_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PersonalDataConfirmScreen extends StatefulWidget {
  const PersonalDataConfirmScreen({
    super.key,
    required this.pending,
  });

  final PendingRegistration pending;

  @override
  State<PersonalDataConfirmScreen> createState() =>
      _PersonalDataConfirmScreenState();
}

class _PersonalDataConfirmScreenState extends State<PersonalDataConfirmScreen> {
  static final Uri _telegramChannelUri = Uri.parse('https://t.me/facade_panel');
  bool _isSaving = false;
  bool _agreementAccepted = false;
  late final TapGestureRecognizer _agreementLinkTap;

  @override
  void initState() {
    super.initState();
    _agreementLinkTap = TapGestureRecognizer()..onTap = _openUserAgreement;
  }

  @override
  void dispose() {
    _agreementLinkTap.dispose();
    super.dispose();
  }

  Future<void> _openUserAgreement() async {
    await launchUrl(
      await LegalUrls.userAgreementResolved(),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<bool> _openTelegramChannel() {
    return launchUrl(
      _telegramChannelUri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<bool> _showTelegramSubscribeDialog() async {
    bool confirmed = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Подписка на канал'),
          content: const Text(
            'Для завершения регистрации подпишитесь на Telegram-канал facade_panel.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final bool opened = await _openTelegramChannel();
                if (!mounted) {
                  return;
                }
                if (!opened) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Не удалось открыть Telegram-канал')),
                  );
                }
              },
              child: const Text('Перейти в канал'),
            ),
            TextButton(
              onPressed: () {
                confirmed = true;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Я подписался'),
            ),
          ],
        );
      },
    );
    return confirmed;
  }

  Future<void> _showContinueDialog() async {
    if (!_agreementAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Примите пользовательское соглашение')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Подтверждение'),
          content: const Text('Сохранить введенные данные и продолжить?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _completeRegistration();
              },
              child: const Text('Далее'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeRegistration() async {
    if (_isSaving) {
      return;
    }
    final pending = widget.pending;
    if (pending.phone.isEmpty || pending.smsCode.isEmpty) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.catalog, (_) => false);
      return;
    }
    setState(() => _isSaving = true);
    final RegisterResult res = await AuthApiService.registerNewUser(
      phone: pending.phone,
      code: pending.smsCode,
      lastName: pending.lastName,
      firstName: pending.firstName,
      middleName: pending.middleName,
      email: pending.email,
      acceptedUserAgreement: _agreementAccepted,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    if (!res.ok || res.token == null || res.token!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.errorMessage ?? 'Не удалось завершить регистрацию')),
      );
      return;
    }
    await SessionService.saveToken(res.token!);
    final bool subscribed = await _showTelegramSubscribeDialog();
    if (!subscribed) {
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.catalog, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Проверьте данные',
                textAlign: TextAlign.center,
                style: AppTextTheme.sectionTitleBold,
              ),
              const SizedBox(height: 24),
              _ReadOnlyField(
                label: 'Телефон',
                value: widget.pending.phone,
              ),
              const SizedBox(height: 12),
              _ReadOnlyField(
                label: 'Фамилия',
                value: widget.pending.lastName,
              ),
              const SizedBox(height: 12),
              _ReadOnlyField(
                label: 'Имя',
                value: widget.pending.firstName,
              ),
              const SizedBox(height: 12),
              _ReadOnlyField(
                label: 'Отчество',
                value: widget.pending.middleName,
              ),
              const SizedBox(height: 12),
              _ReadOnlyField(
                label: 'Эл. почта',
                value: widget.pending.email,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreementAccepted,
                    onChanged: _isSaving
                        ? null
                        : (bool? v) {
                            setState(() => _agreementAccepted = v ?? false);
                          },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: RichText(
                        text: TextSpan(
                          style: AppTextTheme.body32,
                          children: <InlineSpan>[
                            const TextSpan(text: 'Я принимаю '),
                            TextSpan(
                              text: 'пользовательское соглашение',
                              style: AppTextTheme.body32.copyWith(
                                color: AppColors.primaryButtonBackground,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: _agreementLinkTap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: (_isSaving || !_agreementAccepted)
                    ? null
                    : _showContinueDialog,
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
                  _isSaving ? 'Сохранение...' : 'Продолжить',
                  textAlign: TextAlign.center,
                  style: AppTextTheme.buttonLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: RichText(
        text: TextSpan(
          style: AppTextTheme.body32,
          children: <InlineSpan>[
            TextSpan(text: '$label: '),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
