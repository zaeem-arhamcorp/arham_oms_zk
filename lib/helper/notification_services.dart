import 'dart:io';

import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';

const String _androidChannelId = 'arham_oms_notifications_channel';
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
//
// // Top-Level Firebase Background Handler
// @pragma('vm:entry-point')
// Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   if (kDebugMode) {
//     print("Handling a background message: ${message.messageId}");
//     print("Background data block: ${message.data}");
//   }
// }

class NotificationService {
  // --- Singleton Pattern ---
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  // final FirebaseMessaging _fcm = FirebaseMessaging.instance; //FCM Instance
  final BehaviorSubject<String?> behaviorSubject = BehaviorSubject<String?>();

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
    //
    // // Initialize Firebase Cloud Messaging Configuration
    // await _initializeFirebaseMessaging();

    // --- Handle notification that launched the app ---
    await _processNotificationAppLaunchDetails();
  }
  //
  // Future<void> _initializeFirebaseMessaging() async {
  //   // Request system push authorizations
  //   NotificationSettings settings = await _fcm.requestPermission(
  //     alert: true,
  //     badge: true,
  //     sound: true,
  //   );
  //
  //   if (settings.authorizationStatus == AuthorizationStatus.authorized) {
  //     if (kDebugMode) print('[FCM] Push Permission Granted');
  //
  //     // // Auto-subscribe Master Admins to the required structural distribution topic
  //     // await _fcm.subscribeToTopic('master_admins');
  //     // if (kDebugMode) print('[FCM] Subscribed to topic: master_admins');
  //   }
  //
  //   // Connect top-level background trigger
  //   FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  //
  //   // Foreground listener: Fires local popups if administrators are in-app
  //   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  //     if (kDebugMode)
  //       print('[FCM] Message hit foreground: ${message.notification?.title}');
  //
  //     // Extract data map payload if present, serialize to string to match your streams
  //     String? payloadString;
  //     if (message.data.isNotEmpty) {
  //       payloadString = jsonEncode(message.data);
  //     }
  //
  //     // Automatically pop up a native system banner using your local notification channel configuration
  //     if (message.notification != null) {
  //       showLocalNotification(
  //         id: message.hashCode,
  //         title: message.notification!.title ?? '',
  //         body: message.notification!.body ?? '',
  //         payload: payloadString,
  //       );
  //     }
  //   });
  //
  //   // Background Interaction Stream: Fires if user taps notification banner while backgrounded
  //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  //     if (kDebugMode) print('[FCM] Notification clicked from background state');
  //     _handleRemotePayloadRouting(message.data);
  //   });
  // }
  //
  // /// Call this on app initialization OR immediately following a successful login callback.
  // /// Pass the current role string directly from your UserProvider.
  // Future<void> updateRoleBasedSubscription(
  //     String userRole, String masterRoleBenchmark) async {
  //   try {
  //     if (userRole == masterRoleBenchmark) {
  //       // Explicitly lock Master roles into the admin notifications channel
  //       await _fcm.subscribeToTopic('master_admins');
  //       if (kDebugMode)
  //         print(
  //             '[FCM] Target Role Matches Master. Subscribed to: master_admins');
  //     } else {
  //       // Safeguard: Ensure Operators are explicitly cleared out of this queue if roles switch on device
  //       await _fcm.unsubscribeFromTopic('master_admins');
  //       if (kDebugMode)
  //         print(
  //             '[FCM] Target Role is Operator. Unsubscribed from: master_admins');
  //     }
  //   } catch (e) {
  //     if (kDebugMode)
  //       print('[FCM] Failed to modify role subscription topic context: $e');
  //   }
  // }
  //
  // /// Call this during your authentication reset or application sign-out steps
  // Future<void> clearSubscriptionsOnLogout() async {
  //   try {
  //     await _fcm.unsubscribeFromTopic('master_admins');
  //     if (kDebugMode)
  //       print('[FCM] User Session Destroyed. Unsubscribed from: master_admins');
  //   } catch (e) {
  //     if (kDebugMode)
  //       print('[FCM] Error clearing logout subscription structures: $e');
  //   }
  // }

  Future<void> _processNotificationAppLaunchDetails() async {
    // Check if a local notification instance launched it
    final NotificationAppLaunchDetails? details =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      if (details.notificationResponse != null &&
          details.notificationResponse!.payload != null &&
          details.notificationResponse!.payload!.isNotEmpty) {
        await _openPayload(details.notificationResponse!.payload!);
      }
    }
    //
    // // Check if a Firebase Push instance launched it from a terminated state
    // RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    // if (initialMessage != null) {
    //   if (kDebugMode)
    //     print('[FCM] Application launched from terminated push state');
    //   _handleRemotePayloadRouting(initialMessage.data);
    // }
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
      _openPayload(payload);
    }
  }

  Future<void> _openPayload(String payload) async {
    behaviorSubject.add(payload);

    // Check if the payload is our JSON format from Firebase
    // try {
    //   if (payload.startsWith('{') && payload.endsWith('}')) {
    //     final Map<String, dynamic> data = jsonDecode(payload);
    //     _handleRemotePayloadRouting(data);
    //     return;
    //   }
    // } catch (e) {
    //   if (kDebugMode)
    //     print('Payload not parsed as JSON, treating as file layout: $e');
    // }
    //
    // // Fallback to file execution pattern if it's not custom telemetry routing data
    try {
      final result = await OpenFilex.open(payload);
      if (kDebugMode) {
        print('OpenFilex result: ${result.type}, message: ${result.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to open payload file: $e');
      }
    }
  }
  //
  // /// Core Navigation Engine for Processing Target Order Entry Direct Routing
  // void _handleRemotePayloadRouting(Map<String, dynamic> data) {
  //   if (kDebugMode) print('[ROUTING ENGINE] Evaluating parameters: $data');
  //
  //   if (data['type'] == 'new_order') {
  //     String? orderId = data['order_id'];
  //     if (orderId != null && orderId.isNotEmpty) {
  //       if (kDebugMode)
  //         print('[ROUTING ENGINE] Order triggered routing target: $orderId');
  //
  //       // Target Routing Pipeline Integration
  //       // Get.to(() => OrderDetailScreen(orderId: orderId));
  //
  //       // Visual validation notice for your mock testing session
  //       AppSnackBar.showGetXCustomSnackBar(
  //         message: 'Routing Successfully Triggered for Order ID: $orderId',
  //         backgroundColor: Colors.green,
  //       );
  //     }
  //   }
  // }

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
    if (Platform.isIOS) {
      // On iOS, request notification permission using flutter_local_notifications
      // to avoid compile-time permission_handler Podfile macro limitations.
      final bool? granted = await _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return granted ?? false;
    }

    PermissionStatus status;
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13 (TIRAMISU)
        status = await Permission.notification.request();
      } else {
        return true; // Older Android versions don't require explicit runtime permission for basic notifications
      }
    } else {
      return true; // Platform not requiring explicit permission (e.g., desktop, web - adjust as needed)
    }

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      AppSnackBar.showGetXCustomSnackBar(
        message:
            'Notification permission permanently denied. Please enable it from app settings.',
        backgroundColor: Colors.orange,
      );
      // Consider offering to open app settings:
      // await openAppSettings();
      return false;
    } else {
      // isDenied, isRestricted, isLimited
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Notification permission denied.',
        backgroundColor: Colors.red,
      );
      return false;
    }
  }
}
