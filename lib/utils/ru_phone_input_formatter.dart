import 'package:flutter/services.dart';

/// Маска: +7 (###) ###-##-## — только цифры после +7.
class RuPhoneInputFormatter extends TextInputFormatter {
  static const String _prefix = '+7 (';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    String national = digits;
    if (national.startsWith('8')) {
      national = national.substring(1);
    }
    if (national.startsWith('7')) {
      national = national.substring(1);
    }
    if (national.length > 10) {
      national = national.substring(0, 10);
    }

    if (national.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final StringBuffer buf = StringBuffer(_prefix);
    for (int i = 0; i < national.length; i++) {
      if (i == 3) {
        buf.write(') ');
      } else if (i == 6 || i == 8) {
        buf.write('-');
      }
      buf.write(national[i]);
    }

    final String text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
