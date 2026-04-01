// lib/utils/logger.dart
import 'package:flutter/foundation.dart';

/// ANSI color codes for console output (only visible in debug terminals)
class _LogColor {
  static const green = '\x1B[37m'; // ANSI code for white (default)
}

/// Global app logging helper.
/// Prints colorized logs in debug mode only.
/// Automatically disabled in release.
void appLog(
  String message, {
  String tag = 'APP',
  Object? error,
  StackTrace? stackTrace,
  String? color, // optional override
}) {
  if (kDebugMode) {
    final selectedColor = color ?? _LogColor.green; // default color
    final formatted = '$selectedColor[$tag] $message${_LogColor.green}';

    // For debug console
    // ignore: avoid_print
    print(formatted);
  }
}
