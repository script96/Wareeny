import Flutter
import MessageUI
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var emergencySmsBridge: EmergencySmsBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    emergencySmsBridge = EmergencySmsBridge(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }
}

private final class EmergencySmsBridge: NSObject,
  MFMessageComposeViewControllerDelegate
{
  private var pendingResult: FlutterResult?
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.wareeny.bridge/emergency",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "sms.send" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pendingResult == nil else {
      result(
        FlutterError(
          code: "SMS_BUSY",
          message: "An emergency message is already open.",
          details: nil
        )
      )
      return
    }
    guard
      let arguments = call.arguments as? [String: Any],
      let phone = arguments["phone"] as? String,
      let body = arguments["body"] as? String
    else {
      result(
        FlutterError(
          code: "SMS_ARGUMENTS",
          message: "A phone number and message body are required.",
          details: nil
        )
      )
      return
    }
    guard MFMessageComposeViewController.canSendText() else {
      result(
        FlutterError(
          code: "SMS_UNAVAILABLE",
          message: "This device cannot send text messages.",
          details: nil
        )
      )
      return
    }
    guard let presenter = Self.topViewController() else {
      result(
        FlutterError(
          code: "SMS_NO_UI",
          message: "The emergency message screen could not be displayed.",
          details: nil
        )
      )
      return
    }

    pendingResult = result
    let composer = MFMessageComposeViewController()
    composer.messageComposeDelegate = self
    composer.recipients = [phone]
    composer.body = body
    presenter.present(composer, animated: true)
  }

  func messageComposeViewController(
    _ controller: MFMessageComposeViewController,
    didFinishWith result: MessageComposeResult
  ) {
    let flutterResult = pendingResult
    pendingResult = nil
    controller.dismiss(animated: true) {
      flutterResult?(result == .sent)
    }
  }

  private static func topViewController() -> UIViewController? {
    let keyWindow = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }

    var top = keyWindow?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
