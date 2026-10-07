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
