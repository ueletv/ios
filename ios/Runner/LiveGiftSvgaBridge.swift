import Flutter
import SVGAPlayer
import UIKit

/// 对齐 Android LiveGiftSvgaHolder + PlatformView
enum LiveGiftSvgaBridge {
  private static let channelName = "com.video.videoweb/live_gift_svga"
  private static let viewType = "com.video.videoweb/live_gift_svga_view"

  static func register(registrar: FlutterPluginRegistrar) {
    registrar.register(LiveGiftSvgaViewFactory(), withId: viewType)

    FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
      .setMethodCallHandler { call, result in
        switch call.method {
        case "play":
          let args = call.arguments as? [String: Any]
          let url = args?["url"] as? String ?? ""
          let duration = args?["duration"] as? Int ?? 4
          LiveGiftSvgaHolder.shared.play(url: url, durationSeconds: duration)
          result(nil)
        case "clear":
          LiveGiftSvgaHolder.shared.clear()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }
}

final class LiveGiftSvgaHolder {
  static let shared = LiveGiftSvgaHolder()

  private weak var overlay: LiveGiftSvgaOverlayView?
  private var pendingUrl: String?
  private var pendingDuration = 4

  func register(_ overlay: LiveGiftSvgaOverlayView) {
    self.overlay = overlay
    if let url = pendingUrl, !url.isEmpty {
      overlay.play(url: url, durationSeconds: pendingDuration)
      pendingUrl = nil
    }
  }

  func unregister(_ overlay: LiveGiftSvgaOverlayView) {
    if self.overlay === overlay {
      self.overlay = nil
    }
  }

  func play(url: String, durationSeconds: Int) {
    if let overlay {
      overlay.play(url: url, durationSeconds: durationSeconds)
    } else {
      pendingUrl = url
      pendingDuration = durationSeconds
    }
  }

  func clear() {
    overlay?.clear()
    pendingUrl = nil
  }
}

final class LiveGiftSvgaOverlayView: UIView {
  private var players: [SVGAPlayer] = []
  private let parser = SVGAParser()

  func play(url: String, durationSeconds: Int) {
    let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.lowercased().contains(".svga") else { return }

    clear()

    let player = SVGAPlayer(frame: bounds)
    player.contentMode = .scaleAspectFit
    player.clearsAfterStop = true
    player.loops = 0
    player.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(player)
    players.append(player)

    guard let loadUrl = URL(string: trimmed) else {
      remove(player)
      return
    }

    parser.parse(
      with: loadUrl,
      completionBlock: { [weak self, weak player] videoItem in
        guard let self, let player, player.superview != nil, let item = videoItem else { return }
        DispatchQueue.main.async {
          player.videoItem = item
          player.startAnimation()
        }
      },
      failureBlock: { [weak self, weak player] _ in
        guard let self, let player else { return }
        DispatchQueue.main.async {
          self.remove(player)
        }
      }
    )

    let seconds = max(durationSeconds, 1)
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds)) { [weak self, weak player] in
      guard let self, let player else { return }
      self.stopAndRemove(player)
    }
  }

  func clear() {
    players.forEach { stopAndRemove($0) }
  }

  private func stopAndRemove(_ player: SVGAPlayer) {
    player.stopAnimation()
    player.removeFromSuperview()
    players.removeAll { $0 === player }
  }

  private func remove(_ player: SVGAPlayer) {
    player.removeFromSuperview()
    players.removeAll { $0 === player }
  }
}

final class LiveGiftSvgaPlatformView: NSObject, FlutterPlatformView {
  private let container = UIView()
  private let overlay = LiveGiftSvgaOverlayView()

  init(frame: CGRect) {
    super.init()
    container.frame = frame
    container.backgroundColor = .clear
    container.isUserInteractionEnabled = false
    overlay.frame = container.bounds
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.backgroundColor = .clear
    overlay.isUserInteractionEnabled = false
    container.addSubview(overlay)
    LiveGiftSvgaHolder.shared.register(overlay)
  }

  func view() -> UIView { container }

  deinit {
    overlay.clear()
    LiveGiftSvgaHolder.shared.unregister(overlay)
  }
}

final class LiveGiftSvgaViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    LiveGiftSvgaPlatformView(frame: frame)
  }

  func createArgsCodec() -> (any FlutterMessageCodec & NSObjectProtocol) {
    FlutterStandardMessageCodec.sharedInstance()
  }
}
