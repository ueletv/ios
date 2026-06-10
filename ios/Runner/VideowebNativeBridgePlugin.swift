import Flutter

/// 标准 FlutterPlugin 注册入口（避免 AppDelegate 里直接 force-unwrap registrar）
final class VideowebNativeBridgePlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    NativeBridge.register(registrar: registrar)
  }
}
