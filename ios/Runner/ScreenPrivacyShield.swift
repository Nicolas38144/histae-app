import UIKit

/// Uses supported lifecycle/capture APIs. iOS cannot prevent a still screenshot.
@MainActor
final class ScreenPrivacyShield: NSObject {
  private weak var contentWindow: UIWindow?
  private let coverWindow: UIWindow
  private let coverController = ScreenPrivacyViewController()
  private let originalAccessibilityHidden: Bool
  private var active = false
  private var stopCaptureObservation: (() -> Void)?

  init(window: UIWindow, scene: UIWindowScene) {
    contentWindow = window
    originalAccessibilityHidden = window.accessibilityElementsHidden
    coverWindow = UIWindow(windowScene: scene)
    coverWindow.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
    coverWindow.backgroundColor = ScreenPrivacyViewController.background
    coverWindow.isOpaque = true
    coverWindow.rootViewController = coverController
    coverWindow.accessibilityViewIsModal = true
    super.init()

    if #available(iOS 18.0, *) {
      let registration = window.registerForTraitChanges([UITraitSceneCaptureState.self]) {
        [weak self] (_: UIWindow, _: UITraitCollection) in
        self?.update()
      }
      stopCaptureObservation = { [weak window] in
        window?.unregisterForTraitChanges(registration)
      }
    } else {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(captureChanged(_:)),
        name: UIScreen.capturedDidChangeNotification,
        object: scene.screen
      )
    }
    setActive(scene.activationState == .foregroundActive)
  }

  func setActive(_ value: Bool) {
    active = value
    update()
  }

  func stop() {
    stopCaptureObservation?()
    stopCaptureObservation = nil
    NotificationCenter.default.removeObserver(self)
    contentWindow?.accessibilityElementsHidden = originalAccessibilityHidden
    coverWindow.isHidden = true
    coverWindow.rootViewController = nil
  }

  @objc private func captureChanged(_ notification: Notification) {
    update()
  }

  private func update() {
    guard let window = contentWindow else { return }
    let captured: Bool
    if #available(iOS 18.0, *) {
      captured = window.traitCollection.sceneCaptureState != .notCaptured
    } else {
      captured = window.windowScene?.screen.isCaptured ?? false
    }
    let hidden = !active || captured
    coverController.setCaptured(captured)
    window.accessibilityElementsHidden = hidden || originalAccessibilityHidden
    if hidden { window.endEditing(true) }
    // Do not become key: Flutter retains keyboard and navigation ownership.
    coverWindow.isHidden = !hidden
  }
}

@MainActor
private final class ScreenPrivacyViewController: UIViewController {
  // Matches HistaeTokens.night. No private content is rendered in this window.
  static let background = UIColor(red: 13 / 255, green: 20 / 255, blue: 33 / 255, alpha: 1)
  private let help = UILabel()

  override func loadView() {
    view = UIView()
    view.backgroundColor = Self.background
    view.isOpaque = true
    view.accessibilityViewIsModal = true

    let icon = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
    icon.tintColor = UIColor(red: 242 / 255, green: 164 / 255, blue: 140 / 255, alpha: 1)
    icon.contentMode = .scaleAspectFit
    icon.isAccessibilityElement = false
    icon.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      icon.heightAnchor.constraint(equalToConstant: 48),
      icon.widthAnchor.constraint(equalToConstant: 48),
    ])

    let title = UILabel()
    title.text = copy("HistaePrivacyShieldTitle")
    title.font = .preferredFont(forTextStyle: .headline)
    title.adjustsFontForContentSizeCategory = true
    title.textColor = .white
    title.textAlignment = .center
    title.numberOfLines = 0
    help.text = copy("HistaePrivacyShieldCaptureHelp")
    help.font = .preferredFont(forTextStyle: .subheadline)
    help.adjustsFontForContentSizeCategory = true
    help.textColor = UIColor.white.withAlphaComponent(0.75)
    help.textAlignment = .center
    help.numberOfLines = 0

    let content = UIStackView(arrangedSubviews: [icon, title, help])
    content.axis = .vertical
    content.alignment = .center
    content.spacing = 16
    content.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(content)
    NSLayoutConstraint.activate([
      content.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
      content.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
      content.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, constant: -48),
    ])
  }

  func setCaptured(_ captured: Bool) {
    loadViewIfNeeded()
    help.isHidden = !captured
  }

  private func copy(_ key: String) -> String? {
    Bundle.main.localizedInfoDictionary?[key] as? String
      ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
  }
}
