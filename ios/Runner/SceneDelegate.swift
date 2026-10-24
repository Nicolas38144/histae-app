import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var privacyShield: ScreenPrivacyShield?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard let window, let windowScene = scene as? UIWindowScene else { return }
    privacyShield = ScreenPrivacyShield(window: window, scene: windowScene)
  }

  override func sceneWillResignActive(_ scene: UIScene) {
    privacyShield?.setActive(false)
    super.sceneWillResignActive(scene)
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    privacyShield?.setActive(false)
    super.sceneDidEnterBackground(scene)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    privacyShield?.setActive(true)
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    privacyShield?.stop()
    privacyShield = nil
    super.sceneDidDisconnect(scene)
  }
}
