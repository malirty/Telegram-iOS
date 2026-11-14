import Foundation
import Postbox

public struct VisualGramJournalEvent: Codable, Equatable {
    public enum Kind: String, Codable { case edited, deleted }
    public let id: String
    public let accountId: Int64
    public let peerId: Int64
    public let messageId: Int32
    public let authorId: Int64?
    public let date: Int32
    public let kind: Kind
    public let previousText: String
    public let updatedText: String?
}

/// Keeps a bounded record on this device. It never requests deleted content from Telegram.
public final class VisualGramMessageJournal {
    private struct Snapshot: Codable, Equatable {
        let accountId: Int64
        let peerId: Int64
        let peerNamespace: Int32
        let namespace: Int32
        let messageId: Int32
        let globalId: Int64?
        let authorId: Int64?
        let text: String
    }
    private struct Storage: Codable {
        var snapshots: [String: Snapshot] = [:]
        var events: [VisualGramJournalEvent] = []
    }

    public static let shared = VisualGramMessageJournal()
    private let lock = NSLock()
    private let defaults = UserDefaults.standard
    private var storage: Storage

    private init() {
        if let data = self.defaults.data(forKey: "visualgram.journal.v1"),
           let decoded = try? JSONDecoder().decode(Storage.self, from: data) {
            self.storage = decoded
        } else {
            self.storage = Storage()
        }
    }

    private var enabled: Bool { self.defaults.bool(forKey: "visualgram.spy.v1") }

    private func key(accountId: Int64, peerId: Int64, namespace: Int32, messageId: Int32) -> String {
        return "\(accountId):\(peerId):\(namespace):\(messageId)"
    }

    private func save() {
        if self.storage.events.count > 500 { self.storage.events.removeFirst(self.storage.events.count - 500) }
        if self.storage.snapshots.count > 2000 {
            for key in self.storage.snapshots.keys.sorted().prefix(self.storage.snapshots.count - 2000) {
                self.storage.snapshots.removeValue(forKey: key)
            }
        }
        if let data = try? JSONEncoder().encode(self.storage) {
            self.defaults.set(data, forKey: "visualgram.journal.v1")
        }
    }

    private func event(_ kind: VisualGramJournalEvent.Kind, snapshot: Snapshot, updatedText: String? = nil) {
        if kind == .deleted,
           self.storage.events.last(where: { $0.accountId == snapshot.accountId && $0.peerId == snapshot.peerId && $0.messageId == snapshot.messageId })?.kind == .deleted {
            return
        }
        self.storage.events.append(VisualGramJournalEvent(
            id: UUID().uuidString, accountId: snapshot.accountId, peerId: snapshot.peerId,
            messageId: snapshot.messageId, authorId: snapshot.authorId,
            date: Int32(clamping: Int64(Date().timeIntervalSince1970)), kind: kind,
            previousText: snapshot.text, updatedText: updatedText
        ))
    }

    public func observe(accountId: PeerId, messages: [Message]) {
        guard self.enabled else { return }
        self.lock.lock()
        var changed = false
        for message in messages {
            let key = self.key(accountId: accountId.toInt64(), peerId: message.id.peerId.toInt64(), namespace: message.id.namespace, messageId: message.id.id)
            let snapshot = Snapshot(accountId: accountId.toInt64(), peerId: message.id.peerId.toInt64(), peerNamespace: message.id.peerId.namespace, namespace: message.id.namespace,
                                    messageId: message.id.id, globalId: message.globallyUniqueId, authorId: message.author?.id.toInt64(),
                                    text: String(message.text.prefix(4096)))
            if let previous = self.storage.snapshots[key], previous.text != snapshot.text {
                self.event(.edited, snapshot: previous, updatedText: snapshot.text)
            }
            if self.storage.snapshots[key] != snapshot {
                self.storage.snapshots[key] = snapshot
                changed = true
            }
        }
        if changed { self.save() }
        self.lock.unlock()
    }

    public func recordEdit(accountId: PeerId, previous: Message, updatedText: String) {
        guard self.enabled, previous.text != updatedText else { return }
        self.lock.lock()
        let key = self.key(accountId: accountId.toInt64(), peerId: previous.id.peerId.toInt64(), namespace: previous.id.namespace, messageId: previous.id.id)
        let old = self.storage.snapshots[key] ?? Snapshot(accountId: accountId.toInt64(), peerId: previous.id.peerId.toInt64(), peerNamespace: previous.id.peerId.namespace, namespace: previous.id.namespace,
            messageId: previous.id.id, globalId: previous.globallyUniqueId, authorId: previous.author?.id.toInt64(), text: String(previous.text.prefix(4096)))
        self.event(.edited, snapshot: old, updatedText: String(updatedText.prefix(4096)))
        self.storage.snapshots[key] = Snapshot(accountId: old.accountId, peerId: old.peerId, peerNamespace: old.peerNamespace, namespace: old.namespace, messageId: old.messageId,
            globalId: old.globalId, authorId: old.authorId, text: String(updatedText.prefix(4096)))
        self.save()
        self.lock.unlock()
    }

    public func recordDeleted(accountId: PeerId, messages: [Message]) {
        guard self.enabled else { return }
        self.lock.lock()
        for message in messages {
            let key = self.key(accountId: accountId.toInt64(), peerId: message.id.peerId.toInt64(), namespace: message.id.namespace, messageId: message.id.id)
            let snapshot = self.storage.snapshots.removeValue(forKey: key) ?? Snapshot(accountId: accountId.toInt64(), peerId: message.id.peerId.toInt64(), peerNamespace: message.id.peerId.namespace, namespace: message.id.namespace,
                messageId: message.id.id, globalId: message.globallyUniqueId, authorId: message.author?.id.toInt64(), text: String(message.text.prefix(4096)))
            self.event(.deleted, snapshot: snapshot)
        }
        if !messages.isEmpty { self.save() }
        self.lock.unlock()
    }

    public func recordDeletedGlobalIds(accountId: PeerId, ids: [Int32]) {
        guard self.enabled, !ids.isEmpty else { return }
        self.lock.lock()
        let wanted = Set(ids.map { Int64($0) })
        let matches = self.storage.snapshots.filter { _, snapshot in
            snapshot.accountId == accountId.toInt64() && (snapshot.globalId.map(wanted.contains) ??
                ((snapshot.peerNamespace == Namespaces.Peer.CloudUser || snapshot.peerNamespace == Namespaces.Peer.CloudGroup) && wanted.contains(Int64(snapshot.messageId))))
        }
        for (key, snapshot) in matches {
            self.event(.deleted, snapshot: snapshot)
            self.storage.snapshots.removeValue(forKey: key)
        }
        self.save()
        self.lock.unlock()
    }

    public func events(accountId: PeerId, peerId: PeerId? = nil) -> [VisualGramJournalEvent] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.storage.events.reversed().filter { $0.accountId == accountId.toInt64() && (peerId == nil || $0.peerId == peerId?.toInt64()) }
    }

    public func clear(accountId: PeerId) {
        self.lock.lock()
        self.storage.events.removeAll { $0.accountId == accountId.toInt64() }
        self.storage.snapshots = self.storage.snapshots.filter { $0.value.accountId != accountId.toInt64() }
        self.save()
        self.lock.unlock()
    }
}
