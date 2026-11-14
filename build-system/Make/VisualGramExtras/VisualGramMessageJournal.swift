import Foundation
import Postbox
import SwiftSignalKit

public struct VisualGramArchivedMedia: Codable, Equatable {
    public enum Kind: String, Codable { case image, file }
    public let kind: Kind
    public let fileName: String
    public let mediaId: Int64
    public let width: Int32?
    public let height: Int32?
    public let originalFile: Data?
}

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
    // Optional so journals written by earlier builds remain readable.
    public let originalTimestamp: Int32?
    public let originalStableId: UInt32?
    public let originalNamespace: Int32?
    public let threadId: Int64?
    public let wasIncoming: Bool?
    public let authorName: String?
    public let archivedMedia: VisualGramArchivedMedia?
}

/// Keeps a bounded record on this device. It never requests deleted content from Telegram.
public final class VisualGramMessageJournal {
    private struct Snapshot: Codable, Equatable {
        struct Media: Codable, Equatable {
            let kind: VisualGramArchivedMedia.Kind
            let resourceId: String
            let width: Int32?
            let height: Int32?
            let originalFile: Data?
        }
        let accountId: Int64
        let peerId: Int64
        let peerNamespace: Int32
        let namespace: Int32
        let messageId: Int32
        let globalId: Int64?
        let authorId: Int64?
        let text: String
        let originalTimestamp: Int32?
        let originalStableId: UInt32?
        let threadId: Int64?
        let wasIncoming: Bool?
        let authorName: String?
        let media: Media?
    }
    private struct Storage: Codable {
        var snapshots: [String: Snapshot] = [:]
        var events: [VisualGramJournalEvent] = []
    }

    public static let shared = VisualGramMessageJournal()
    private let lock = NSLock()
    private let defaults = UserDefaults.standard
    private let revision = ValuePromise<Int32>(0, ignoreRepeated: true)
    private var revisionValue: Int32 = 0
    private var storage: Storage

    private static let maximumFileBytes: Int64 = 512 * 1024 * 1024
    private static let maximumArchiveBytes: Int64 = 1024 * 1024 * 1024
    private static var archiveDirectory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("VisualGramMediaJournal", isDirectory: true)
    }

    private init() {
        if let data = self.defaults.data(forKey: "visualgram.journal.v1"),
           let decoded = try? JSONDecoder().decode(Storage.self, from: data) {
            self.storage = decoded
        } else {
            self.storage = Storage()
        }
    }

    private var enabled: Bool { self.defaults.bool(forKey: "visualgram.spy.v1") }
    public var changes: Signal<Int32, NoError> { self.revision.get() }

    private func key(accountId: Int64, peerId: Int64, namespace: Int32, messageId: Int32) -> String {
        return "\(accountId):\(peerId):\(namespace):\(messageId)"
    }

    private func save(notify: Bool = false) {
        if self.storage.events.count > 500 {
            for event in self.storage.events.prefix(self.storage.events.count - 500) { self.removeArchive(event.archivedMedia) }
            self.storage.events.removeFirst(self.storage.events.count - 500)
        }
        if self.storage.snapshots.count > 2000 {
            for key in self.storage.snapshots.keys.sorted().prefix(self.storage.snapshots.count - 2000) {
                self.storage.snapshots.removeValue(forKey: key)
            }
        }
        if let data = try? JSONEncoder().encode(self.storage) {
            self.defaults.set(data, forKey: "visualgram.journal.v1")
        }
        if notify {
            self.revisionValue &+= 1
            let value = self.revisionValue
            Queue.mainQueue().async { [weak self] in
                guard let self else { return }
                self.revision.set(value)
            }
        }
    }

    private func removeArchive(_ media: VisualGramArchivedMedia?) {
        guard let media, let directory = Self.archiveDirectory else { return }
        let name = (media.fileName as NSString).lastPathComponent
        guard name == media.fileName else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }

    private func mediaSnapshot(_ message: Message) -> Snapshot.Media? {
        // Timed media and secret chats have their own expiration contract.
        guard message.id.peerId.namespace != Namespaces.Peer.SecretChat,
              !message.attributes.contains(where: { $0 is AutoremoveTimeoutMessageAttribute || $0 is AutoclearTimeoutMessageAttribute }) else { return nil }
        for item in message.media {
            if let image = item as? TelegramMediaImage,
               let largest = largestImageRepresentation(image.representations) {
                return Snapshot.Media(kind: .image, resourceId: largest.resource.id.stringRepresentation,
                                      width: largest.dimensions.width, height: largest.dimensions.height, originalFile: nil)
            }
            if let file = item as? TelegramMediaFile,
               (file.isVoice || file.isVideo || file.mimeType.hasPrefix("image/")),
               let originalFile = try? JSONEncoder().encode(file) {
                return Snapshot.Media(kind: .file, resourceId: file.resource.id.stringRepresentation,
                                      width: nil, height: nil, originalFile: originalFile)
            }
        }
        return nil
    }

    private func snapshot(accountId: PeerId, message: Message) -> Snapshot {
        return Snapshot(accountId: accountId.toInt64(), peerId: message.id.peerId.toInt64(),
                        peerNamespace: message.id.peerId.namespace, namespace: message.id.namespace,
                        messageId: message.id.id, globalId: message.globallyUniqueId,
                        authorId: message.author?.id.toInt64(), text: String(message.text.prefix(4096)),
                        originalTimestamp: message.timestamp, originalStableId: message.stableId,
                        threadId: message.threadId, wasIncoming: message.flags.contains(.Incoming),
                        authorName: message.author?.debugDisplayTitle, media: self.mediaSnapshot(message))
    }

    private func archive(_ media: Snapshot.Media?, mediaBox: MediaBox?) -> VisualGramArchivedMedia? {
        guard let media, let mediaBox, let directory = Self.archiveDirectory,
              let sourcePath = mediaBox.completedResourcePath(id: MediaResourceId(media.resourceId)) else { return nil }
        let source = URL(fileURLWithPath: sourcePath)
        let fileManager = FileManager.default
        let sourceAttributes = try? fileManager.attributesOfItem(atPath: sourcePath)
        guard let size = (sourceAttributes?[.size] as? NSNumber)?.int64Value,
              size > 0, size <= Self.maximumFileBytes else { return nil }
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let suffix: String
        if media.kind == .image { suffix = ".jpg" }
        else if let original = media.originalFile.flatMap({ try? JSONDecoder().decode(TelegramMediaFile.self, from: $0) }) {
            if original.isVoice { suffix = ".ogg" }
            else if original.mimeType == "video/quicktime" { suffix = ".mov" }
            else if original.mimeType.hasPrefix("video/") { suffix = ".mp4" }
            else { suffix = ".bin" }
        } else { suffix = ".bin" }
        let fileName = UUID().uuidString + suffix
        let target = directory.appendingPathComponent(fileName)
        do {
            do { try fileManager.linkItem(at: source, to: target) }
            catch {
                guard size <= 32 * 1024 * 1024 else { return nil }
                try fileManager.copyItem(at: source, to: target)
            }
        } catch { return nil }
        let archived = VisualGramArchivedMedia(kind: media.kind, fileName: fileName,
                                               mediaId: Int64.random(in: 1...Int64.max),
                                               width: media.width, height: media.height,
                                               originalFile: media.originalFile)
        let previous = self.storage.events.compactMap { $0.archivedMedia }
        var total: Int64 = size
        for item in previous {
            let path = directory.appendingPathComponent(item.fileName).path
            let attributes = try? fileManager.attributesOfItem(atPath: path)
            total += (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        }
        for item in previous where total > Self.maximumArchiveBytes {
            let path = directory.appendingPathComponent(item.fileName).path
            let attributes = try? fileManager.attributesOfItem(atPath: path)
            let itemSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            self.removeArchive(item)
            total -= itemSize
        }
        return archived
    }

    public func archivedMedia(_ media: VisualGramArchivedMedia?) -> Media? {
        guard let media, let directory = Self.archiveDirectory else { return nil }
        let name = (media.fileName as NSString).lastPathComponent
        guard name == media.fileName else { return nil }
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let resource = LocalFileReferenceMediaResource(localFilePath: url.path, randomId: media.mediaId)
        switch media.kind {
        case .image:
            guard let width = media.width, let height = media.height else { return nil }
            let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: width, height: height),
                resource: resource, progressiveSizes: [], immediateThumbnailData: nil)
            return TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: media.mediaId),
                representations: [representation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        case .file:
            guard let data = media.originalFile, let original = try? JSONDecoder().decode(TelegramMediaFile.self, from: data) else { return nil }
            return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: media.mediaId),
                partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [],
                immediateThumbnailData: nil, mimeType: original.mimeType, size: original.size,
                attributes: original.attributes, alternativeRepresentations: [])
        }
    }

    private func event(_ kind: VisualGramJournalEvent.Kind, snapshot: Snapshot, updatedText: String? = nil, mediaBox: MediaBox? = nil) {
        if kind == .deleted,
           self.storage.events.last(where: { $0.accountId == snapshot.accountId && $0.peerId == snapshot.peerId && $0.messageId == snapshot.messageId })?.kind == .deleted {
            return
        }
        let archived = kind == .deleted ? self.archive(snapshot.media, mediaBox: mediaBox) : nil
        self.storage.events.append(VisualGramJournalEvent(
            id: UUID().uuidString, accountId: snapshot.accountId, peerId: snapshot.peerId,
            messageId: snapshot.messageId, authorId: snapshot.authorId,
            date: Int32(clamping: Int64(Date().timeIntervalSince1970)), kind: kind,
            previousText: snapshot.text, updatedText: updatedText,
            originalTimestamp: snapshot.originalTimestamp, originalStableId: snapshot.originalStableId,
            originalNamespace: snapshot.namespace, threadId: snapshot.threadId,
            wasIncoming: snapshot.wasIncoming, authorName: snapshot.authorName,
            archivedMedia: archived
        ))
    }

    public func observe(accountId: PeerId, messages: [Message]) {
        guard self.enabled else { return }
        self.lock.lock()
        var changed = false
        let previousEventCount = self.storage.events.count
        for message in messages {
            let key = self.key(accountId: accountId.toInt64(), peerId: message.id.peerId.toInt64(), namespace: message.id.namespace, messageId: message.id.id)
            let snapshot = self.snapshot(accountId: accountId, message: message)
            if let previous = self.storage.snapshots[key], previous.text != snapshot.text {
                self.event(.edited, snapshot: previous, updatedText: snapshot.text)
            }
            if self.storage.snapshots[key] != snapshot {
                self.storage.snapshots[key] = snapshot
                changed = true
            }
        }
        if changed { self.save(notify: self.storage.events.count != previousEventCount) }
        self.lock.unlock()
    }

    public func recordEdit(accountId: PeerId, previous: Message, updatedText: String) {
        guard self.enabled, previous.text != updatedText else { return }
        self.lock.lock()
        let key = self.key(accountId: accountId.toInt64(), peerId: previous.id.peerId.toInt64(), namespace: previous.id.namespace, messageId: previous.id.id)
        let old = self.storage.snapshots[key] ?? self.snapshot(accountId: accountId, message: previous)
        self.event(.edited, snapshot: old, updatedText: String(updatedText.prefix(4096)))
        self.storage.snapshots[key] = Snapshot(accountId: old.accountId, peerId: old.peerId, peerNamespace: old.peerNamespace, namespace: old.namespace, messageId: old.messageId,
            globalId: old.globalId, authorId: old.authorId, text: String(updatedText.prefix(4096)),
            originalTimestamp: old.originalTimestamp, originalStableId: old.originalStableId,
            threadId: old.threadId, wasIncoming: old.wasIncoming, authorName: old.authorName, media: old.media)
        self.save(notify: true)
        self.lock.unlock()
    }

    public func recordDeleted(accountId: PeerId, messages: [Message], mediaBox: MediaBox) {
        guard self.enabled else { return }
        self.lock.lock()
        for message in messages {
            let key = self.key(accountId: accountId.toInt64(), peerId: message.id.peerId.toInt64(), namespace: message.id.namespace, messageId: message.id.id)
            let snapshot = self.storage.snapshots.removeValue(forKey: key) ?? self.snapshot(accountId: accountId, message: message)
            self.event(.deleted, snapshot: snapshot, mediaBox: mediaBox)
        }
        if !messages.isEmpty { self.save(notify: true) }
        self.lock.unlock()
    }

    public func recordDeletedGlobalIds(accountId: PeerId, ids: [Int32], mediaBox: MediaBox) {
        guard self.enabled, !ids.isEmpty else { return }
        self.lock.lock()
        let wanted = Set(ids.map { Int64($0) })
        let matches = self.storage.snapshots.filter { _, snapshot in
            snapshot.accountId == accountId.toInt64() && (snapshot.globalId.map(wanted.contains) ??
                ((snapshot.peerNamespace == Namespaces.Peer.CloudUser || snapshot.peerNamespace == Namespaces.Peer.CloudGroup) && wanted.contains(Int64(snapshot.messageId))))
        }
        for (key, snapshot) in matches {
            self.event(.deleted, snapshot: snapshot, mediaBox: mediaBox)
            self.storage.snapshots.removeValue(forKey: key)
        }
        if !matches.isEmpty { self.save(notify: true) }
        self.lock.unlock()
    }

    public func events(accountId: PeerId, peerId: PeerId? = nil) -> [VisualGramJournalEvent] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.storage.events.reversed().filter { $0.accountId == accountId.toInt64() && (peerId == nil || $0.peerId == peerId?.toInt64()) }
    }

    public func clear(accountId: PeerId) {
        self.lock.lock()
        for event in self.storage.events where event.accountId == accountId.toInt64() { self.removeArchive(event.archivedMedia) }
        self.storage.events.removeAll { $0.accountId == accountId.toInt64() }
        self.storage.snapshots = self.storage.snapshots.filter { $0.value.accountId != accountId.toInt64() }
        self.save(notify: true)
        self.lock.unlock()
    }
}
