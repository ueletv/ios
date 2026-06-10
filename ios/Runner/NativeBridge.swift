import AVFoundation
import Flutter
import MediaPlayer
import UIKit

/// 对齐 Android MainActivity：device_id / player_controls MethodChannel
enum NativeBridge {
  private static let deviceIdChannel = "com.video.videoweb/device_id"
  private static let playerControlsChannel = "com.video.videoweb/player_controls"
  private static let keychainService = "com.video.videoweb.device_id"
  private static let keychainAccount = "stable_device_id"
  private static var volumeView: MPVolumeView?

  static func register(registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()

    FlutterMethodChannel(name: deviceIdChannel, binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "getAndroidId":
          result(FlutterMethodNotImplemented)
        case "getStableDeviceId":
          result(resolveStableDeviceId())
        case "getUserAgent":
          result(buildUserAgent())
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    FlutterMethodChannel(name: playerControlsChannel, binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "getBrightness":
          let value = UIScreen.main.brightness
          result(value < 0 ? 0.5 : Double(value))
        case "setBrightness":
          let raw = (call.arguments as? [String: Any])?["value"] as? Double ?? 0.5
          UIScreen.main.brightness = CGFloat(min(max(raw, 0.02), 1.0))
          result(nil)
        case "getVolume":
          let session = AVAudioSession.sharedInstance()
          do {
            try session.setActive(true)
          } catch {}
          let maxVol = 15
          let current = Int(round(session.outputVolume * Float(maxVol)))
          result(["volume": current, "max": maxVol])
        case "setVolume":
          let volume = (call.arguments as? [String: Any])?["volume"] as? Int ?? 0
          setSystemVolume(volume: volume, max: 15)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    LiveGiftSvgaBridge.register(registrar: registrar)
  }

  // MARK: - Device ID (Keychain + IDFV，卸载后 Keychain 常可恢复)

  private static func resolveStableDeviceId() -> String {
    if let cached = readKeychain(), isValidDeviceId(cached) {
      return cached
    }
    let idfv = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    if isValidDeviceId(idfv) {
      writeKeychain(idfv)
      return idfv
    }
    let generated = UUID().uuidString
    writeKeychain(generated)
    return generated
  }

  private static func isValidDeviceId(_ id: String) -> Bool {
    let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 8, trimmed.count <= 64 else { return false }
    let pattern = "^[a-zA-Z0-9\\-]{8,64}$"
    return trimmed.range(of: pattern, options: .regularExpression) != nil
  }

  private static func readKeychain() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func writeKeychain(_ value: String) {
    let data = value.data(using: .utf8) ?? Data()
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
    ]
    let attrs: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let status = SecItemAdd(query.merging(attrs) { $1 } as CFDictionary, nil)
    if status == errSecDuplicateItem {
      let update = [kSecValueData as String: data]
      SecItemUpdate(query as CFDictionary, update as CFDictionary)
    }
  }

  private static func buildUserAgent() -> String {
    let device = UIDevice.current
    let os = device.systemVersion.replacingOccurrences(of: ".", with: "_")
    var model = device.model
    if model == "iPhone" {
      model = "iPhone"
    }
    return "Mozilla/5.0 (\(model); CPU iPhone OS \(os) like Mac OS X) "
      + "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 VideoWebApp/1.0"
  }

  // MARK: - Volume

  private static func setSystemVolume(volume: Int, max: Int) {
    ensureVolumeView()
    guard let slider = volumeView?.subviews.compactMap({ $0 as? UISlider }).first else { return }
    let clamped = min(max(volume, 0), max)
    let value = Float(clamped) / Float(max)
    DispatchQueue.main.async {
      slider.value = value
      slider.sendActions(for: .valueChanged)
    }
  }

  private static func ensureVolumeView() {
    if volumeView != nil { return }
    let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
    view.alpha = 0.01
    volumeView = view
    if let window = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap({ $0.windows })
      .first(where: { $0.isKeyWindow }) {
      window.addSubview(view)
    }
  }
}
