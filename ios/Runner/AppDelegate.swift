import Flutter
import UIKit
import firebase_messaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let pushChannel = FlutterMethodChannel(
      name: "histae/push",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    pushChannel.setMethodCallHandler { call, result in
      if call.method == "registerAPNs" {
        // Called only after the explicit notification choice and system grant.
        UIApplication.shared.registerForRemoteNotifications()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
