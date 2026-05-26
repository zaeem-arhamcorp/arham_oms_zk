import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class CrashlyticsService {
  static FirebaseCrashlytics? get _crashlytics {
    try {
      if (Firebase.apps.isNotEmpty) return FirebaseCrashlytics.instance;
    } catch (_) {}
    return null;
  }

  static final DateFormat _timestampFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  static String _safeString(Object? value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return lower.contains('token') ||
        lower.contains('password') ||
        lower.contains('secret') ||
        lower.contains('auth');
  }

  static Future<void> _setSafeKey(String key, Object? value) async {
    if (_isSensitiveKey(key)) return;
    final c = _crashlytics;
    if (c == null) return;
    await c.setCustomKey(key, _safeString(value));
  }

  static Future<void> setScreenName(String screenName) async {
    final safeScreenName = _safeString(screenName);
    if (safeScreenName.isEmpty) return;

    await _setSafeKey('screen_name', safeScreenName);
    final c = _crashlytics;
    if (c == null) return;
    await c.log('screen:$safeScreenName');
  }

  static Future<void> setUserContext({
    required String userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    String? userRole,
  }) async {
    final safeUserId =
        _safeString(userId).isEmpty ? 'unknown' : _safeString(userId);

    final c = _crashlytics;
    if (c == null) return;
    await c.setUserIdentifier(safeUserId);
    await _setSafeKey('user_id', safeUserId);
    await _setSafeKey('user_name', _safeString(userName));
    await _setSafeKey('user_email', _safeString(userEmail));
    await _setSafeKey('user_phone', _safeString(userPhone));
    await _setSafeKey('user_role', _safeString(userRole));
    await _crashlytics?.log('user_context_updated');
  }

  static Future<void> logAction(
    String action, {
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    final safeAction = _safeString(action);
    if (safeAction.isEmpty) return;

    final parts = <String>[];
    for (final entry in context.entries) {
      if (_isSensitiveKey(entry.key)) continue;
      final value = _safeString(entry.value);
      if (value.isEmpty) continue;
      parts.add('${entry.key}=$value');
      if (parts.length >= 4) break;
    }

    final suffix = parts.isEmpty ? '' : ' [${parts.join(', ')}]';
    final c = _crashlytics;
    if (c == null) return;
    await c.log('action:$safeAction$suffix');
  }

  static Future<void> setCrashTimeNow() async {
    await _setSafeKey('crash_time', _timestampFormat.format(DateTime.now()));
  }

  static Future<void> recordNonFatal(
    Object error,
    StackTrace stack, {
    String reason = 'non_fatal_error',
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    await setCrashTimeNow();
    await _setSafeKey('error_reason', reason);

    for (final entry in context.entries) {
      if (_isSensitiveKey(entry.key)) continue;
      await _setSafeKey('ctx_${entry.key}', entry.value);
    }

    final c = _crashlytics;
    if (c == null) return;
    await c.recordError(
      error,
      stack,
      fatal: false,
      reason: reason,
      printDetails: kDebugMode,
    );
  }

  static Future<void> recordFatal(
    Object error,
    StackTrace stack, {
    String reason = 'fatal_error',
  }) async {
    await setCrashTimeNow();
    await _setSafeKey('error_reason', reason);
    final c = _crashlytics;
    if (c == null) return;
    await c.recordError(
      error,
      stack,
      fatal: true,
      reason: reason,
      printDetails: kDebugMode,
    );
  }

  static Future<void> recordFlutterFatal(
    FlutterErrorDetails details, {
    String reason = 'flutter_framework_error',
  }) async {
    await setCrashTimeNow();
    await _setSafeKey('error_reason', reason);
    final c = _crashlytics;
    if (c == null) return;
    await c.recordFlutterFatalError(details);
  }
}
