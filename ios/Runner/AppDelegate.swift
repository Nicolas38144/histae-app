import Flutter
import UIKit
import StoreKit
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
        // Called only after notification activation and the system grant.
        UIApplication.shared.registerForRemoteNotifications()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    let updatesChannel = FlutterMethodChannel(
      name: "histae/store-updates",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    updatesChannel.setMethodCallHandler { call, result in
      guard call.method == "check" else {
        result(FlutterMethodNotImplemented)
        return
      }
      #if DEBUG || targetEnvironment(simulator)
      result(nil)
      #else
      // TestFlight/sandbox and apps without a production receipt stay usable.
      guard let receipt = Bundle.main.appStoreReceiptURL,
            receipt.lastPathComponent == "receipt",
            FileManager.default.fileExists(atPath: receipt.path),
            let bundle = Bundle.main.bundleIdentifier,
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      else { result(nil); return }
      Task { @MainActor in
        guard let storefront = await Storefront.current else { result(nil); return }
        result([
          "platform": "ios", "bundle": bundle, "version": version,
          "country": storefront.countryCode, "os": UIDevice.current.systemVersion
        ])
      }
      #endif
    }
  }
}
