import 'package:flutter/services.dart';

class MoneyInputFormatter extends TextInputFormatter {
  static double parse(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    return (int.tryParse(digits) ?? 0) / 100;
  }

  static String format(double value) {
    final cents = (value * 100).round();
    final digits = cents.toString().padLeft(3, '0');
    final whole = digits.substring(0, digits.length - 2);
    final grouped = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return 'R\$ $grouped,${digits.substring(digits.length - 2)}';
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 11) return oldValue;
    final result = format((int.tryParse(digits) ?? 0) / 100);
    return TextEditingValue(text: result, selection: TextSelection.collapsed(offset: result.length));
  }
}
