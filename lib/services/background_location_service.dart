import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'package:arham_corporation/helper/network_helper.dart';
import 'package:http/http.dart' as http;
import 'package:arham_corporation/config/app_config.dart';

/// Background Location Tracking Service
/// Captures GPS location every 40 seconds during active punch-in.
/// Stores locations locally in SQLite and syncs periodically when internet is available.
/// Continues running even when app is minimized or cleared from recent apps.
@pragma('vm:entry-point')
class BackgroundLocationService {
  static final BackgroundLocationService _instance =
      BackgroundLocationService._internal();

  factory BackgroundLocationService() => _instance;

  BackgroundLocationService._internal();

  final DatabaseHelper _db = DatabaseHelper();
  final FlutterBackgroundService _service = FlutterBackgroundService();
  static const Duration _captureInterval = Duration(seconds: 40);
  static const platform = MethodChannel('com.arhamerp.app/notification');
  static const trackingControlPlatform =
      MethodChannel('com.arhamerp.app/tracking_control');

  bool _isRunning = false;
  String? _currentUserCd;
  int? _currentSyncId;
  String? _token;
  int? _currentTripId;

  /// Check if background service is currently running
  bool get isRunning => _isRunning;

  String? get currentUserCd => _currentUserCd;

  int? get currentSyncId => _currentSyncId;

  int? get currentTripId => _currentTripId;

  static String _formatDateTimeForApi(int timestampMs) {
    // Use UTC with explicit timezone marker to avoid server-side timezone ambiguity.
    return DateTime.fromMillisecondsSinceEpoch(timestampMs)
        .toUtc()
        .toIso8601String();
  }

  /// Check if the app has "Allow all the time" location permission
  /// Required for background location tracking to work
  Future<bool> hasBackgroundLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();

      print('[BackgroundLocationService] Checking location permission...');
      print('[BackgroundLocationService]   Permission status: $permission');

      // Only LocationPermission.always is valid for background tracking
      if (permission == LocationPermission.always) {
        print(
            '[BackgroundLocationService] ✅ "Allow all the time" permission granted');
        return true;
      } else {
        print(
            '[BackgroundLocationService] ❌ Permission is: $permission (needs "Always")');
        return false;
      }
    } catch (e) {
      print('[BackgroundLocationService] ⚠️ Error checking permission: $e');
      return false;
    }
  }

  /// Initialize background location service
  /// Should be called once during app startup
  Future<void> initialize() async {
    try {
      print('[BackgroundLocationService] Initializing background service...');

      // Configure the background service callback
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          // this will be executed when app is in foreground
          onStart: _onStart,
          // onIosConfiguration to inform ios app that you learned more about background service by installing flutter_background_service_ios package
          isForegroundMode: true,
          autoStart: false,
          autoStartOnBoot: false,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
          onBackground: _onIosBackground,
        ),
      );

      print('[BackgroundLocationService] ✅ Background service initialized');
    } catch (e) {
      print('[BackgroundLocationService] ❌ Error initializing: $e');
    }
  }

  /// Set foreground service notification as ongoing (non-dismissible)
  /// This prevents users from accidentally swiping away the location tracking notification
  Future<void> setNotificationOngoing({
    String title = 'Location Tracking Active',
    String message = 'Background location tracking is active',
  }) async {
    try {
      print(
          '[BackgroundLocationService] 📌 Setting notification as ongoing...');
      await platform.invokeMethod('setNotificationOngoing', {
        'notificationId':
            888, // Use flutter_background_service plugin's notification ID
        'title': title,
        'message': message,
      });
      print(
          '[BackgroundLocationService] ✅ Notification set as ongoing (non-dismissible)');
    } catch (e) {
      print(
          '[BackgroundLocationService] ⚠️ Error setting notification ongoing: $e');
    }
  }

  /// Start background location tracking service and initialize trip on server
  /// Should be called after successful punch-in
  /// Parameters:
  /// - userCd: Employee code
  /// - syncId: Organization ID
  /// - token: API authentication token
  /// - startLat: Punch-in latitude
  /// - startLng: Punch-in longitude
  /// Returns: {success: bool, trip_id: int, message: string, error?: string}
  Future<Map<String, dynamic>> startTracking({
    required String userCd,
    required int syncId,
    required String token,
    required double startLat,
    required double startLng,
  }) async {
    try {
      print('[BackgroundLocationService] 🚀 Starting background tracking...');
      print('[BackgroundLocationService]   User: $userCd');
      print('[BackgroundLocationService]   Sync ID: $syncId');

      // Verify permissions. Background tracking requires "always" permission.
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[BackgroundLocationService] ❌ Location permission denied');
          return {
            'success': false,
            'message': 'Location permission denied',
            'error': 'Permission not granted',
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print(
            '[BackgroundLocationService] ❌ Location permission permanently denied');
        return {
          'success': false,
          'message': 'Location permission permanently denied',
          'error': 'Permission not granted',
        };
      }

      if (permission == LocationPermission.whileInUse) {
        print(
            '[BackgroundLocationService] ❌ Background location needs "Allow all the time" permission');
        return {
          'success': false,
          'message':
              'Please enable "Allow all the time" location permission for route tracking.',
          'error': 'Background location permission not granted',
        };
      }

      print('[BackgroundLocationService] ✅ Location permissions granted');

      // Step 1: Call /api/location/trip/start to initialize trip on server
      print('[BackgroundLocationService] 📤 Initiating trip on server...');
      print(
          '[BackgroundLocationService]   API URL: ${AppConfig.baseURL}location/trip/start');
      print(
          '[BackgroundLocationService]   Send data: syncId=$syncId, startLat=$startLat, startLng=$startLng');
      try {
        print(
            '[BackgroundLocationService] API HIT: ${AppConfig.baseURL}location/trip/start');
        final tripStartResponse = await http.post(
          Uri.parse('${AppConfig.baseURL}location/trip/start'),
          headers: {
            'Authorization': 'Bearer $token',
            'x-app-type': 'oms',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'sync_id': syncId.toString(),
            'start_lat': startLat.toString(),
            'start_lng': startLng.toString(),
          }),
        );

        print('[BackgroundLocationService] ✅ Trip start response received');
        print(
            '[BackgroundLocationService]   HTTP Status: ${tripStartResponse.statusCode}');
        print(
            '[BackgroundLocationService]   Response Body: ${tripStartResponse.body}');

        if (tripStartResponse.statusCode != 200 &&
            tripStartResponse.statusCode != 201) {
          print(
              '[BackgroundLocationService] ❌ Trip start failed: ${tripStartResponse.statusCode}');
          print(
              '[BackgroundLocationService]   Response: ${tripStartResponse.body}');
          return {
            'success': false,
            'message': 'Failed to initialize trip on server',
            'error': 'Server error: ${tripStartResponse.statusCode}',
          };
        }

        // Parse trip_id from response
        int tripId = 0;
        try {
          // Assuming response has trip_id field
          final responseData = tripStartResponse.body;
          if (responseData.contains('trip_id')) {
            // Extract trip_id from response
            final match =
                RegExp(r'\"trip_id\"\s*:\s*(\d+)').firstMatch(responseData);
            if (match != null) {
              tripId = int.parse(match.group(1)!);
            }
          }
        } catch (e) {
          print('[BackgroundLocationService] ⚠️ Could not parse trip_id: $e');
        }

        if (tripId <= 0) {
          print('[BackgroundLocationService] ❌ Invalid trip_id received');
          return {
            'success': false,
            'message': 'Server did not return valid trip_id',
            'error': 'Invalid trip_id',
          };
        }

        print('[BackgroundLocationService] ✅ Trip created: trip_id=$tripId');

        // Store user info for the service in MEMORY
        _currentUserCd = userCd;
        _currentSyncId = syncId;
        _token = token;
        _currentTripId = tripId;
        _isRunning = true;

        // ALSO STORE IN PERSISTENT STORAGE in case app is backgrounded
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('active_trip_id', tripId);
          await prefs.setString('active_user_cd', userCd);
          await prefs.setInt('active_sync_id', syncId);
          await prefs.setString('active_token', token);
          print(
              '[BackgroundLocationService] ✅ Trip data saved to SharedPreferences');
        } catch (e) {
          print(
              '[BackgroundLocationService] ⚠️ Could not save to SharedPreferences: $e');
        }

        // Start the background service
        await _service.startService();

        // Start native watchdog for extra recovery after app swipe/kill.
        try {
          await trackingControlPlatform
              .invokeMethod('startTrackingRecoveryWatchdog');
          print(
              '[BackgroundLocationService] ✅ Native tracking recovery watchdog enabled');
        } catch (e) {
          print(
              '[BackgroundLocationService] ⚠️ Could not enable native recovery watchdog: $e');
        }

        // Give the service a moment to fully initialize before updating notification
        await Future.delayed(const Duration(milliseconds: 500));

        // Set the notification as non-dismissible (non-swipeable)
        await setNotificationOngoing(
          title: 'Route Tracking Active',
          message:
              'Your location is being tracked during this route. Please DO NOT remove the app from background',
        );

        // Send initial configuration to the service
        _service.invoke('startLocationTracking', {
          'userCd': userCd,
          'syncId': syncId,
          'token': token,
          'tripId': tripId,
        });

        print('[BackgroundLocationService] ✅ Background tracking started');
        return {
          'success': true,
          'trip_id': tripId,
          'message': 'Tracking started successfully',
        };
      } catch (e) {
        print('[BackgroundLocationService] ❌ Error starting trip: $e');
        return {
          'success': false,
          'message': 'Failed to start trip',
          'error': e.toString(),
        };
      }
    } catch (e) {
      print('[BackgroundLocationService] ❌ Error starting tracking: $e');
      _isRunning = false;
      return {
        'success': false,
        'message': 'Failed to start tracking',
        'error': e.toString(),
      };
    }
  }

  /// Resume background tracking for an already active trip persisted locally.
  /// This is used by WorkManager after app process is killed.
  Future<bool> resumeTrackingIfActiveTrip() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final tripId = prefs.getInt('active_trip_id');
      final userCd = prefs.getString('active_user_cd');
      final syncId = prefs.getInt('active_sync_id');
      final token = prefs.getString('active_token');

      if (tripId == null || userCd == null || syncId == null || token == null) {
        print(
            '[BackgroundLocationService] No active trip in SharedPreferences. Skipping resume.');
        return false;
      }

      _currentTripId = tripId;
      _currentUserCd = userCd;
      _currentSyncId = syncId;
      _token = token;

      bool serviceRunning = false;
      try {
        serviceRunning = await _service.isRunning();
      } catch (e) {
        print(
            '[BackgroundLocationService] Could not check service running state: $e');
      }

      if (!serviceRunning) {
        print(
            '[BackgroundLocationService] Recovering tracking service for active trip_id=$tripId');
        await _service.startService();

        // Give the plugin a brief moment to spin up the foreground isolate.
        await Future.delayed(const Duration(milliseconds: 700));

        bool startedAfterRecovery = false;
        try {
          startedAfterRecovery = await _service.isRunning();
        } catch (e) {
          print(
              '[BackgroundLocationService] Could not verify service state after recovery start: $e');
        }

        if (!startedAfterRecovery) {
          print(
              '[BackgroundLocationService] ⚠️ Recovery start requested but service is still not running');
        }

        // Set the notification as non-dismissible when recovering
        await setNotificationOngoing(
          title: 'Route Tracking Resumed',
          message: 'Your location is being tracked during this route',
        );

        _service.invoke('startLocationTracking', {
          'userCd': userCd,
          'syncId': syncId,
          'token': token,
          'tripId': tripId,
        });
      } else {
        print(
            '[BackgroundLocationService] Background service already running. Resume not required. ');
      }

      _isRunning = true;
      return true;
    } catch (e) {
      print('[BackgroundLocationService] Error while resuming active trip: $e');
      return false;
    }
  }

  /// Stop background location tracking service.
  /// By default also ends the trip on server; can be skipped for punch-out flow
  /// so pending points sync before trip end.
  Future<void> stopTracking({bool endTripOnServer = true}) async {
    try {
      print('[BackgroundLocationService] 🛑 Stopping background tracking...');

      // Signal the service to stop (tracking loop will exit)
      _service.invoke('stopLocationTracking');

      // Disable native watchdog so it does not restart tracking after punch-out.
      try {
        await trackingControlPlatform
            .invokeMethod('stopTrackingRecoveryWatchdog');
        print('[BackgroundLocationService] ✅ Native recovery watchdog disabled');
      } catch (e) {
        print(
            '[BackgroundLocationService] ⚠️ Could not disable native recovery watchdog: $e');
      }

      // Wait a moment for the service to stop
      await Future.delayed(Duration(milliseconds: 500));
      print('[BackgroundLocationService] ✅ Foreground service stopping...');

      // Try to get trip_id and token from memory first, then SharedPreferences
      int? tripIdToUse = _currentTripId;
      String? tokenToUse = _token;

      if (tripIdToUse == null || tokenToUse == null) {
        print(
            '[BackgroundLocationService] ⚠️ Trip data not in memory, checking SharedPreferences...');
        try {
          final prefs = await SharedPreferences.getInstance();
          tripIdToUse = prefs.getInt('active_trip_id');
          tokenToUse = prefs.getString('active_token');
          if (tripIdToUse != null && tokenToUse != null) {
            print(
                '[BackgroundLocationService] ✅ Retrieved trip data from SharedPreferences');
            print('[BackgroundLocationService]   trip_id=$tripIdToUse');
          }
        } catch (e) {
          print(
              '[BackgroundLocationService] ⚠️ Could not retrieve from SharedPreferences: $e');
        }
      }

      // End trip on server if requested and if we have trip_id+token
      if (endTripOnServer && tripIdToUse != null && tokenToUse != null) {
        print(
            '[BackgroundLocationService] 📤 Ending trip on server (trip_id=$tripIdToUse)...');
        try {
          print(
              '[BackgroundLocationService] API HIT: ${AppConfig.baseURL}location/trip/end');
          final tripEndResponse = await http.post(
            Uri.parse('${AppConfig.baseURL}location/trip/end'),
            headers: {
              'Authorization': 'Bearer $tokenToUse',
              'x-app-type': 'oms',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'trip_id': tripIdToUse,
            }),
          );

          if (tripEndResponse.statusCode == 200 ||
              tripEndResponse.statusCode == 201) {
            print(
                '[BackgroundLocationService] ✅ Trip ended successfully on server');
            // Clear SharedPreferences after successful end
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('active_trip_id');
              await prefs.remove('active_user_cd');
              await prefs.remove('active_sync_id');
              await prefs.remove('active_token');
              print(
                  '[BackgroundLocationService] ✅ Cleared trip data from SharedPreferences');
            } catch (e) {
              print(
                  '[BackgroundLocationService] ⚠️ Could not clear SharedPreferences: $e');
            }
          } else {
            print(
                '[BackgroundLocationService] ⚠️ Trip end failed: ${tripEndResponse.statusCode}');
          }
        } catch (e) {
          print('[BackgroundLocationService] ⚠️ Error ending trip: $e');
        }
      } else if (endTripOnServer) {
        print(
            '[BackgroundLocationService] ⚠️ Missing trip_id or token - cannot end trip on server');
      } else {
        print(
            '[BackgroundLocationService] ℹ️ Trip end skipped now. Caller will end trip after pending sync.');
      }

      _isRunning = false;
      _currentUserCd = null;
      _currentSyncId = null;
      _token = null;
      _currentTripId = null;

      print(
          '[BackgroundLocationService] ✅ Background tracking completely stopped');
      print('[BackgroundLocationService]    - Tracking loop exited');
      print('[BackgroundLocationService]    - Service notification will clear');
      print(
          '[BackgroundLocationService]    - Trip end requested: $endTripOnServer');
      print('[BackgroundLocationService]    - All state cleared');
    } catch (e) {
      print('[BackgroundLocationService] ⚠️ Error stopping tracking: $e');
      _isRunning = false;
    }
  }

  /// End active trip on server using persisted trip data.
  /// Used when capture is already stopped and pending data has synced.
  Future<bool> endActiveTripOnServer() async {
    try {
      int? tripIdToUse = _currentTripId;
      String? tokenToUse = _token;

      if (tripIdToUse == null || tokenToUse == null) {
        final prefs = await SharedPreferences.getInstance();
        tripIdToUse = prefs.getInt('active_trip_id');
        tokenToUse = prefs.getString('active_token');
      }

      if (tripIdToUse == null || tokenToUse == null) {
        print(
            '[BackgroundLocationService] ⚠️ Missing trip data, cannot end trip on server');
        return false;
      }

      print(
          '[BackgroundLocationService] API HIT: ${AppConfig.baseURL}location/trip/end');
      final tripEndResponse = await http.post(
        Uri.parse('${AppConfig.baseURL}location/trip/end'),
        headers: {
          'Authorization': 'Bearer $tokenToUse',
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'trip_id': tripIdToUse}),
      );

      if (tripEndResponse.statusCode == 200 ||
          tripEndResponse.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('active_trip_id');
        await prefs.remove('active_user_cd');
        await prefs.remove('active_sync_id');
        await prefs.remove('active_token');
        print(
            '[BackgroundLocationService] ✅ Trip ended and SharedPreferences cleared');
        return true;
      }

      print(
          '[BackgroundLocationService] ⚠️ Trip end failed: ${tripEndResponse.statusCode} ${tripEndResponse.body}');
      return false;
    } catch (e) {
      print('[BackgroundLocationService] ⚠️ Error ending trip on server: $e');
      return false;
    }
  }

  /// Callback for starting the background service (Android & iOS)
  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    print('[BackgroundLocationService] [Background] Service started');

    // Handle service commands
    service.on('startLocationTracking').listen((event) async {
      final userCd = event?['userCd'] as String?;
      final syncId = event?['syncId'] as int?;
      final token = event?['token'] as String?;
      final tripId = event?['tripId'] as int?;

      if (userCd != null && syncId != null && token != null && tripId != null) {
        print(
            '[BackgroundLocationService] [Background] Starting location tracking');
        print(
            '[BackgroundLocationService] [Background]   User: $userCd, Sync: $syncId, Trip: $tripId');
        await _backgroundLocationTracking(
            service, userCd, syncId, token, tripId);
      }
    });

    service.on('stopLocationTracking').listen((event) {
      print('[BackgroundLocationService] [Background] Received stop signal');
      // This will be handled by returning from _backgroundLocationTracking
    });
  }

  /// Callback for iOS background
  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }

  /// Main background location tracking loop
  /// Runs in the background and captures location every 40 seconds
  @pragma('vm:entry-point')
  static Future<void> _backgroundLocationTracking(
    ServiceInstance service,
    String userCd,
    int syncId,
    String token,
    int tripId,
  ) async {
    final db = DatabaseHelper();

    print(
        '[BackgroundLocationService] [Background] 🟢 Location tracking loop started');
    print(
        '[BackgroundLocationService] [Background]   Capture interval: 40 seconds');
    print(
        '[BackgroundLocationService] [Background]   Sync strategy: Immediate (after each capture)');

    // Main tracking loop
    bool shouldContinue = true;
    service.on('stopLocationTracking').listen((event) {
      shouldContinue = false;
      print('[BackgroundLocationService] [Background] Received stop signal');
    });

    while (shouldContinue) {
      try {
        // Capture current location
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          print(
              '[BackgroundLocationService] [Background] 📍 Captured location: ${position.latitude}, ${position.longitude}');
          print(
              '[BackgroundLocationService] [Background]   Accuracy: ${position.accuracy}m, Speed: ${position.speed}m/s, Altitude: ${position.altitude}m');
          final timestampDateTime =
              DateTime.fromMillisecondsSinceEpoch(timestamp)
                  .toLocal()
                  .toIso8601String();
          print(
              '[BackgroundLocationService] [Background]   Timestamp: $timestampDateTime');

          // Store location in SQLite first (always, regardless of internet)
          try {
            print(
                '[BackgroundLocationService] [Background] 💾 Storing in local database...');
            final id = await db.insertLocationTracking(
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: timestamp,
              userCd: userCd,
              syncId: syncId,
              tripId: tripId,
              accuracy: position.accuracy,
              speed: position.speed,
              altitude: position.altitude,
            );
            print('[BackgroundLocationService] [Background] ✅ LOCAL DB STORED');
            print('[BackgroundLocationService] [Background]    Record ID: $id');
            print(
                '[BackgroundLocationService] [Background]    Trip ID: $tripId');
            print(
                '[BackgroundLocationService] [Background]    User: $userCd | Sync: $syncId');

            // Step 2: Immediately try to sync this single location to server
            print(
                '[BackgroundLocationService] [Background] 📤 Starting immediate server sync...');
            await _syncSingleLocation(
                db,
                id,
                position.latitude,
                position.longitude,
                timestamp,
                position.accuracy,
                position.speed,
                position.altitude,
                tripId,
                token);
          } catch (e) {
            print(
                '[BackgroundLocationService] [Background] ❌ Error storing location: $e');
          }
        } catch (e) {
          print('[BackgroundLocationService] [Background] ⚠️ GPS error: $e');
        }

        // Wait for the capture interval before next capture
        // Using periodic check in case service is stopped
        print(
            '[BackgroundLocationService] [Background] ⏳ Waiting 40 seconds before next capture cycle...');
        for (int i = 0; i < _captureInterval.inSeconds; i++) {
          if (!shouldContinue) {
            print(
                '[BackgroundLocationService] [Background] Service stopped, exiting loop');
            return;
          }
          await Future.delayed(const Duration(seconds: 1));
        }
        print('[BackgroundLocationService] [Background] ');
      } catch (e) {
        print(
            '[BackgroundLocationService] [Background] ❌ Error in tracking loop: $e');
        // Continue trying even on errors
        await Future.delayed(const Duration(seconds: 10));
      }
    }

    print(
        '[BackgroundLocationService] [Background] 🛑 Location tracking loop stopped');
  }

  /// Sync a single location immediately after capture
  /// If online: sends to server immediately
  /// If offline: leaves as unsynced for later retry
  static Future<void> _syncSingleLocation(
    DatabaseHelper db,
    int recordId,
    double latitude,
    double longitude,
    int timestamp,
    double accuracy,
    double speed,
    double altitude,
    int tripId,
    String token,
  ) async {
    try {
      final syncStartTime = DateTime.now();

      // Check internet connection
      print(
          '[BackgroundLocationService] [Background]    🌐 Checking internet connection...');
      final isOnline = await NetworkHelper.hasInternet();
      if (!isOnline) {
        print(
            '[BackgroundLocationService] [Background] ❌ NO INTERNET - Cannot sync');
        print(
            '[BackgroundLocationService] [Background]    Record id=$recordId will be retried when online');
        return;
      }
      print('[BackgroundLocationService] [Background]    ✅ Internet available');

      // Keep epoch seconds for backend validation and include ISO datetime.
      final timestampSeconds = timestamp ~/ 1000;
      final timestampDateTime = _formatDateTimeForApi(timestamp);

      final payload = {
        'trip_id': tripId,
        'lat': latitude,
        'lng': longitude,
        'accuracy': accuracy > 0 ? accuracy : null,
        'speed': speed > 0 ? speed : null,
        'altitude': altitude != 0 ? altitude : null,
        'timestamp': timestampSeconds,
        'timestamp_datetime': timestampDateTime,
      };

      print(
          '[BackgroundLocationService] [Background]    📨 HTTP POST Request Details:');
      print(
          '[BackgroundLocationService] [Background]       URL: ${AppConfig.baseURL}location/update');
      print('[BackgroundLocationService] [Background]       Method: POST');
      print(
          '[BackgroundLocationService] [Background]       Content-Type: application/json');
      print('[BackgroundLocationService] [Background]       Payload:');
      print('[BackgroundLocationService] [Background]         {');
      print(
          '[BackgroundLocationService] [Background]           \"trip_id\": \"${payload['trip_id']}\",');
      print(
          '[BackgroundLocationService] [Background]           \"lat\": \"${payload['lat']}\",');
      print(
          '[BackgroundLocationService] [Background]           \"lng\": \"${payload['lng']}\",');
      print(
          '[BackgroundLocationService] [Background]           \"accuracy\": \"${payload['accuracy']}\",');
      print(
          '[BackgroundLocationService] [Background]           \"speed\": \"${payload['speed']}\",');
      print(
          '[BackgroundLocationService] [Background]           \"altitude\": \"${payload['altitude']}\",');
      print(
          '[BackgroundLocationService] [Background]           \"timestamp\": \"${payload['timestamp']}\",');
      print(
          '[BackgroundLocationService] [Background]           \"timestamp_datetime\": \"${payload['timestamp_datetime']}\"');
      print('[BackgroundLocationService] [Background]         }');

      // Send to server via /api/location/update endpoint
      print('[BackgroundLocationService] [Background]    ⏳ Sending request...');
      print(
          '[BackgroundLocationService] [Background] API HIT: ${AppConfig.baseURL}location/update');
      final response = await http.post(
        Uri.parse('${AppConfig.baseURL}location/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final syncEndTime = DateTime.now();
      final syncElapsed = syncEndTime.difference(syncStartTime).inMilliseconds;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Mark as synced
        await db.markLocationTrackingSynced(recordId);
        print(
            '[BackgroundLocationService] [Background] ✅ SERVER SYNC SUCCESS (${syncElapsed}ms)');
        print(
            '[BackgroundLocationService] [Background]    Status Code: ${response.statusCode}');
        print(
            '[BackgroundLocationService] [Background]    Record ID: $recordId');
        print('[BackgroundLocationService] [Background]    Trip ID: $tripId');
        print(
            '[BackgroundLocationService] [Background]    Action: Marked as synced in local DB');
        print(
            '[BackgroundLocationService] [Background]    Server Response: ${response.body}');
      } else {
        print(
            '[BackgroundLocationService] [Background] ⚠️ SERVER SYNC FAILED (${syncElapsed}ms)');
        print(
            '[BackgroundLocationService] [Background]    Status Code: ${response.statusCode}');
        print(
            '[BackgroundLocationService] [Background]    Record ID: $recordId');
        print(
            '[BackgroundLocationService] [Background]    Server Error: ${response.body}');
        print(
            '[BackgroundLocationService] [Background]    Action: Will retry on next scheduled retry');
      }
    } catch (e, stack) {
      print('[BackgroundLocationService] [Background] ❌ SYNC EXCEPTION');
      print('[BackgroundLocationService] [Background]    Record ID: $recordId');
      print('[BackgroundLocationService] [Background]    Error: $e');
      print(
          '[BackgroundLocationService] [Background]    Action: Will retry on next scheduled retry');
    }
  }

  /// Sync pending locations to server
  /// Fallback mechanism for any locations that failed immediate sync
  /// (e.g., due to brief network interruption during capture)
  /// Called periodically every 5 minutes as a retry mechanism
  static Future<void> _syncPendingLocations(
    DatabaseHelper db,
    String userCd,
    int syncId,
    String token,
    int tripId,
  ) async {
    try {
      // Check internet connection
      final isOnline = await NetworkHelper.hasInternet();
      if (!isOnline) {
        print(
            '[BackgroundLocationService] [Background] 📵 No internet, skipping retry sync');
        return;
      }

      print(
          '[BackgroundLocationService] [Background] 🔄 Retry sync check: finding unsynced locations...');

      // Get all unsynced locations for this user
      final unsyncedLocations =
          await db.getUnsyncedLocationTrackingsByUser(userCd, syncId);

      if (unsyncedLocations.isEmpty) {
        print(
            '[BackgroundLocationService] [Background] ✅ No unsynced locations to retry');
        return;
      }

      print(
          '[BackgroundLocationService] [Background] 📤 Retrying ${unsyncedLocations.length} failed locations...');

      // Retry each unsynced location
      int successCount = 0;
      int failureCount = 0;

      for (var location in unsyncedLocations) {
        try {
          final id = location['id'] as int;
          final latitude = location['latitude'] as double;
          final longitude = location['longitude'] as double;
          final timestamp = location['timestamp'] as int; // milliseconds
          final accuracy = location['accuracy'] as double? ?? 0.0;
          final speed = location['speed'] as double? ?? 0.0;
          final altitude = location['altitude'] as double? ?? 0.0;

          // Keep epoch seconds for backend validation and include ISO datetime.
          final timestampSeconds = timestamp ~/ 1000;
          final timestampDateTime = _formatDateTimeForApi(timestamp);

          // Send to server via /api/location/update endpoint
          print(
              '[BackgroundLocationService] [Background] API HIT: ${AppConfig.baseURL}location/update');
          final response = await http.post(
            Uri.parse('${AppConfig.baseURL}location/update'),
            headers: {
              'Authorization': 'Bearer $token',
              'x-app-type': 'oms',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'trip_id': tripId,
              'lat': latitude,
              'lng': longitude,
              'accuracy': accuracy > 0 ? accuracy : null,
              'speed': speed > 0 ? speed : null,
              'altitude': altitude != 0 ? altitude : null,
              'timestamp': timestampSeconds,
              'timestamp_datetime': timestampDateTime,
            }),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            // Mark as synced
            await db.markLocationTrackingSynced(id);
            successCount++;
            print(
                '[BackgroundLocationService] [Background] ✅ Retry synced id=$id to trip=$tripId');
          } else {
            failureCount++;
            print(
                '[BackgroundLocationService] [Background] ⚠️ Retry failed for id=$id: ${response.statusCode}');
          }
        } catch (e) {
          failureCount++;
          print(
              '[BackgroundLocationService] [Background] ❌ Error retrying id: $e');
        }
      }

      print(
          '[BackgroundLocationService] [Background] 📊 Retry complete: $successCount success, $failureCount failed');
    } catch (e) {
      print(
          '[BackgroundLocationService] [Background] ❌ Error in retry sync batch: $e');
    }
  }

  /// Manually trigger retry sync of any pending locations
  /// Called from foreground when user wants to ensure sync happens
  /// This is a fallback for locations that failed immediate sync
  Future<void> syncNow() async {
    if (!_isRunning ||
        _currentUserCd == null ||
        _token == null ||
        _currentSyncId == null ||
        _currentTripId == null) {
      print('[BackgroundLocationService] ⚠️ Service not running, cannot sync');
      return;
    }

    print('[BackgroundLocationService] 🔄 Manual retry sync triggered');
    await _syncPendingLocations(
        _db, _currentUserCd!, _currentSyncId!, _token!, _currentTripId!);
  }
}
