import Flutter
import UIKit
import CoreLocation
import UserNotifications
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {

    /// Native iOS location tracking manager.
    /// Handles CLLocationManager lifecycle and dispatches location data to Flutter.
    private var locationTrackingManager: IOSLocationTrackingManager?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize Google Maps SDK before registering plugins using Google Maps API key
        GMSServices.provideAPIKey("AIzaSyCHNYtneNSu_KZwoGAK7pFGWhJpKFVaiaI")

        // Initialize Flutter engine first
        GeneratedPluginRegistrant.register(with: self)

        // Request system push/local notification authorizations on iOS
        registerForNotifications(application: application)

        // Create the location tracking manager
        locationTrackingManager = IOSLocationTrackingManager()

        // Set up MethodChannels
        if let controller = window?.rootViewController as? FlutterViewController {
            setupIOSLocationChannel(controller: controller)
            setupTrackingControlChannel(controller: controller)
            setupNotificationChannel(controller: controller)
            setupBatteryChannel(controller: controller)
            setupManufacturerChannel(controller: controller)
        }

        // Check if app was launched by a significant-change location event.
        // This happens when the user force-quit the app and then moved ~500m.
        // iOS relaunches the app in the background to deliver the location update.
        if launchOptions?[.location] != nil {
            NSLog("[AppDelegate] 🔄 App launched from significant-change location event")
            NSLog("[AppDelegate] Checking for active trip to resume...")

            if let manager = locationTrackingManager {
                let resumed = manager.resumeTrackingFromPrefs()
                if resumed {
                    NSLog("[AppDelegate] ✅ Active trip resumed after significant-change relaunch")
                } else {
                    NSLog("[AppDelegate] ℹ️ No active trip found to resume")
                }
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - iOS Location MethodChannel
    // Channel: "com.arhamerp.app/ios_location"
    // Used by ios_background_location_service.dart to control native CLLocationManager

    private func setupIOSLocationChannel(controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "com.arhamerp.app/ios_location",
            binaryMessenger: controller.binaryMessenger
        )

        // Give the channel reference to the tracking manager so it can send location updates to Dart
        locationTrackingManager?.setMethodChannel(channel)

        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self, let manager = self.locationTrackingManager else {
                result(FlutterError(code: "UNAVAILABLE", message: "Location manager not initialized", details: nil))
                return
            }

            switch call.method {
            case "startTracking":
                guard let args = call.arguments as? [String: Any],
                      let userCd = args["userCd"] as? String,
                      let syncId = args["syncId"] as? Int,
                      let token = args["token"] as? String,
                      let tripId = args["tripId"] as? Int else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
                    return
                }

                NSLog("[AppDelegate] MethodChannel: startTracking(user=\(userCd), syncId=\(syncId), tripId=\(tripId))")
                manager.startTracking(userCd: userCd, syncId: syncId, token: token, tripId: tripId)
                result(true)

            case "stopTracking":
                NSLog("[AppDelegate] MethodChannel: stopTracking()")
                manager.stopTracking()
                result(true)

            case "isTracking":
                result(manager.isTracking)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Tracking Control MethodChannel (Android stubs for iOS)
    // Channel: "com.arhamerp.app/tracking_control"
    // On Android, this controls AlarmManager watchdog and foreground service.
    // On iOS, these are no-ops since iOS doesn't have equivalent mechanisms.

    private func setupTrackingControlChannel(controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "com.arhamerp.app/tracking_control",
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "startTrackingRecoveryWatchdog":
                // No-op on iOS: AlarmManager watchdog is Android-only
                NSLog("[AppDelegate] tracking_control: startTrackingRecoveryWatchdog (no-op on iOS)")
                result(true)

            case "stopTrackingRecoveryWatchdog":
                // No-op on iOS: AlarmManager watchdog is Android-only
                NSLog("[AppDelegate] tracking_control: stopTrackingRecoveryWatchdog (no-op on iOS)")
                result(true)

            case "stopForegroundService":
                // No-op on iOS: Foreground services are Android-only
                NSLog("[AppDelegate] tracking_control: stopForegroundService (no-op on iOS)")
                result(true)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Notification MethodChannel (Android stubs for iOS)
    // Channel: "com.arhamerp.app/notification"
    // On Android, this sets the foreground service notification as ongoing.
    // On iOS, there's no equivalent persistent notification.

    private func setupNotificationChannel(controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "com.arhamerp.app/notification",
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "setNotificationOngoing":
                // No-op on iOS: No persistent foreground notification concept
                NSLog("[AppDelegate] notification: setNotificationOngoing (no-op on iOS)")
                result(true)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Battery MethodChannel (iOS stub)
    // Channel: "com.arhamerp.app/battery"
    // On Android, this checks battery optimization settings.
    // On iOS, battery optimization is managed by the OS — no user-facing toggle.

    private func setupBatteryChannel(controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "com.arhamerp.app/battery",
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "isBatteryOptimizationEnabled":
                // iOS doesn't have battery optimization settings like Android
                // Return false (not restricted) so the Dart-side dialog doesn't show
                result(false)

            case "openBatteryOptimizationSettings":
                // Open general Settings on iOS
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Manufacturer MethodChannel (iOS stub)
    // Channel: "my_channel"
    // On Android, returns Build.MANUFACTURER for device-specific battery guidance.
    // On iOS, returns "Apple".

    private func setupManufacturerChannel(controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "my_channel",
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "getManufacturer":
                result("Apple")

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Native iOS Notification Authorization Prompt
    private func registerForNotifications(application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                NSLog("[AppDelegate] ❌ Notification permission error: \(error.localizedDescription)")
            } else {
                NSLog("[AppDelegate] 🔔 Notification permission status: \(granted)")
            }
        }
        application.registerForRemoteNotifications()
    }
}
