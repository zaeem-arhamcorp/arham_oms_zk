import 'dart:convert';
import 'dart:io';

import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';

const String _androidChannelId = 'arham_corp_notifications_channel';
const String _androidChannelName = 'Arham Corp General Notifications';
const String _androidChannelDescription =
    'Channel for general notifications and updates from Arham Corporation.';

// This needs to be a top-level function or a static method.
@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponseCallback(
    NotificationResponse notificationResponse) {
  // IMPORTANT: Runs in a separate isolate. Avoid direct UI updates or complex app state manipulation.
  // Store the payload for processing when the app is next active.
  final String? payload = notificationResponse.payload;
  if (kDebugMode) {
    print('Background Notification Tapped. Payload: $payload');
  }
  // Example: Save to SharedPreferences
  // SharedPreferences prefs = await SharedPreferences.getInstance();
  // await prefs.setString('background_notification_payload', payload ?? '');
}

class NotificationService {
  // --- Singleton Pattern ---
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final BehaviorSubject<String?> behaviorSubject = BehaviorSubject<String?>();
  static const MethodChannel _iosNotificationChannel =
      MethodChannel('arham_oms/notification_debug');

  void _log(String message) {
    debugPrint('[NotificationService] $message');
  }

  Future<void> _logIosNotificationStatus(String stage) async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      final result = await _iosNotificationChannel.invokeMethod('getStatus');
      if (result is Map) {
        final normalized = <String, String>{};
        result.forEach((key, value) {
          normalized['$key'] = '$value';
        });
        _log('iOS status ($stage): ${jsonEncode(normalized)}');
      } else {
        _log('iOS status ($stage): unexpected response: $result');
      }
    } catch (e) {
      _log('iOS status ($stage) failed: $e');
    }
  }

  Future<void> _requestIosRemoteNotifications() async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      final result = await _iosNotificationChannel
          .invokeMethod('registerForRemoteNotifications');
      _log('iOS registerForRemoteNotifications result: $result');
    } catch (e) {
      _log('iOS registerForRemoteNotifications failed: $e');
    }
  }

  Future<void> initializePlatformNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
            '@mipmap/ic_launcher'); // Use your app icon

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      //onDidReceiveLocalNotification: _onDidReceiveLocalNotification, // For iOS < 10 foreground
      defaultPresentAlert: true,
      // For iOS 10+ foreground presentation
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin, // Can reuse Darwin settings
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponseCallback,
    );

    // --- Handle notification that launched the app ---
    await _processNotificationAppLaunchDetails();
  }

  Future<void> _processNotificationAppLaunchDetails() async {
    final NotificationAppLaunchDetails? details =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      if (details.notificationResponse != null &&
          details.notificationResponse!.payload != null &&
          details.notificationResponse!.payload!.isNotEmpty) {
        behaviorSubject.add(details.notificationResponse!.payload);
      }
    }
  }

  // Callback for iOS < 10 when app is in foreground
  // ignore: unused_element
  void _onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) {
    if (kDebugMode) {
      print(
          'Foreground notification received on OLDER iOS: id $id, title: $title, payload: $payload');
    }
    if (payload != null && payload.isNotEmpty) {
      behaviorSubject.add(payload);
    }
    // Optionally show an in-app banner/dialog for older iOS versions
  }

  // Callback for handling notification tap when app is in foreground/background (not terminated)
  void _onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (kDebugMode) {
      print(
          'Notification Tapped. Payload: $payload, Action ID: ${notificationResponse.actionId}');
    }
    if (payload != null && payload.isNotEmpty) {
      behaviorSubject.add(payload);
    }
  }

  Future<NotificationDetails> _notificationDetails() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.max,
      // Consider Importance.high if Max is too intrusive
      priority: Priority.high,
      playSound: true,
      ticker: 'ticker', // Less relevant on modern Android
    );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      threadIdentifier: "arham_corp_thread", // App-specific thread identifier
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinNotificationDetails,
      macOS: darwinNotificationDetails,
    );
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final platformChannelSpecifics = await _notificationDetails();
    await _localNotifications.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  void cancelAllNotifications() => _localNotifications.cancelAll();

  void cancelNotificationById(int id) => _localNotifications.cancel(id);

  Future<bool> requestNotificationPermission() async {
    PermissionStatus status;
    _log(
        'requestNotificationPermission start: platform=${Platform.operatingSystem}');
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      _log('Android SDK: ${androidInfo.version.sdkInt}');
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13 (TIRAMISU)
        status = await Permission.notification.request();
      } else {
        return true; // Older Android versions don't require explicit runtime permission for basic notifications
      }
    } else if (Platform.isIOS) {
      // For iOS, permission is typically requested during initialization.
      // This call will prompt if not yet determined, or return current status.
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      _log(
          'iOS device: model=${iosInfo.utsname.machine}, systemVersion=${iosInfo.systemVersion}');
      final beforeStatus = await Permission.notification.status;
      _log('iOS status before request: isGranted=${beforeStatus.isGranted}, '
          'isDenied=${beforeStatus.isDenied}, '
          'isPermanentlyDenied=${beforeStatus.isPermanentlyDenied}, '
          'isRestricted=${beforeStatus.isRestricted}, '
          'isLimited=${beforeStatus.isLimited}, '
          'isProvisional=${beforeStatus.isProvisional}');
      await _logIosNotificationStatus('before_request');
      _log('iOS requesting notification permission');
      status = await Permission.notification.request();
      final afterStatus = await Permission.notification.status;
      _log('iOS status after request: isGranted=${afterStatus.isGranted}, '
          'isDenied=${afterStatus.isDenied}, '
          'isPermanentlyDenied=${afterStatus.isPermanentlyDenied}, '
          'isRestricted=${afterStatus.isRestricted}, '
          'isLimited=${afterStatus.isLimited}, '
          'isProvisional=${afterStatus.isProvisional}');
      await _logIosNotificationStatus('after_request');
    } else {
      return true; // Platform not requiring explicit permission (e.g., desktop, web - adjust as needed)
    }

    _log(
      'permission result: '
      'isGranted=${status.isGranted}, '
      'isDenied=${status.isDenied}, '
      'isPermanentlyDenied=${status.isPermanentlyDenied}, '
      'isRestricted=${status.isRestricted}, '
      'isLimited=${status.isLimited}, '
      'isProvisional=${status.isProvisional}',
    );

    if (status.isGranted) {
      if (Platform.isIOS) {
        await _requestIosRemoteNotifications();
        await _logIosNotificationStatus('after_remote_register');
      }
      return true;
    } else if (status.isPermanentlyDenied) {
      _log('opening notification settings');
      AppSnackBar.showGetXCustomSnackBar(
        message:
            'Notification permission permanently denied. Please enable it from app settings.',
        backgroundColor: Colors.orange,
      );
      if (Platform.isIOS) {
        try {
          await AppSettings.openAppSettings(type: AppSettingsType.notification);
        } catch (_) {
          await openAppSettings();
        }
      } else {
        await openAppSettings();
      }
      return false;
    } else {
      // isDenied, isRestricted, isLimited
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Notification permission denied.',
        backgroundColor: Colors.red,
      );
      if (Platform.isIOS) {
        await _logIosNotificationStatus('denied');
      }
      return false;
    }
  }
}
