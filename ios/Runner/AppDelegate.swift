import Flutter
import LocalAuthentication
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
    let channel = FlutterMethodChannel(
      name: "hu.bali0531.nhnk/biometrics",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isDeviceSupported":
        let context = LAContext()
        var error: NSError?
        result(context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error))
      case "authenticate":
        let args = call.arguments as? [String: String]
        let reason = args?["subtitle"] ?? "Unlock NHNK"
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
          result(true)
          return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
          DispatchQueue.main.async {
            result(success)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
