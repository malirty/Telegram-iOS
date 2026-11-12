import Foundation
import UIKit
import TelegramCore

public struct FlexGramGift: Codable {
    public let kind: String
    public let background: String
    public let pattern: String
    /// Read-only Telegram catalogue media copied into a local presentation record.
    public let catalogueGift: StarGift?
    public let collectibleAttributes: [StarGift.UniqueGift.Attribute]?

    public init(kind: String, background: String, pattern: String, catalogueGift: StarGift? = nil, collectibleAttributes: [StarGift.UniqueGift.Attribute]? = nil) {
        self.kind = kind
        self.background = background
        self.pattern = pattern
        self.catalogueGift = catalogueGift
        self.collectibleAttributes = collectibleAttributes
    }
}

/// Presentation data for this installation only. No Telegram engine records are changed.
public enum FlexGramOverrides {
    private static let defaults = UserDefaults.standard

    public static var virtualStars: Int {
        get { max(0, defaults.integer(forKey: "flexgram.virtualStars")) }
        set {
            defaults.set(max(0, newValue), forKey: "flexgram.virtualStars")
            NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        }
    }

    public static var virtualTon: Double {
        get { max(0, defaults.double(forKey: "flexgram.virtualTon")) }
        set {
            defaults.set(max(0, newValue), forKey: "flexgram.virtualTon")
            NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        }
    }

    private static func peerKey(_ field: String, accountId: Int64, peerId: Int64) -> String {
        return "flexgram.\(field).\(accountId).\(peerId)"
    }

    private static func messageKey(accountId: Int64, messageId: String) -> String {
        return "flexgram.message.\(accountId).\(messageId)"
    }

    public static func name(accountId: Int64, peerId: Int64) -> String? {
        return defaults.string(forKey: peerKey("name", accountId: accountId, peerId: peerId))
    }

    public static func setName(_ name: String?, accountId: Int64, peerId: Int64) {
        let key = peerKey("name", accountId: accountId, peerId: peerId)
        let value = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(String(value.prefix(64)), forKey: key)
        }
    }

    public static func avatar(accountId: Int64, peerId: Int64) -> UIImage? {
        guard let data = defaults.data(forKey: peerKey("avatar", accountId: accountId, peerId: peerId)) else {
            return nil
        }
        return UIImage(data: data)
    }

    public static func setAvatar(_ image: UIImage?, accountId: Int64, peerId: Int64) {
        let key = peerKey("avatar", accountId: accountId, peerId: peerId)
        guard let image else {
            defaults.removeObject(forKey: key)
            return
        }
        guard image.size.width > 0 && image.size.height > 0 else { return }
        let size = CGSize(width: 256.0, height: 256.0)
        let renderer = UIGraphicsImageRenderer(size: size)
        let scaled = renderer.image { _ in
            let scale = max(size.width / image.size.width, size.height / image.size.height)
            let rect = CGRect(
                x: (size.width - image.size.width * scale) * 0.5,
                y: (size.height - image.size.height * scale) * 0.5,
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            image.draw(in: rect)
        }
        if let data = scaled.jpegData(compressionQuality: 0.8) {
            defaults.set(data, forKey: key)
        }
    }

    public static func messageText(accountId: Int64, messageId: String) -> String? {
        return defaults.string(forKey: messageKey(accountId: accountId, messageId: messageId))
    }

    public static func setMessageText(_ text: String?, accountId: Int64, messageId: String) {
        let key = messageKey(accountId: accountId, messageId: messageId)
        let value = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(String(value.prefix(4096)), forKey: key)
        }
    }

    public static func gifts(accountId: Int64, peerId: Int64) -> [FlexGramGift] {
        let key = peerKey("gifts", accountId: accountId, peerId: peerId)
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode([FlexGramGift].self, from: data) else {
            return []
        }
        return value
    }

    public static func addGift(_ gift: FlexGramGift, accountId: Int64, peerId: Int64) {
        let key = peerKey("gifts", accountId: accountId, peerId: peerId)
        var value = gifts(accountId: accountId, peerId: peerId)
        value.append(gift)
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
            NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        }
    }
}

public extension Notification.Name {
    static let flexGramLocalDataChanged = Notification.Name("FlexGramLocalDataChanged")
}
