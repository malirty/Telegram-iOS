"""Attach local VisualGram profile and message presentation to the pinned Telegram UI."""
from pathlib import Path
import sys
import shutil


def replace_once(path: Path, old: str, new: str) -> None:
    source = path.read_text(encoding="utf-8")
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"Expected one anchor in {path}: {old[:70]!r}; found {count}")
    path.write_text(source.replace(old, new, 1), encoding="utf-8", newline="\n")


def replace_count(path: Path, old: str, new: str, expected: int) -> None:
    source = path.read_text(encoding="utf-8")
    count = source.count(old)
    if count != expected:
        raise RuntimeError(f"Expected {expected} anchors in {path}: {old[:70]!r}; found {count}")
    path.write_text(source.replace(old, new), encoding="utf-8", newline="\n")


def apply(root: Path) -> None:
    shutil.copyfile(Path(__file__).with_name("VisualGramMessageEditorController.swift"),
                    root / "submodules/TelegramUI/Sources/VisualGramMessageEditorController.swift")
    shutil.copyfile(Path(__file__).with_name("VisualGramBannerMediaView.swift"),
                    root / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/VisualGramBannerMediaView.swift")
    shutil.copyfile(Path(__file__).with_name("VisualGramMessageJournal.swift"),
                    root / "submodules/TelegramCore/Sources/VisualGramMessageJournal.swift")
    reads = root / "submodules/TelegramCore/Sources/TelegramEngine/Messages/ApplyMaxReadIndexInteractively.swift"
    replace_once(reads, "func _internal_applyMaxReadIndexInteractively(postbox: Postbox, stateManager: AccountStateManager, index: MessageIndex) -> Signal<Void, NoError> {\n", """func visualGramGhostModeEnabled() -> Bool {
    return UserDefaults.standard.bool(forKey: "visualgram.ghost.v1")
}

func _internal_applyMaxReadIndexInteractively(postbox: Postbox, stateManager: AccountStateManager, index: MessageIndex) -> Signal<Void, NoError> {
""")
    replace_once(reads, "func _internal_applyMaxReadIndexInteractively(transaction: Transaction, stateManager: AccountStateManager, index: MessageIndex) {\n", """func _internal_applyMaxReadIndexInteractively(transaction: Transaction, stateManager: AccountStateManager, index: MessageIndex) {
    if visualGramGhostModeEnabled() { return }
""")
    for signature in [
        "func _internal_toggleForumThreadUnreadMarkInteractively(transaction: Transaction, network: Network, viewTracker: AccountViewTracker, peerId: PeerId, threadId: Int64, setToValue: Bool?) {\n",
        "func _internal_markForumThreadAsReadInteractively(transaction: Transaction, network: Network, viewTracker: AccountViewTracker, peerId: PeerId, threadId: Int64) {\n",
        "func _internal_togglePeerUnreadMarkInteractively(transaction: Transaction, network: Network, viewTracker: AccountViewTracker, peerId: PeerId, setToValue: Bool? = nil) {\n",
    ]:
        replace_once(reads, signature, signature + "    if visualGramGhostModeEnabled() { return }\n")
    stories = root / "submodules/TelegramCore/Sources/TelegramEngine/Messages/Stories.swift"
    replace_once(stories, "func _internal_markStoryAsSeen(account: Account, peerId: PeerId, id: Int32, asPinned: Bool) -> Signal<Never, NoError> {\n", """func _internal_markStoryAsSeen(account: Account, peerId: PeerId, id: Int32, asPinned: Bool) -> Signal<Never, NoError> {
    if visualGramGhostModeEnabled() { return .complete() }
""")
    mark_all = root / "submodules/TelegramCore/Sources/TelegramEngine/Messages/MarkAllChatsAsRead.swift"
    replace_once(mark_all, "func _internal_markAllChatsAsRead(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {\n", """func _internal_markAllChatsAsRead(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    if visualGramGhostModeEnabled() { return .complete() }
""")
    reply_reads = root / "submodules/TelegramCore/Sources/TelegramEngine/Messages/ReplyThreadHistory.swift"
    replace_once(reply_reads, "    func applyMaxReadIndex(messageIndex: MessageIndex) {\n", """    func applyMaxReadIndex(messageIndex: MessageIndex) {
        if visualGramGhostModeEnabled() { return }
""")
    sync_reads = root / "submodules/TelegramCore/Sources/State/SynchronizePeerReadState.swift"
    replace_once(sync_reads, "private func pushPeerReadState(network: Network, postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId, readState: PeerReadState) -> Signal<PeerReadState, PeerReadStateValidationError> {\n", """private func pushPeerReadState(network: Network, postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId, readState: PeerReadState) -> Signal<PeerReadState, PeerReadStateValidationError> {
    if visualGramGhostModeEnabled() { return .single(readState) }
""")
    sync_stories = root / "submodules/TelegramCore/Sources/State/ManagedSynchronizeViewStoriesOperations.swift"
    replace_once(sync_stories, "private func pushStoriesAreSeen(postbox: Postbox, network: Network, stateManager: AccountStateManager, peer: Peer, operation: SynchronizeViewStoriesOperation) -> Signal<Void, NoError> {\n", """private func pushStoriesAreSeen(postbox: Postbox, network: Network, stateManager: AccountStateManager, peer: Peer, operation: SynchronizeViewStoriesOperation) -> Signal<Void, NoError> {
    if visualGramGhostModeEnabled() { return .complete() }
""")
    content_reads = root / "submodules/TelegramCore/Sources/State/ManagedSynchronizeConsumeMessageContentsOperations.swift"
    replace_once(content_reads, "private func synchronizeConsumeMessageContents(transaction: Transaction, network: Network, stateManager: AccountStateManager, peerId: PeerId, operation: SynchronizeConsumeMessageContentsOperation) -> Signal<Void, NoError> {\n", """private func synchronizeConsumeMessageContents(transaction: Transaction, network: Network, stateManager: AccountStateManager, peerId: PeerId, operation: SynchronizeConsumeMessageContentsOperation) -> Signal<Void, NoError> {
    if visualGramGhostModeEnabled() { return .complete() }
""")
    personal_reads = root / "submodules/TelegramCore/Sources/State/ManagedConsumePersonalMessagesActions.swift"
    for signature in [
        "private func synchronizeConsumeMessageContents(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, id: MessageId) -> Signal<Void, NoError> {\n",
        "private func synchronizeReadMessageReactionsOrPollVotes(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, id: MessageId) -> Signal<Void, NoError> {\n",
    ]:
        replace_once(personal_reads, signature, signature + "    if visualGramGhostModeEnabled() { return .complete() }\n")
    unseen_reads = root / "submodules/TelegramCore/Sources/State/ManagedSynchronizeMarkAllUnseenPersonalMessagesOperations.swift"
    for signature in [
        "private func synchronizeMarkAllUnseen(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, peerId: PeerId, operation: SynchronizeMarkAllUnseenPersonalMessagesOperation) -> Signal<Void, NoError> {\n",
        "private func synchronizeMarkAllUnseenReactions(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, peerId: PeerId, operation: SynchronizeMarkAllUnseenReactionsOperation) -> Signal<Void, NoError> {\n",
        "private func synchronizeMarkAllUnseenPollVotes(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, peerId: PeerId, operation: SynchronizeMarkAllUnseenReactionsOperation) -> Signal<Void, NoError> {\n",
    ]:
        replace_once(unseen_reads, signature, signature + "    if visualGramGhostModeEnabled() { return .complete() }\n")
    live_location_reads = root / "submodules/TelegramCore/Sources/State/AccountViewTracker.swift"
    replace_once(live_location_reads, "    public func updateSeenLiveLocationForMessageIds(messageIds: Set<MessageId>) {\n", """    public func updateSeenLiveLocationForMessageIds(messageIds: Set<MessageId>) {
        if visualGramGhostModeEnabled() { return }
""")
    state_updates = root / "submodules/TelegramCore/Sources/State/AccountStateManagementUtils.swift"
    consumed = root / "submodules/TelegramCore/Sources/TelegramEngine/Messages/MarkMessageContentAsConsumedInteractively.swift"
    replace_once(consumed,
                 "func _internal_markMessageContentAsConsumedInteractively(postbox: Postbox, messageId: MessageId) -> Signal<Void, NoError> {\n",
                 "func _internal_markMessageContentAsConsumedInteractively(postbox: Postbox, accountId: PeerId, messageId: MessageId) -> Signal<Void, NoError> {\n")
    replace_once(consumed,
                 "        if let message = transaction.getMessage(messageId), message.flags.contains(.Incoming) {\n",
                 "        if let message = transaction.getMessage(messageId), message.flags.contains(.Incoming) {\n            VisualGramMessageJournal.shared.recordTimed(accountId: accountId, message: message, mediaBox: postbox.mediaBox)\n")
    replace_once(consumed,
                 "func markMessageContentAsConsumedRemotely(transaction: Transaction, messageId: MessageId, consumeDate: Int32?) {\n    if let message = transaction.getMessage(messageId) {\n",
                 "func markMessageContentAsConsumedRemotely(transaction: Transaction, messageId: MessageId, consumeDate: Int32?, accountId: PeerId? = nil, mediaBox: MediaBox? = nil) {\n    if let message = transaction.getMessage(messageId) {\n        if let accountId, let mediaBox { VisualGramMessageJournal.shared.recordTimed(accountId: accountId, message: message, mediaBox: mediaBox) }\n")
    engine_messages = root / "submodules/TelegramCore/Sources/TelegramEngine/Messages/TelegramEngineMessages.swift"
    replace_once(engine_messages,
                 "_internal_markMessageContentAsConsumedInteractively(postbox: self.account.postbox, messageId: messageId)",
                 "_internal_markMessageContentAsConsumedInteractively(postbox: self.account.postbox, accountId: self.account.peerId, messageId: messageId)")
    replace_once(state_updates,
                 "markMessageContentAsConsumedRemotely(transaction: transaction, messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id), consumeDate: date)",
                 "markMessageContentAsConsumedRemotely(transaction: transaction, messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id), consumeDate: date, accountId: accountPeerId, mediaBox: mediaBox)")
    replace_once(state_updates,
                 "markMessageContentAsConsumedRemotely(transaction: transaction, messageId: messageId, consumeDate: date)",
                 "markMessageContentAsConsumedRemotely(transaction: transaction, messageId: messageId, consumeDate: date, accountId: accountPeerId, mediaBox: mediaBox)")
    autoremove = root / "submodules/TelegramCore/Sources/State/ManagedAutoremoveMessageOperations.swift"
    replace_once(autoremove,
                 "func managedAutoremoveMessageOperations(network: Network, postbox: Postbox, isRemove: Bool) -> Signal<Void, NoError> {\n",
                 "func managedAutoremoveMessageOperations(network: Network, postbox: Postbox, accountId: PeerId, isRemove: Bool) -> Signal<Void, NoError> {\n")
    replace_once(autoremove,
                 "                    if let message = transaction.getMessage(entry.messageId) {\n",
                 "                    if let message = transaction.getMessage(entry.messageId) {\n                        VisualGramMessageJournal.shared.recordTimed(accountId: accountId, message: message, mediaBox: postbox.mediaBox)\n")
    replace_once(autoremove,
                 "                        if message.id.peerId.namespace == Namespaces.Peer.SecretChat || isRemove {\n                            _internal_deleteMessages(transaction: transaction, mediaBox: postbox.mediaBox, ids: [entry.messageId])\n",
                 "                        if message.id.peerId.namespace == Namespaces.Peer.SecretChat || isRemove {\n                            VisualGramMessageJournal.shared.recordDeleted(accountId: accountId, messages: [message], mediaBox: postbox.mediaBox)\n                            _internal_deleteMessages(transaction: transaction, mediaBox: postbox.mediaBox, ids: [entry.messageId])\n")
    account = root / "submodules/TelegramCore/Sources/Account/Account.swift"
    replace_count(account,
                  "managedAutoremoveMessageOperations(network: self.network, postbox: self.postbox, isRemove:",
                  "managedAutoremoveMessageOperations(network: self.network, postbox: self.postbox, accountId: peerId, isRemove:", 2)
    replace_once(state_updates, """            case let .DeleteMessagesWithGlobalIds(ids):
                var resourceIds: [MediaResourceId] = []
""", """            case let .DeleteMessagesWithGlobalIds(ids):
                VisualGramMessageJournal.shared.recordDeletedGlobalIds(accountId: accountPeerId, ids: ids, mediaBox: mediaBox)
                var resourceIds: [MediaResourceId] = []
""")
    replace_once(state_updates, """            case let .DeleteMessages(ids):
                _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: ids, manualAddMessageThreadStatsDifference: { id, add, remove in
""", """            case let .DeleteMessages(ids):
                VisualGramMessageJournal.shared.recordDeleted(accountId: accountPeerId, messages: ids.compactMap { transaction.getMessage($0) }, mediaBox: mediaBox)
                _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: ids, manualAddMessageThreadStatsDifference: { id, add, remove in
""")
    replace_once(state_updates, """            case let .EditMessage(id, message):
                var generatedEvent: (reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)?
                transaction.updateMessage(id, update: { previousMessage in
""", """            case let .EditMessage(id, message):
                var generatedEvent: (reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)?
                transaction.updateMessage(id, update: { previousMessage in
                    VisualGramMessageJournal.shared.recordEdit(accountId: accountPeerId, previous: previousMessage, updatedText: message.text)
""")
    status_data = root / "submodules/TelegramCore/Sources/TelegramEngine/AccountData/TelegramEngineAccountData.swift"
    replace_once(status_data,
                 "if VisualGramLocalAppearance.shared.appearance(accountId: self.account.peerId).enabled {\n                _ = VisualGramLocalAppearance.shared.setLocalGiftStatus",
                 "if VisualGramLocalAppearance.shared.appearance(accountId: self.account.peerId).enabled || VisualGramLocalAppearance.shared.deviceSettings.localPremiumPresentation {\n                _ = VisualGramLocalAppearance.shared.setLocalGiftStatus")
    status_picker = root / "submodules/TelegramUI/Components/EmojiStatusSelectionComponent/Sources/EmojiStatusSelectionComponent.swift"
    replace_once(status_picker, "                                    return user.isPremium\n", "                                    return user.isPremium || VisualGramLocalAppearance.shared.deviceSettings.localPremiumPresentation\n")
    replace_once(status_picker, "if !self.context.isPremium || count < 3, let pushController = controller.pushController {",
                 "if (!self.context.isPremium && !VisualGramLocalAppearance.shared.deviceSettings.localPremiumPresentation) || count < 3, let pushController = controller.pushController {")
    profile = root / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreen.swift"
    replace_once(profile, """            case .edit:
                if case let .replyThread(message) = strongSelf.chatLocation {
""", """            case .edit:
                if VisualGramLocalAppearance.shared.deviceSettings.openEditorMode,
                   strongSelf.peerId != strongSelf.context.account.peerId,
                   let peer = strongSelf.data?.peer, case .user = peer {
                    strongSelf.controller?.push(visualGramProfileEditorController(context: strongSelf.context, targetPeerId: strongSelf.peerId, targetTitle: peer.compactDisplayTitle))
                    break
                }
                if case let .replyThread(message) = strongSelf.chatLocation {
""")
    replace_once(profile, """            navigationFlags.canEdit = peerInfoCanEdit(peer: self.data?.peer, chatLocation: self.chatLocation, threadData: self.data?.threadData, cachedData: self.data?.cachedData, isContact: self.data?.isContact)
""", """            navigationFlags.canEdit = peerInfoCanEdit(peer: self.data?.peer, chatLocation: self.chatLocation, threadData: self.data?.threadData, cachedData: self.data?.cachedData, isContact: self.data?.isContact)
            if VisualGramLocalAppearance.shared.deviceSettings.openEditorMode,
               self.peerId != self.context.account.peerId,
               let peer = self.data?.peer, case .user = peer {
                navigationFlags.canEdit = true
            }
""")
    replace_once(profile, "                if appearance.enabled {\n", """                if appearance.enabled {
                    if let cached = data.cachedData as? CachedUserData {
                        var local = cached
                        if let bio = appearance.localBio { local = local.withUpdatedAbout(bio) }
                        if let avatar = appearance.localAvatar, let image = VisualGramLocalAppearance.localImage(avatar) {
                            local = local.withUpdatedPhoto(.known(image))
                        }
                        data.cachedData = local
                    }
""")
    replace_once(profile,
                 "if let verification = appearance.verification, let cached = data.serverCachedData as? CachedUserData {",
                 "if let verification = appearance.verification, let cached = data.cachedData as? CachedUserData {")
    replace_once(profile, """            self.headerNode.displayPremiumIntro = { [weak self] sourceView, peerStatus, emojiStatusFileAndPack, white in
                guard let strongSelf = self, let peer = strongSelf.data?.peer else {
                    return
                }
""", """            self.headerNode.displayPremiumIntro = { [weak self] sourceView, peerStatus, emojiStatusFileAndPack, white in
                guard let strongSelf = self, let peer = strongSelf.data?.peer else {
                    return
                }
                if VisualGramLocalAppearance.shared.deviceSettings.localPremiumPresentation {
                    strongSelf.controller?.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, title: "Локальный Premium", text: "Визуальный режим включён на этом устройстве. Подписка и серверные функции Telegram не изменены.", actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    return
                }
""")

    header = root / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoHeaderNode.swift"
    replace_once(header, "    let backgroundBannerView: UIView\n", "    let backgroundBannerView: UIView\n    private var visualGramBannerMediaView: VisualGramBannerMediaView?\n")
    replace_once(header, "        if let profileGiftsContext, let peer {\n", """        if let peer {
            let appearance = VisualGramLocalAppearance.shared.appearance(accountId: self.context.account.peerId, targetPeerId: peer.id)
            if appearance.enabled && (appearance.localBanner != nil || appearance.localBannerMedia != nil) {
                let mediaView: VisualGramBannerMediaView
                if let existing = self.visualGramBannerMediaView {
                    mediaView = existing
                } else {
                    mediaView = VisualGramBannerMediaView(frame: .zero)
                    self.backgroundBannerView.addSubview(mediaView)
                    self.visualGramBannerMediaView = mediaView
                }
                mediaView.configure(image: appearance.localBanner, media: appearance.localBannerMedia)
                mediaView.frame = CGRect(x: 0.0, y: bannerFrame.height - apparentBackgroundHeight, width: bannerFrame.width, height: apparentBackgroundHeight)
                mediaView.setPlaybackAllowed(apparentBackgroundHeight > 80.0 && backgroundBannerAlpha > 0.05)
            } else {
                self.visualGramBannerMediaView?.removeFromSuperview()
                self.visualGramBannerMediaView = nil
            }
        }

        if let profileGiftsContext, let peer {
""")
    replace_once(header, "        if let profileGiftsContext, let peer {\n", """        if let mediaView = self.visualGramBannerMediaView {
            self.backgroundBannerView.bringSubviewToFront(mediaView)
        }
        if let profileGiftsContext, let peer {
""")

    history = root / "submodules/TelegramUI/Sources/ChatHistoryEntriesForView.swift"
    replace_once(history, "    var count = 0\n    loop: for entry in view.entries {\n", """    var count = 0
    VisualGramMessageJournal.shared.observe(accountId: context.account.peerId, messages: view.entries.map { $0.message })
    let visualGramJournalEnabled = VisualGramLocalAppearance.shared.deviceSettings.messageHistoryEnabled
    let visualGramJournalEvents = location.peerId.map { VisualGramMessageJournal.shared.events(accountId: context.account.peerId, peerId: $0) } ?? []
    loop: for entry in view.entries {
""")
    replace_once(history, "        var message = entry.message.withAppliedEphemeralReplacementMessage()\n", """        var message = entry.message.withAppliedEphemeralReplacementMessage()
        message = VisualGramMessageJournal.shared.displayTimed(accountId: context.account.peerId, message: message)
        message = VisualGramLocalAppearance.shared.displayMessage(message)
        let visualGramEdit = visualGramJournalEvents.first { event in
            event.kind == .edited && event.messageId == message.id.id
                && (event.originalNamespace.map { $0 == message.id.namespace } ?? true)
        }
        if visualGramJournalEnabled && (visualGramEdit != nil || message.attributes.contains(where: { $0 is EditedMessageAttribute })) {
            let marker = visualGramEdit.flatMap { $0.previousText.isEmpty ? nil : $0.previousText }
                .map { "✏️ До изменения:\\n" + $0 } ?? "✏️ Изменено"
            message = message.withUpdatedText(message.text + (message.text.isEmpty ? "" : "\\n") + marker)
            message = message.withUpdatedAttributes(message.attributes.filter { !($0 is EditedMessageAttribute) })
            message = message.withUpdatedStableVersion(stableVersion: message.stableVersion &+ 1)
        }
        if let author = message.author,
           let displayed = VisualGramLocalAppearance.shared.displayPeer(EnginePeer(author), accountId: context.account.peerId),
           case let .user(localUser) = displayed {
            message = message.withUpdatedAuthor(localUser)
        }
        if VisualGramLocalAppearance.shared.deviceSettings.hides(message.text) {
            continue
        }
""")
    replace_once(history, "        if !dynamicAdMessages.isEmpty {\n", "        if !VisualGramLocalAppearance.shared.deviceSettings.hideSponsoredMessages && !dynamicAdMessages.isEmpty {\n")
    replace_once(history, "        if view.laterId == nil && !view.isLoading {\n            if !entries.isEmpty, case let .MessageEntry(lastMessage, _, _, _, _, _) = entries[entries.count - 1], let message = adMessage {\n", "        if !VisualGramLocalAppearance.shared.deviceSettings.hideSponsoredMessages && view.laterId == nil && !view.isLoading {\n            if !entries.isEmpty, case let .MessageEntry(lastMessage, _, _, _, _, _) = entries[entries.count - 1], let message = adMessage {\n")
    replace_once(history, "    if !groupMessages && reverseGroupedMessages {\n", """    // Deleted messages have left Postbox. Recreate a local row at the saved
    // timestamp, with archived media when its complete file was cached.
    if case .none = subject, let peerId = location.peerId,
       !view.isLoading {
        let timestamps = view.entries.map { $0.message.timestamp }
        let oldest = timestamps.min()
        let newest = timestamps.max()
        for event in visualGramJournalEvents where event.kind == .deleted {
            if !visualGramJournalEnabled && event.archivedMedia == nil { continue }
            guard let timestamp = event.originalTimestamp, let stableId = event.originalStableId else { continue }
            if let threadId = location.threadId, event.threadId != threadId { continue }
            if VisualGramLocalAppearance.shared.deviceSettings.hides(event.previousText) { continue }
            if view.entries.contains(where: { entry in
                entry.message.id.id == event.messageId && (event.originalNamespace.map { $0 == entry.message.id.namespace } ?? true)
            }) { continue }
            let isVisible: Bool
            if let oldest, let newest {
                isVisible = (timestamp >= oldest && timestamp <= newest)
                    || (view.laterId == nil && timestamp > newest)
                    || (view.earlierId == nil && timestamp < oldest)
            } else {
                isVisible = view.earlierId == nil && view.laterId == nil
            }
            if !isVisible { continue }
            let author: Peer? = event.authorId.flatMap { authorId in
                view.entries.lazy.compactMap { $0.message.author }.first { $0.id.toInt64() == authorId }
            } ?? (peerId.namespace == Namespaces.Peer.CloudUser ? chatPeer : nil)
            let authorPrefix = author == nil && peerId.namespace != Namespaces.Peer.CloudUser ? (event.authorName.map { $0 + ": " } ?? "") : ""
            let archivedMedia = VisualGramMessageJournal.shared.archivedMedia(event.archivedMedia)
            let body = event.previousText.isEmpty ? (archivedMedia == nil ? "Медиа больше недоступно" : "") : event.previousText
            let message = Message(
                stableId: stableId,
                stableVersion: 0,
                id: MessageId(peerId: peerId, namespace: Int32.max - 42, id: event.messageId),
                globallyUniqueId: nil,
                groupingKey: nil,
                groupInfo: nil,
                threadId: event.threadId,
                timestamp: timestamp,
                flags: event.wasIncoming == false ? [] : [.Incoming],
                tags: [], globalTags: [], localTags: [], customTags: [],
                forwardInfo: nil,
                author: author,
                text: "🗑️ Удалено" + (body.isEmpty ? "" : "\\n" + authorPrefix + body),
                attributes: [], media: archivedMedia.map { [$0] } ?? [],
                peers: SimpleDictionary<PeerId, Peer>(),
                associatedMessages: SimpleDictionary<MessageId, Message>(),
                associatedMessageIds: [], associatedMedia: [:],
                associatedThreadInfo: nil, associatedStories: [:]
            )
            entries.append(.MessageEntry(message, presentationData, false, nil, .none,
                ChatMessageEntryAttributes(rank: nil, isContact: false, contentTypeHint: .generic,
                    updatingMedia: nil, isPlaying: false, isCentered: false, authorStoryStats: nil,
                    displayContinueThreadFooter: false, pinToTop: false)))
        }
        entries.sort()
    }

    if !groupMessages && reverseGroupedMessages {
""")
    history_list = root / "submodules/TelegramUI/Sources/ChatHistoryListNode.swift"
    replace_once(history_list, "        let historyViewTransitionDisposable = (combineLatest(queue: messageViewQueue,\n            historyViewUpdate |> debug_measureTimeToFirstEvent(label: \"chatHistoryNode_historyViewUpdate\"),\n", """        let visualGramHistoryViewUpdate = combineLatest(historyViewUpdate, VisualGramLocalAppearance.shared.changes, VisualGramMessageJournal.shared.changes)
        |> map { update, _, _ in update }
        let historyViewTransitionDisposable = (combineLatest(queue: messageViewQueue,
            visualGramHistoryViewUpdate |> debug_measureTimeToFirstEvent(label: "chatHistoryNode_historyViewUpdate"),
""")
    replace_once(history_list, """                let alwaysDisplayTranscribeButton = ChatMessageItemAssociatedData.DisplayTranscribeButton(
""", """                if VisualGramLocalAppearance.shared.deviceSettings.allowProtectedScreenshots,
                   chatLocation.peerId?.namespace != Namespaces.Peer.SecretChat {
                    isCopyProtectionEnabled = false
                }
                let alwaysDisplayTranscribeButton = ChatMessageItemAssociatedData.DisplayTranscribeButton(
""")
    chat_node = root / "submodules/TelegramUI/Sources/ChatControllerNode.swift"
    replace_once(chat_node, """        let isSecret = self.chatPresentationInterfaceState.copyProtectionEnabled || self.chatLocation.peerId?.namespace == Namespaces.Peer.SecretChat || self.chatLocation.peerId?.isVerificationCodes == true
""", """        let isSecret = (self.chatPresentationInterfaceState.copyProtectionEnabled && !VisualGramLocalAppearance.shared.deviceSettings.allowProtectedScreenshots) || self.chatLocation.peerId?.namespace == Namespaces.Peer.SecretChat || self.chatLocation.peerId?.isVerificationCodes == true
""")
    protected_media = root / "submodules/TelegramUI/Components/Chat/ChatMessageInteractiveMediaNode/Sources/ChatMessageInteractiveMediaNode.swift"
    replace_once(protected_media, "captureProtected: associatedData.isCopyProtectionEnabled || message.isCopyProtected() || isExtendedMedia,",
                 "captureProtected: ((associatedData.isCopyProtectionEnabled || message.isCopyProtected()) && (!VisualGramLocalAppearance.shared.deviceSettings.allowProtectedScreenshots || message.id.peerId.namespace == Namespaces.Peer.SecretChat)) || isExtendedMedia,")
    replace_once(protected_media, "strongSelf.imageNode.captureProtected = associatedData.isCopyProtectionEnabled || message.isCopyProtected() || isExtendedMedia",
                 "strongSelf.imageNode.captureProtected = ((associatedData.isCopyProtectionEnabled || message.isCopyProtected()) && (!VisualGramLocalAppearance.shared.deviceSettings.allowProtectedScreenshots || message.id.peerId.namespace == Namespaces.Peer.SecretChat)) || isExtendedMedia")
    shared_player = root / "submodules/TelegramUI/Sources/SharedMediaPlayer.swift"
    replace_once(shared_player, "captureProtected: item.message.isCopyProtected(),",
                 "captureProtected: item.message.isCopyProtected() && (!VisualGramLocalAppearance.shared.deviceSettings.allowProtectedScreenshots || item.message.id.peerId.namespace == Namespaces.Peer.SecretChat),")
    chat_controller = root / "submodules/TelegramUI/Sources/ChatController.swift"
    replace_once(chat_controller, """                copyProtected: self.presentationInterfaceState.copyProtectionEnabled || self.presentationInterfaceState.myCopyProtectionEnabled,
""", """                copyProtected: (self.presentationInterfaceState.copyProtectionEnabled || self.presentationInterfaceState.myCopyProtectionEnabled) && !VisualGramLocalAppearance.shared.deviceSettings.allowProtectedScreenshots,
""")
    replace_once(chat_controller, """            let isSecret = strongSelf.presentationInterfaceState.copyProtectionEnabled || strongSelf.chatLocation.peerId?.namespace == Namespaces.Peer.SecretChat
""", """            let isSecret = (strongSelf.presentationInterfaceState.copyProtectionEnabled && !VisualGramLocalAppearance.shared.deviceSettings.allowProtectedScreenshots) || strongSelf.chatLocation.peerId?.namespace == Namespaces.Peer.SecretChat
""")
    pinned_panel = root / "submodules/TelegramUI/Sources/ChatPinnedMessageTitlePanelNode.swift"
    replace_once(pinned_panel, """        self.captureProtected = interfaceState.copyProtectionEnabled || interfaceState.myCopyProtectionEnabled
""", """        self.captureProtected = (interfaceState.copyProtectionEnabled || interfaceState.myCopyProtectionEnabled) && !VisualGramLocalAppearance.shared.deviceSettings.allowProtectedScreenshots
""")
    replace_once(chat_controller, """    func sendMessages(_ messages: [EnqueueMessage], media: Bool = false, postpone: Bool = false, commit: Bool = false) {
""", """    func sendMessages(_ messages: [EnqueueMessage], media: Bool = false, postpone: Bool = false, commit: Bool = false, visualGramConfirmed: Bool = false) {
        if VisualGramLocalAppearance.shared.deviceSettings.confirmMediaSends && !visualGramConfirmed {
            let kind: String? = messages.compactMap { message -> String? in
                guard case let .message(_, _, _, mediaReference, _, _, _, _, _, _) = message,
                      let file = mediaReference?.media as? TelegramMediaFile else { return nil }
                if file.isSticker { return "стикер" }
                if file.isAnimated || file.mimeType == "image/gif" { return "GIF" }
                return nil
            }.first
            if let kind {
                let alert = UIAlertController(title: "Отправить \\(kind)?", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
                alert.addAction(UIAlertAction(title: "Отправить", style: .default, handler: { [weak self] _ in
                    self?.sendMessages(messages, media: media, postpone: postpone, commit: commit, visualGramConfirmed: true)
                }))
                self.present(alert, animated: true)
                return
            }
        }
""")
    replace_once(chat_controller, "strongSelf.sendMessages(strongSelf.transformEnqueueMessages(messages, silentPosting: result.silentPosting, scheduleTime: result.time, repeatPeriod: result.repeatPeriod, postpone: postpone), commit: true)", "strongSelf.sendMessages(strongSelf.transformEnqueueMessages(messages, silentPosting: result.silentPosting, scheduleTime: result.time, repeatPeriod: result.repeatPeriod, postpone: postpone), commit: true, visualGramConfirmed: visualGramConfirmed)")
    recording = root / "submodules/TelegramUI/Sources/Chat/ChatControllerMediaRecording.swift"
    replace_once(recording, """        postpone: Bool = false
    ) {
        self.chatDisplayNode.updateRecordedMediaDeleted(false)
""", """        postpone: Bool = false,
        visualGramConfirmed: Bool = false
    ) {
        if !visualGramConfirmed && VisualGramLocalAppearance.shared.deviceSettings.confirmMediaSends,
           case .some(.audio) = self.presentationInterfaceState.interfaceState.mediaDraftState {
            let alert = UIAlertController(title: "Отправить голосовое сообщение?", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            alert.addAction(UIAlertAction(title: "Отправить", style: .default, handler: { [weak self] _ in
                self?.sendMediaRecording(silentPosting: silentPosting, scheduleTime: scheduleTime, repeatPeriod: repeatPeriod, viewOnce: viewOnce, messageEffect: messageEffect, postpone: postpone, visualGramConfirmed: true)
            }))
            self.present(alert, animated: true)
            return
        }
        self.chatDisplayNode.updateRecordedMediaDeleted(false)
""")
    app_delegate = root / "submodules/TelegramUI/Sources/AppDelegate.swift"
    for name in ["Premium", "PremiumTurbo", "PremiumBlack"]:
        replace_once(app_delegate, f'PresentationAppIcon(name: "{name}", imageName: "{name}", isPremium: true)',
                     f'PresentationAppIcon(name: "{name}", imageName: "{name}", isPremium: !VisualGramLocalAppearance.shared.deviceSettings.localPremiumPresentation)')

    chat_content = root / "submodules/TelegramUI/Sources/ChatControllerContentData.swift"
    replace_once(chat_content, "extension ChatControllerImpl {\n", """private func visualGramRenderedPeer(_ original: RenderedPeer?, accountId: PeerId) -> RenderedPeer? {
    guard let original else { return nil }
    var peers = original.peers
    for (id, peer) in original.peers {
        if let displayed = VisualGramLocalAppearance.shared.displayPeer(EnginePeer(peer), accountId: accountId),
           case let .user(localUser) = displayed {
            peers[id] = localUser
        }
    }
    return RenderedPeer(peerId: original.peerId, peers: peers, associatedMedia: original.associatedMedia)
}

extension ChatControllerImpl {
""")
    replace_count(chat_content, "strongSelf.state.renderedPeer = renderedPeer", "strongSelf.state.renderedPeer = visualGramRenderedPeer(renderedPeer, accountId: context.account.peerId)", 3)
    replace_once(chat_content, "self.state.renderedPeer = renderedPeer", "self.state.renderedPeer = visualGramRenderedPeer(renderedPeer, accountId: context.account.peerId)")

    context = root / "submodules/TelegramUI/Sources/Chat/ChatControllerOpenMessageContextMenu.swift"
    replace_once(context, "import AccountContext\n", "import AccountContext\nimport SaveToCameraRoll\n")
    replace_once(context, "    func openMessageContextMenu(message: EngineMessage, selectAll: Bool, node: ASDisplayNode, frame: CGRect, anyRecognizer: UIGestureRecognizer?, location: CGPoint?) -> Void {\n", """    func openMessageContextMenu(message: EngineMessage, selectAll: Bool, node: ASDisplayNode, frame: CGRect, anyRecognizer: UIGestureRecognizer?, location: CGPoint?) -> Void {
        // A journal tombstone is a local display row, not a server message.
        if message.id.namespace == Int32.max - 42 {
            guard let media = message._asMessage().media.first else { return }
            let alert = UIAlertController(title: "Сохранённая копия", message: nil, preferredStyle: .alert)
            if media is TelegramMediaImage || (media as? TelegramMediaFile)?.isVideo == true {
                alert.addAction(UIAlertAction(title: "Сохранить в Фото", style: .default, handler: { [weak self] _ in
                    self?.visualGramSaveInPhotos(message)
                }))
            }
            alert.addAction(UIAlertAction(title: "Отправить копию", style: .default, handler: { [weak self] _ in
                guard let self else { return }
                let share = self.context.sharedContext.makeShareScreen(context: self.context,
                    params: ShareControllerParams(subject: .media(.standalone(media: media), nil),
                        immediateExternalShare: true, updatedPresentationData: self.updatedPresentationData))
                self.present(share, in: .window(.root))
            }))
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            var presenter: UIViewController? = self.view.window?.rootViewController ?? self
            while let shown = presenter?.presentedViewController { presenter = shown }
            presenter?.present(alert, animated: true)
            return
        }
""")
    replace_once(context, """                let isSecret = self.presentationInterfaceState.copyProtectionEnabled || self.presentationInterfaceState.myCopyProtectionEnabled || self.chatLocation.peerId?.namespace == Namespaces.Peer.SecretChat
""", """                let isSecret = ((self.presentationInterfaceState.copyProtectionEnabled || self.presentationInterfaceState.myCopyProtectionEnabled) && !VisualGramLocalAppearance.shared.deviceSettings.allowProtectedScreenshots) || self.chatLocation.peerId?.namespace == Namespaces.Peer.SecretChat
""")
    replace_once(context, "extension ChatControllerImpl {\n", """extension ChatControllerImpl {
    private func visualGramSaveInPhotos(_ message: EngineMessage) {
        let raw = message._asMessage()
        guard let media = raw.media.first(where: { item in
            if item is TelegramMediaImage { return true }
            if let file = item as? TelegramMediaFile { return file.isVideo }
            return false
        }) else { return }
        let local = message.id.namespace == Int32.max - 42
            || VisualGramMessageJournal.shared.timedMedia(accountId: self.context.account.peerId, messageId: message.id) != nil
        let reference: AnyMediaReference = local ? .standalone(media: media)
            : .message(message: MessageReference(raw), media: media)
        let _ = saveToCameraRoll(context: self.context, userLocation: .peer(raw.id.peerId), mediaReference: reference).startStandalone()
    }

    private func visualGramEditLocalMessage(_ message: EngineMessage) {
        self.push(VisualGramMessageEditorController(context: self.context, message: message))
    }
""")
    replace_once(context, "                var actions = actions\n", """                var actions = actions
                let isVisualGramEditable = message.id.namespace != Int32.max - 42
                    && message.adAttribute == nil
                    && !message.media.contains(where: { $0 is TelegramMediaAction })
                if isVisualGramEditable {
                    let editTitle = message.effectivelyIncoming(self.context.account.peerId) ? "Изменить" : "Изменить локально"
                    let edit: ContextMenuItem = .action(ContextMenuActionItem(text: editTitle, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.actionSheet.primaryTextColor)
                    }, action: { [weak self] controller, _ in
                        controller?.dismiss(completion: { [weak self] in self?.visualGramEditLocalMessage(message) })
                    }))
                    var extra: [ContextMenuItem] = [.separator, edit]
                    if VisualGramLocalAppearance.shared.messageOverride(message.id) != nil {
                        extra.append(.action(ContextMenuActionItem(text: "Вернуть оригинал", icon: { _ in nil }, action: { controller, _ in
                            controller?.dismiss(completion: {
                                VisualGramLocalAppearance.shared.restoreMessage(message.id)
                            })
                        })))
                    }
                    switch actions.content {
                    case let .list(items): actions.content = .list(items + extra)
                    case let .twoLists(first, second): actions.content = .twoLists(first + extra, second)
                    case .custom: break
                    }
                }
                if message.media.contains(where: { item in
                    if item is TelegramMediaImage { return true }
                    if let file = item as? TelegramMediaFile { return file.isVideo }
                    return false
                }),
                   (message.attributes.contains(where: { $0 is AutoclearTimeoutMessageAttribute || $0 is AutoremoveTimeoutMessageAttribute })
                    || VisualGramMessageJournal.shared.timedMedia(accountId: self.context.account.peerId, messageId: message.id) != nil) {
                    let save: ContextMenuItem = .action(ContextMenuActionItem(text: "Сохранить в Фото", icon: { theme in
                        generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.actionSheet.primaryTextColor)
                    }, action: { [weak self] controller, _ in
                        controller?.dismiss(completion: { [weak self] in self?.visualGramSaveInPhotos(message) })
                    }))
                    switch actions.content {
                    case let .list(items): actions.content = .list(items + [.separator, save])
                    case let .twoLists(first, second): actions.content = .twoLists(first + [.separator, save], second)
                    case .custom: break
                    }
                }
                if let media = VisualGramMessageJournal.shared.timedMedia(accountId: self.context.account.peerId, messageId: message.id) {
                    let copy: ContextMenuItem = .action(ContextMenuActionItem(text: "Отправить сохранённую копию", icon: { _ in nil }, action: { [weak self] controller, _ in
                        controller?.dismiss(completion: { [weak self] in
                            guard let self else { return }
                            let share = self.context.sharedContext.makeShareScreen(context: self.context,
                                params: ShareControllerParams(subject: .media(.standalone(media: media), nil),
                                    immediateExternalShare: true, updatedPresentationData: self.updatedPresentationData))
                            self.present(share, in: .window(.root))
                        })
                    }))
                    switch actions.content {
                    case let .list(items): actions.content = .list(items + [.separator, copy])
                    case let .twoLists(first, second): actions.content = .twoLists(first + [.separator, copy], second)
                    case .custom: break
                    }
                }
""")


if __name__ == "__main__":
    apply(Path(sys.argv[1]).resolve())
    print("VisualGram local profile, banner, and message hooks applied.")
