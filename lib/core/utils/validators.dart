import 'package:quickfix/core/constants/strings.dart';

class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return Strings.emailRequired;
    }

    final emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    );

    if (!emailRegExp.hasMatch(value)) {
      return Strings.emailInvalid;
    }

    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return Strings.passwordRequired;
    }

    if (value.length < 6) {
      return Strings.passwordTooShort;
    }

    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return Strings.phoneRequired;
    }

    // Normalize: keep digits only
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');

    // Reject obviously invalid patterns (e.g., all same digit)
    if (RegExp(r'^(\d)\1{9,}$').hasMatch(digitsOnly)) {
      return Strings.phoneInvalid;
    }

    // US-friendly rules:
    // - Allow 10 digits (national) or 11 with leading country code '1'
    // - If 11 digits, first must be '1'
    if (digitsOnly.length == 10) {
      return null;
    }
    if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
      return null;
    }

    return Strings.phoneInvalid;
  }

  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return Strings.nameRequired;
    }

    if (value.length < 2) {
      return Strings.nameTooShort;
    }

    return null;
  }

  static bool isValidPhoneNumber(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (RegExp(r'^(\d)\1{9,}$').hasMatch(digitsOnly)) return false;
    if (digitsOnly.length == 10) return true; // US national
    if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) return true; // +1
    return false;
  }

  static String formatPhoneNumber(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    String normalized = digitsOnly;
    if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
      normalized = digitsOnly.substring(1);
    }
    if (normalized.length == 10) {
      final area = normalized.substring(0, 3);
      final prefix = normalized.substring(3, 6);
      final line = normalized.substring(6);
      return '($area) $prefix-$line';
    }
    return phone.trim();
  }
}
