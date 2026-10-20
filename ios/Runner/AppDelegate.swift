import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IncomingFilesPlugin") {
      IncomingFilesPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WindowControlsPlugin") {
      WindowControlsPlugin.register(with: registrar)
    }
  }
}

/// iPadOS 26+ draws the window buttons (close, minimise, tile) over the
/// app's top-left corner when it runs in a window. Flutter's safe area
/// leaves them out, so this tells Dart how far below the safe area they
/// reach; the app moves its content down by that much.
class WindowControlsPlugin: NSObject, FlutterPlugin {
  private var channel: FlutterMethodChannel?
  private weak var registrar: FlutterPluginRegistrar?
  private var probe: UIView?
  private var last: CGFloat = -1

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = WindowControlsPlugin()
    let channel = FlutterMethodChannel(name: "app.tabiya/window", binaryMessenger: registrar.messenger())
    instance.channel = channel
    instance.registrar = registrar
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "start" else { return result(FlutterMethodNotImplemented) }
    if probe == nil, let view = registrar?.viewController?.view {
      attach(to: view)
    }
    result(nil)
  }

  private func attach(to view: UIView) {
    guard #available(iOS 26.0, *) else { return }
    // An invisible strip from the top of the view to the top of the area
    // clear of the window buttons: its height changes whenever they move.
    let strip = ProbeView { [weak self, weak view] in
      guard let self, let view else { return }
      let clear = view.edgeInsets(for: .safeArea(cornerAdaptation: .vertical)).top
      self.send(max(0, clear - view.safeAreaInsets.top))
    }
    strip.isUserInteractionEnabled = false
    strip.isHidden = true
    strip.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(strip)
    let guide = view.layoutGuide(for: .safeArea(cornerAdaptation: .vertical))
    NSLayoutConstraint.activate([
      strip.topAnchor.constraint(equalTo: view.topAnchor),
      strip.bottomAnchor.constraint(equalTo: guide.topAnchor),
      strip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      strip.widthAnchor.constraint(equalToConstant: 1),
    ])
    probe = strip
  }

  private func send(_ extra: CGFloat) {
    guard extra != last else { return }
    last = extra
    channel?.invokeMethod("controls", arguments: Double(extra))
  }
}

private class ProbeView: UIView {
  private let onChange: () -> Void
  init(onChange: @escaping () -> Void) {
    self.onChange = onChange
    super.init(frame: .zero)
  }
  required init?(coder: NSCoder) { fatalError() }

  override func layoutSubviews() {
    super.layoutSubviews()
    onChange()
  }

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    onChange()
  }
}

/// Receives documents opened with Tabiya ("Open in…", Files, Mail,
/// messengers) and forwards their bytes to Dart (F-IMP-02).
class IncomingFilesPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private var channel: FlutterMethodChannel?
  private var pending: [[String: Any]] = []
  private var dartReady = false
  private static let maxBytes = 64 * 1024 * 1024

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = IncomingFilesPlugin()
    let channel = FlutterMethodChannel(name: "app.tabiya/incoming", binaryMessenger: registrar.messenger())
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
    registrar.addSceneDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "getInitial" {
      dartReady = true
      result(pending)
      pending.removeAll()
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  private func receive(_ url: URL) {
    guard url.isFileURL else { return }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    guard let data = try? Data(contentsOf: url), data.count <= IncomingFilesPlugin.maxBytes else { return }
    let payload: [String: Any] = [
      "name": url.lastPathComponent,
      "bytes": FlutterStandardTypedData(bytes: data),
    ]
    if dartReady {
      channel?.invokeMethod("incoming", arguments: payload)
    } else {
      pending.append(payload)
    }
  }

  // Cold start with a document.
  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions?) -> Bool {
    connectionOptions?.urlContexts.forEach { receive($0.url) }
    return false
  }

  // Document opened while running.
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    var handled = false
    for ctx in URLContexts where ctx.url.isFileURL {
      receive(ctx.url)
      handled = true
    }
    return handled
  }

  func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    guard url.isFileURL else { return false }
    receive(url)
    return true
  }
}
