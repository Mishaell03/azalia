import 'package:flutter/services.dart';

class AppProfilePhone extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    String cleaned = text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length > 11) {
      cleaned = cleaned.substring(0, 11);
    }

    String formatted = '';
    if (cleaned.isNotEmpty) {
      formatted = '+7';
      if (cleaned.length > 1)
        formatted +=
            ' (${cleaned.substring(1, cleaned.length > 4 ? 4 : cleaned.length)}';
      if (cleaned.length > 4)
        formatted +=
            ') ${cleaned.substring(4, cleaned.length > 7 ? 7 : cleaned.length)}';
      if (cleaned.length > 7)
        formatted +=
            '-${cleaned.substring(7, cleaned.length > 9 ? 9 : cleaned.length)}';
      if (cleaned.length > 9) formatted += '-${cleaned.substring(9)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}