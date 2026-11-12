import Foundation
import UIKit
import TelegramCore

public struct FlexGramGift: Codable {
    public let kind: String
    public let background: String
    public let pattern: String
    public let localId: String?
    /// Read-only Telegram catalogue media copied into a local presentation record.
    public let catalogueGift: StarGift?
    public let collectibleAttributes: [StarGift.UniqueGift.Attribute]?

    public init(kind: String, background: String, pattern: String, catalogueGift: StarGift? = nil, collectibleAttributes: [StarGift.UniqueGift.Attribute]? = nil, localId: String? = UUID().uuidString) {
        self.kind = kind
        self.background = background
        self.pattern = pattern
        self.localId = localId
        self.catalogueGift = catalogueGift
        self.collectibleAttributes = collectibleAttributes
    }
}

public struct FlexGramBalanceEntry: Codable {
    public enum Currency: String, Codable, Equatable { case stars, ton, gram }
    public let date: Date
    public let currency: Currency
    public let change: Double
    public let balance: Double
    public let title: String

    public init(date: Date = Date(), currency: Currency, change: Double, balance: Double, title: String) {
        self.date = date
        self.currency = currency
        self.change = change
        self.balance = balance
        self.title = title
    }
}

public struct FlexGramScheduledGift: Codable {
    public let id: String
    public let accountId: Int64
    public let peerId: Int64
    public let gift: FlexGramGift
    public let deliveryDate: Date
    public let cost: Int
}

public struct FlexGramWalletCardLayout: Codable {
    public let x: Double
    public let y: Double
    public let scale: Double

    public init(x: Double = 0.0, y: Double = 0.0, scale: Double = 1.0) {
        self.x = x
        self.y = y
        self.scale = scale
    }
}

public enum FlexGramProfileField: String {
    case bio, businessGreeting, businessHours, businessLocation
}

/// Presentation data for this installation only. No Telegram engine records are changed.
public enum FlexGramOverrides {
    private static let defaults = UserDefaults.standard

    public static var sharedAppearance: Bool {
        get { defaults.bool(forKey: "flexgram.sharedAppearance") }
        set {
            defaults.set(newValue, forKey: "flexgram.sharedAppearance")
            NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        }
    }

    public static var virtualStars: Int {
        get { max(0, defaults.integer(forKey: "flexgram.virtualStars")) }
        set {
            let previous = virtualStars
            let value = max(0, min(1_000_000_000, newValue))
            guard value != previous else { return }
            defaults.set(value, forKey: "flexgram.virtualStars")
            appendBalanceEntry(FlexGramBalanceEntry(currency: .stars, change: Double(value - previous), balance: Double(value), title: "Изменение баланса"))
            NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        }
    }

    public static var virtualTon: Double {
        get { max(0, defaults.double(forKey: "flexgram.virtualTon")) }
        set {
            let previous = virtualTon
            let value = newValue.isFinite ? max(0, min(1_000_000_000, newValue)) : previous
            guard value != previous else { return }
            defaults.set(value, forKey: "flexgram.virtualTon")
            appendBalanceEntry(FlexGramBalanceEntry(currency: .ton, change: value - previous, balance: value, title: "Изменение баланса"))
            NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        }
    }

    public static var virtualGram: Double {
        get { max(0, defaults.double(forKey: "flexgram.virtualGram")) }
        set {
            let previous = virtualGram
            let value = newValue.isFinite ? max(0, min(1_000_000_000, newValue)) : previous
            guard value != previous else { return }
            defaults.set(value, forKey: "flexgram.virtualGram")
            appendBalanceEntry(FlexGramBalanceEntry(currency: .gram, change: value - previous, balance: value, title: "Изменение баланса"))
            NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        }
    }

    public static var balanceHistory: [FlexGramBalanceEntry] {
        guard let data = defaults.data(forKey: "flexgram.balanceHistory"),
              let entries = try? JSONDecoder().decode([FlexGramBalanceEntry].self, from: data) else { return [] }
        return entries
    }

    public static func walletCardGiftId(accountId: Int64) -> String? {
        return defaults.string(forKey: "flexgram.walletCardGift.\(accountId)")
    }

    public static func setWalletCardGiftId(_ id: String?, accountId: Int64) {
        let key = "flexgram.walletCardGift.\(accountId)"
        if let id { defaults.set(id, forKey: key) } else { defaults.removeObject(forKey: key) }
        NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
    }

    public static func walletCardLayout(accountId: Int64) -> FlexGramWalletCardLayout {
        let key = sharedAppearance ? "flexgram.walletCardLayout.shared" : "flexgram.walletCardLayout.\(accountId)"
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(FlexGramWalletCardLayout.self, from: data) else {
            return FlexGramWalletCardLayout()
        }
        return value
    }

    public static func setWalletCardLayout(_ layout: FlexGramWalletCardLayout, accountId: Int64) {
        guard layout.x.isFinite, layout.y.isFinite, layout.scale.isFinite,
              abs(layout.x) <= 50.0, abs(layout.y) <= 20.0,
              layout.scale >= 0.6, layout.scale <= 1.4,
              let data = try? JSONEncoder().encode(layout) else { return }
        let key = sharedAppearance ? "flexgram.walletCardLayout.shared" : "flexgram.walletCardLayout.\(accountId)"
        defaults.set(data, forKey: key)
        NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
    }

    private static func appendBalanceEntry(_ entry: FlexGramBalanceEntry) {
        var entries = balanceHistory
        entries.insert(entry, at: 0)
        if let data = try? JSONEncoder().encode(Array(entries.prefix(100))) {
            defaults.set(data, forKey: "flexgram.balanceHistory")
        }
    }

    private static func peerKey(_ field: String, accountId: Int64, peerId: Int64) -> String {
        return sharedAppearance ? "flexgram.\(field).shared.\(peerId)" : legacyPeerKey(field, accountId: accountId, peerId: peerId)
    }

    private static func legacyPeerKey(_ field: String, accountId: Int64, peerId: Int64) -> String {
        return "flexgram.\(field).\(accountId).\(peerId)"
    }

    private static func peerValue(_ field: String, accountId: Int64, peerId: Int64) -> Any? {
        let key = peerKey(field, accountId: accountId, peerId: peerId)
        if let value = defaults.object(forKey: key) { return value }
        return sharedAppearance ? defaults.object(forKey: legacyPeerKey(field, accountId: accountId, peerId: peerId)) : nil
    }

    private static func messageKey(accountId: Int64, messageId: String) -> String {
        return "flexgram.message.\(accountId).\(messageId)"
    }

    public static func profileField(_ field: FlexGramProfileField, accountId: Int64, peerId: Int64) -> String? {
        guard let value = peerValue("profile.\(field.rawValue)", accountId: accountId, peerId: peerId) as? String, !value.isEmpty else { return nil }
        return value
    }

    public static func setProfileField(_ field: FlexGramProfileField, value: String?, accountId: Int64, peerId: Int64) {
        let key = peerKey("profile.\(field.rawValue)", accountId: accountId, peerId: peerId)
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            if sharedAppearance { defaults.set("", forKey: key) } else { defaults.removeObject(forKey: key) }
        } else {
            defaults.set(String(trimmed.prefix(field == .businessGreeting ? 256 : 160)), forKey: key)
        }
        NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
    }

    public static func aliases(accountId: Int64, peerId: Int64) -> [String] {
        guard let data = peerValue("aliases", accountId: accountId, peerId: peerId) as? Data,
              let stored = try? JSONDecoder().decode([String].self, from: data) else {
            return name(accountId: accountId, peerId: peerId).map { [$0] } ?? []
        }
        let value = Array(stored.prefix(30))
        if let current = name(accountId: accountId, peerId: peerId), !value.contains(current) {
            return [current] + Array(value.prefix(29))
        }
        return value
    }

    @discardableResult
    public static func addAlias(_ alias: String, accountId: Int64, peerId: Int64) -> Bool {
        let value = String(alias.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
        guard !value.isEmpty else { return false }
        var names = aliases(accountId: accountId, peerId: peerId)
        guard names.count < 30 || names.contains(value) else { return false }
        names.removeAll(where: { $0 == value })
        names.insert(value, at: 0)
        guard let data = try? JSONEncoder().encode(names) else { return false }
        defaults.set(data, forKey: peerKey("aliases", accountId: accountId, peerId: peerId))
        setName(value, accountId: accountId, peerId: peerId)
        NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        return true
    }

    @discardableResult
    public static func removeAlias(_ alias: String, accountId: Int64, peerId: Int64) -> Bool {
        var names = aliases(accountId: accountId, peerId: peerId)
        guard names.contains(alias) else { return false }
        names.removeAll(where: { $0 == alias })
        guard let data = try? JSONEncoder().encode(names) else { return false }
        defaults.set(data, forKey: peerKey("aliases", accountId: accountId, peerId: peerId))
        if name(accountId: accountId, peerId: peerId) == alias {
            setName(names.first, accountId: accountId, peerId: peerId)
        }
        NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        return true
    }

    public static func name(accountId: Int64, peerId: Int64) -> String? {
        guard let value = peerValue("name", accountId: accountId, peerId: peerId) as? String, !value.isEmpty else { return nil }
        return value
    }

    public static func setName(_ name: String?, accountId: Int64, peerId: Int64) {
        let key = peerKey("name", accountId: accountId, peerId: peerId)
        let value = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty {
            if sharedAppearance { defaults.set("", forKey: key) } else { defaults.removeObject(forKey: key) }
        } else {
            defaults.set(String(value.prefix(64)), forKey: key)
        }
    }

    public static func chatBadge(accountId: Int64, peerId: Int64) -> String? {
        guard let value = peerValue("chatBadge", accountId: accountId, peerId: peerId) as? String, !value.isEmpty else { return nil }
        return value
    }

    public static func setChatBadge(_ badge: String?, accountId: Int64, peerId: Int64) {
        let key = peerKey("chatBadge", accountId: accountId, peerId: peerId)
        let value = badge?.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty {
            if sharedAppearance { defaults.set("", forKey: key) } else { defaults.removeObject(forKey: key) }
        } else {
            defaults.set(String(value.prefix(8)), forKey: key)
        }
    }

    public static func titleWithChatBadge(_ title: String, accountId: Int64, peerId: Int64) -> String {
        guard let badge = chatBadge(accountId: accountId, peerId: peerId) else { return title }
        return "\(title) \(badge)"
    }

    public static func avatar(accountId: Int64, peerId: Int64) -> UIImage? {
        guard let data = peerValue("avatar", accountId: accountId, peerId: peerId) as? Data else {
            return nil
        }
        return UIImage(data: data)
    }

    public static func setAvatar(_ image: UIImage?, accountId: Int64, peerId: Int64) {
        let key = peerKey("avatar", accountId: accountId, peerId: peerId)
        guard let image else {
            if sharedAppearance { defaults.set(Data(), forKey: key) } else { defaults.removeObject(forKey: key) }
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
        _ = deliverDueGifts()
        return storedGifts(accountId: accountId, peerId: peerId)
    }

    private static func storedGifts(accountId: Int64, peerId: Int64) -> [FlexGramGift] {
        guard let data = peerValue("gifts", accountId: accountId, peerId: peerId) as? Data,
              let value = try? JSONDecoder().decode([FlexGramGift].self, from: data) else {
            return []
        }
        guard value.contains(where: { $0.localId == nil }) else { return value }
        let migrated = value.map { gift -> FlexGramGift in
            guard gift.localId == nil else { return gift }
            return FlexGramGift(kind: gift.kind, background: gift.background, pattern: gift.pattern, catalogueGift: gift.catalogueGift, collectibleAttributes: gift.collectibleAttributes)
        }
        if let data = try? JSONEncoder().encode(migrated) {
            defaults.set(data, forKey: peerKey("gifts", accountId: accountId, peerId: peerId))
        }
        return migrated
    }

    @discardableResult
    public static func replaceGift(localId: String, accountId: Int64, peerId: Int64, with updated: FlexGramGift) -> Bool {
        guard updated.localId == localId else { return false }
        var value = storedGifts(accountId: accountId, peerId: peerId)
        guard let index = value.firstIndex(where: { $0.localId == localId }) else { return false }
        value[index] = updated
        guard let data = try? JSONEncoder().encode(value) else { return false }
        defaults.set(data, forKey: peerKey("gifts", accountId: accountId, peerId: peerId))
        NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        return true
    }

    @discardableResult
    public static func removeGift(localId: String, accountId: Int64, peerId: Int64) -> Bool {
        var gifts = storedGifts(accountId: accountId, peerId: peerId)
        guard let index = gifts.firstIndex(where: { $0.localId == localId }) else { return false }
        gifts.remove(at: index)
        guard let data = try? JSONEncoder().encode(gifts) else { return false }
        defaults.set(data, forKey: peerKey("gifts", accountId: accountId, peerId: peerId))
        NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        return true
    }

    @discardableResult
    public static func transferGift(localId: String, accountId: Int64, fromPeerId: Int64, toPeerId: Int64, cost: Int = 25) -> Bool {
        let balance = virtualStars
        guard fromPeerId != toPeerId, cost >= 0, balance >= cost else { return false }
        var source = storedGifts(accountId: accountId, peerId: fromPeerId)
        guard let index = source.firstIndex(where: { $0.localId == localId }) else { return false }
        let gift = source.remove(at: index)
        var target = storedGifts(accountId: accountId, peerId: toPeerId)
        guard !target.contains(where: { $0.localId == localId }) else { return false }
        target.append(gift)
        guard let sourceData = try? JSONEncoder().encode(source),
              let targetData = try? JSONEncoder().encode(target) else { return false }
        defaults.set(targetData, forKey: peerKey("gifts", accountId: accountId, peerId: toPeerId))
        defaults.set(sourceData, forKey: peerKey("gifts", accountId: accountId, peerId: fromPeerId))
        if cost > 0 {
            defaults.set(balance - cost, forKey: "flexgram.virtualStars")
            appendBalanceEntry(FlexGramBalanceEntry(currency: .stars, change: Double(-cost), balance: Double(balance - cost), title: "Локальный перевод подарка: \(gift.kind)"))
        }
        NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        return true
    }

    @discardableResult
    public static func sellGift(localId: String, accountId: Int64, peerId: Int64, price: Int = 75) -> Bool {
        let balance = virtualStars
        guard peerId == accountId, price > 0, balance <= 1_000_000_000 - price else { return false }
        var gifts = storedGifts(accountId: accountId, peerId: peerId)
        guard let index = gifts.firstIndex(where: { $0.localId == localId }) else { return false }
        let gift = gifts.remove(at: index)
        guard let data = try? JSONEncoder().encode(gifts) else { return false }
        defaults.set(data, forKey: peerKey("gifts", accountId: accountId, peerId: peerId))
        defaults.set(balance + price, forKey: "flexgram.virtualStars")
        appendBalanceEntry(FlexGramBalanceEntry(currency: .stars, change: Double(price), balance: Double(balance + price), title: "Локальная продажа подарка: \(gift.kind)"))
        NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        return true
    }

    @discardableResult
    public static func addGift(_ gift: FlexGramGift, accountId: Int64, peerId: Int64, cost: Int = 0) -> Bool {
        let balance = virtualStars
        guard cost >= 0, balance >= cost else { return false }
        let key = peerKey("gifts", accountId: accountId, peerId: peerId)
        var value = gifts(accountId: accountId, peerId: peerId)
        value.append(gift)
        guard let data = try? JSONEncoder().encode(value) else { return false }
        defaults.set(data, forKey: key)
        if cost > 0 {
            defaults.set(balance - cost, forKey: "flexgram.virtualStars")
            appendBalanceEntry(FlexGramBalanceEntry(currency: .stars, change: Double(-cost), balance: Double(balance - cost), title: "Подарок: \(gift.kind)"))
        }
        NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        return true
    }

    public static func scheduledGifts(accountId: Int64, peerId: Int64) -> [FlexGramScheduledGift] {
        _ = deliverDueGifts()
        return storedScheduledGifts().filter { $0.accountId == accountId && $0.peerId == peerId }.sorted { $0.deliveryDate < $1.deliveryDate }
    }

    private static func storedScheduledGifts() -> [FlexGramScheduledGift] {
        guard let data = defaults.data(forKey: "flexgram.scheduledGifts"),
              let value = try? JSONDecoder().decode([FlexGramScheduledGift].self, from: data) else { return [] }
        return value
    }

    @discardableResult
    public static func scheduleGift(_ gift: FlexGramGift, accountId: Int64, peerId: Int64, deliveryDate: Date, cost: Int = 100) -> Bool {
        let balance = virtualStars
        guard cost >= 0, balance >= cost, deliveryDate > Date(), storedScheduledGifts().count < 100 else { return false }
        var scheduled = storedScheduledGifts()
        scheduled.append(FlexGramScheduledGift(id: UUID().uuidString, accountId: accountId, peerId: peerId, gift: gift, deliveryDate: deliveryDate, cost: cost))
        guard let data = try? JSONEncoder().encode(scheduled) else { return false }
        defaults.set(data, forKey: "flexgram.scheduledGifts")
        defaults.set(balance - cost, forKey: "flexgram.virtualStars")
        appendBalanceEntry(FlexGramBalanceEntry(currency: .stars, change: Double(-cost), balance: Double(balance - cost), title: "Запланирован подарок: \(gift.kind)"))
        NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        return true
    }

    @discardableResult
    public static func cancelScheduledGift(id: String, accountId: Int64) -> Bool {
        _ = deliverDueGifts()
        var scheduled = storedScheduledGifts()
        guard let index = scheduled.firstIndex(where: { $0.id == id && $0.accountId == accountId }) else { return false }
        let item = scheduled.remove(at: index)
        guard let data = try? JSONEncoder().encode(scheduled) else { return false }
        let balance = virtualStars
        let refund = min(item.cost, max(0, 1_000_000_000 - min(balance, 1_000_000_000)))
        defaults.set(data, forKey: "flexgram.scheduledGifts")
        defaults.set(balance + refund, forKey: "flexgram.virtualStars")
        appendBalanceEntry(FlexGramBalanceEntry(currency: .stars, change: Double(refund), balance: Double(balance + refund), title: "Отменён подарок: \(item.gift.kind)"))
        NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        return true
    }

    @discardableResult
    public static func deliverDueGifts(now: Date = Date()) -> Int {
        let scheduled = storedScheduledGifts()
        guard !scheduled.isEmpty else { return 0 }
        var remaining: [FlexGramScheduledGift] = []
        var delivered = 0
        for item in scheduled {
            guard item.deliveryDate <= now else { remaining.append(item); continue }
            let key = peerKey("gifts", accountId: item.accountId, peerId: item.peerId)
            var gifts = storedGifts(accountId: item.accountId, peerId: item.peerId)
            if !gifts.contains(where: { $0.localId != nil && $0.localId == item.gift.localId }) {
                gifts.append(item.gift)
            }
            guard let data = try? JSONEncoder().encode(gifts) else { remaining.append(item); continue }
            defaults.set(data, forKey: key)
            delivered += 1
        }
        if delivered > 0, let data = try? JSONEncoder().encode(remaining) {
            defaults.set(data, forKey: "flexgram.scheduledGifts")
            NotificationCenter.default.post(name: .flexGramLocalDataChanged, object: nil)
        }
        return delivered
    }
}

public extension Notification.Name {
    static let flexGramLocalDataChanged = Notification.Name("FlexGramLocalDataChanged")
}
