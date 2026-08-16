import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let backupExclusionChannel = "roundtablezoo/backup_exclusion"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Required so a reminder notification's banner still shows while the
    // app is in the foreground (FR-016d) — without a registered delegate,
    // UNUserNotificationCenter suppresses it silently.
    UNUserNotificationCenter.current().delegate = self

    guard let messenger = engineBridge.pluginRegistry as? FlutterBinaryMessenger else {
      return
    }
    let channel = FlutterMethodChannel(
      name: AppDelegate.backupExclusionChannel,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup", let path = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(AppDelegate.excludeFromBackup(path: path))
    }
  }

  /// Sets `NSURLIsExcludedFromBackupKey` on the file/directory at `path` so it is never
  /// included in an iCloud/iTunes device backup (FR-016d — the local database must stay
  /// on-device only).
  private static func excludeFromBackup(path: String) -> Bool {
    var url = URL(fileURLWithPath: path)
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    do {
      try url.setResourceValues(resourceValues)
      return true
    } catch {
      return false
    }
  }

  /// Foreground presentation for the reminder notification (FR-016d) —
  /// banner and sound must show even while the app is open, matching
  /// Android's default channel behavior (FR-025a). `FlutterAppDelegate`
  /// already conforms to `UNUserNotificationCenterDelegate` and provides a
  /// default implementation, so this is an `override`, not a fresh
  /// conformance — a separate `extension AppDelegate:
  /// UNUserNotificationCenterDelegate` fails to build ("redundant
  /// conformance").
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }
}
