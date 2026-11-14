import Foundation
import UIKit
import AVFoundation
import ImageIO
import TelegramCore

final class VisualGramBannerMediaView: UIView {
    private let imageView = UIImageView()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?
    private var currentImage: VisualGramLocalImage?
    private var currentMedia: VisualGramLocalBannerMedia?
    private var playbackAllowed = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.clipsToBounds = true
        self.isUserInteractionEnabled = false
        self.imageView.contentMode = .scaleAspectFill
        self.imageView.clipsToBounds = true
        self.addSubview(self.imageView)
        NotificationCenter.default.addObserver(self, selector: #selector(updatePlayback), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updatePlayback), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updatePlayback), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        NotificationCenter.default.removeObserver(self)
        self.player?.pause()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.imageView.frame = self.bounds
        self.playerLayer?.frame = self.bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        self.updatePlayback()
    }

    func setPlaybackAllowed(_ allowed: Bool) {
        guard self.playbackAllowed != allowed else { return }
        self.playbackAllowed = allowed
        self.updatePlayback()
    }

    func configure(image: VisualGramLocalImage?, media: VisualGramLocalBannerMedia?) {
        guard self.currentImage != image || self.currentMedia != media else { return }
        self.currentImage = image
        self.currentMedia = media
        self.imageView.stopAnimating()
        self.imageView.animationImages = nil
        self.player?.pause()
        self.playerLayer?.removeFromSuperlayer()
        self.playerLayer = nil
        self.looper = nil
        self.player = nil

        if let media {
            if let posterURL = VisualGramLocalAppearance.imageURL(media.poster) {
                self.imageView.image = UIImage(contentsOfFile: posterURL.path)
            } else {
                self.imageView.image = nil
            }
            guard let url = VisualGramLocalAppearance.bannerMediaURL(media), FileManager.default.fileExists(atPath: url.path) else { return }
            switch media.kind {
            case .gif:
                if let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 1 {
                    let count = CGImageSourceGetCount(source)
                    let step = max(1, Int(ceil(Double(count) / 36.0)))
                    var frames: [UIImage] = []
                    var duration = 0.0
                    for index in stride(from: 0, to: count, by: step) {
                        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 640]
                        if let frame = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) {
                            frames.append(UIImage(cgImage: frame))
                            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
                            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
                            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue
                                ?? (gif?[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue ?? 0.1
                            duration += max(0.02, delay) * Double(step)
                        }
                    }
                    if frames.count > 1 {
                        self.imageView.animationImages = frames
                        self.imageView.animationDuration = max(0.1, duration)
                        self.imageView.animationRepeatCount = 0
                    }
                }
            case .video:
                let player = AVQueuePlayer()
                player.isMuted = true
                player.actionAtItemEnd = .none
                let looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
                let layer = AVPlayerLayer(player: player)
                layer.videoGravity = .resizeAspectFill
                layer.frame = self.bounds
                self.layer.insertSublayer(layer, above: self.imageView.layer)
                self.player = player
                self.looper = looper
                self.playerLayer = layer
            }
        } else if let image, let url = VisualGramLocalAppearance.imageURL(image) {
            self.imageView.image = UIImage(contentsOfFile: url.path)
        } else {
            self.imageView.image = nil
        }
        self.updatePlayback()
    }

    @objc private func updatePlayback() {
        let shouldPlay = self.window != nil && self.playbackAllowed && UIApplication.shared.applicationState == .active && !UIAccessibility.isReduceMotionEnabled
        if shouldPlay {
            self.imageView.startAnimating()
            self.player?.play()
        } else {
            self.imageView.stopAnimating()
            self.player?.pause()
        }
    }
}
