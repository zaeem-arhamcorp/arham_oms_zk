// lib/utils/logger.dart
import 'package:flutter/foundation.dart';

/// Global app logging helper.
/// Prints plain logs in debug mode only.
/// Automatically disabled in release.
void appLog(
  String message, {
  String tag = 'APP',
  Object? error,
  StackTrace? stackTrace,
  String? color,
}) {
  if (kDebugMode) {
    // For debug console
    // ignore: avoid_print
    print('[$tag] $message');
  }
}
