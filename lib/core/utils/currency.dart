import 'package:intl/intl.dart';

class Currency {
  static final NumberFormat usd =
      NumberFormat.simpleCurrency(locale: 'en_US', name: 'USD');

  static String formatUsd(num amount) {
    final double value = (amount is double) ? amount : amount.toDouble();
    // Ensure two decimal places and proper symbol
    return usd.format(double.parse(value.toStringAsFixed(2)));
  }
}


