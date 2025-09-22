import 'dart:developer' as dev;

class Log {
  static void d(String msg) => dev.log(msg, level: 500, name: 'QuickFix');
  static void e(String msg, [Object? err, StackTrace? st]) =>
      dev.log(msg, level: 1000, name: 'QuickFix', error: err, stackTrace: st);
  static void i(String msg) => dev.log(msg, level: 800, name: 'QuickFix');
  static void w(String msg) => dev.log(msg, level: 900, name: 'QuickFix');
}
