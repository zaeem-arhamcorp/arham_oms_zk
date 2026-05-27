import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "arham_oms/notification_debug",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getStatus":
        if #available(iOS 10.0, *) {
          UNUserNotificationCenter.current().getNotificationSettings { settings in
            let payload: [String: Any] = [
              "authorizationStatus": self.authorizationStatusString(settings.authorizationStatus),
              "alertSetting": self.notificationSettingString(settings.alertSetting),
              "badgeSetting": self.notificationSettingString(settings.badgeSetting),
              "soundSetting": self.notificationSettingString(settings.soundSetting),
              "lockScreenSetting": self.notificationSettingString(settings.lockScreenSetting),
              "notificationCenterSetting": self.notificationSettingString(settings.notificationCenterSetting),
              "showPreviewsSetting": self.showPreviewsSettingString(settings.showPreviewsSetting),
              "isRegisteredForRemoteNotifications": application.isRegisteredForRemoteNotifications,
              "systemVersion": UIDevice.current.systemVersion,
              "bundleId": Bundle.main.bundleIdentifier ?? "",
            ]
            result(payload)
          }
        } else {
          result([
            "authorizationStatus": "unsupported",
            "isRegisteredForRemoteNotifications": application.isRegisteredForRemoteNotifications,
            "systemVersion": UIDevice.current.systemVersion,
            "bundleId": Bundle.main.bundleIdentifier ?? "",
          ])
        }
      case "registerForRemoteNotifications":
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    NSLog("[NotificationDebug] APNs registered. Token: \(token)")
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[NotificationDebug] APNs registration failed: \(error)")
  }

  private func authorizationStatusString(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .notDetermined:
      return "notDetermined"
    case .denied:
      return "denied"
    case .authorized:
      return "authorized"
    case .provisional:
      return "provisional"
    case .ephemeral:
      return "ephemeral"
    @unknown default:
      return "unknown"
    }
  }

  private func notificationSettingString(_ setting: UNNotificationSetting) -> String {
    switch setting {
    case .enabled:
      return "enabled"
    case .disabled:
      return "disabled"
    case .notSupported:
      return "notSupported"
    @unknown default:
      return "unknown"
    }
  }

  private func showPreviewsSettingString(_ setting: UNShowPreviewsSetting) -> String {
    switch setting {
    case .always:
      return "always"
    case .whenAuthenticated:
      return "whenAuthenticated"
    case .never:
      return "never"
    @unknown default:
      return "unknown"
    }
  }
}
