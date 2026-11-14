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
    replace_once(state_updates, """            case let .DeleteMessagesWithGlobalIds(ids):
                var resourceIds: [MediaResourceId] = []
""", """            case let .DeleteMessagesWithGlobalIds(ids):
                VisualGramMessageJournal.shared.recordDeletedGlobalIds(accountId: accountPeerId, ids: ids)
                var resourceIds: [MediaResourceId] = []
""")
    replace_once(state_updates, """            case let .DeleteMessages(ids):
                _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: ids, manualAddMessageThreadStatsDifference: { id, add, remove in
""", """            case let .DeleteMessages(ids):
                VisualGramMessageJournal.shared.recordDeleted(accountId: accountPeerId, messages: ids.compactMap { transaction.getMessage($0) })
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
    replace_once(header, "    let backgroundBannerView: UIView\n", "    let backgroundBannerView: UIView\n    private var visualGramBannerView: UIImageView?\n")
    replace_once(header, "        if let profileGiftsContext, let peer {\n", """        if let peer {
            let appearance = VisualGramLocalAppearance.shared.appearance(accountId: self.context.account.peerId, targetPeerId: peer.id)
            if appearance.enabled, let banner = appearance.localBanner, let url = VisualGramLocalAppearance.imageURL(banner),
               FileManager.default.fileExists(atPath: url.path) {
                let imageView: UIImageView
                if let existing = self.visualGramBannerView {
                    imageView = existing
                } else {
                    imageView = UIImageView()
                    imageView.contentMode = .scaleAspectFill
                    imageView.clipsToBounds = true
                    self.backgroundBannerView.addSubview(imageView)
                    self.visualGramBannerView = imageView
                }
                if imageView.accessibilityIdentifier != banner.fileName {
                    imageView.image = UIImage(contentsOfFile: url.path)
                    imageView.accessibilityIdentifier = banner.fileName
                }
                imageView.frame = CGRect(x: 0.0, y: bannerFrame.height - apparentBackgroundHeight, width: bannerFrame.width, height: apparentBackgroundHeight)
            } else {
                self.visualGramBannerView?.removeFromSuperview()
                self.visualGramBannerView = nil
            }
        }

        if let profileGiftsContext, let peer {
""")

    history = root / "submodules/TelegramUI/Sources/ChatHistoryEntriesForView.swift"
    replace_once(history, "    var count = 0\n    loop: for entry in view.entries {\n", """    var count = 0
    VisualGramMessageJournal.shared.observe(accountId: context.account.peerId, messages: view.entries.map { $0.message })
    loop: for entry in view.entries {
""")
    replace_once(history, "        var message = entry.message.withAppliedEphemeralReplacementMessage()\n", """        var message = entry.message.withAppliedEphemeralReplacementMessage()
        message = VisualGramLocalAppearance.shared.displayMessage(message)
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
    history_list = root / "submodules/TelegramUI/Sources/ChatHistoryListNode.swift"
    replace_once(history_list, "        let historyViewTransitionDisposable = (combineLatest(queue: messageViewQueue,\n            historyViewUpdate |> debug_measureTimeToFirstEvent(label: \"chatHistoryNode_historyViewUpdate\"),\n", """        let visualGramHistoryViewUpdate = combineLatest(historyViewUpdate, VisualGramLocalAppearance.shared.changes)
        |> map { update, _ in update }
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
    replace_once(context, """                let isSecret = self.presentationInterfaceState.copyProtectionEnabled || self.presentationInterfaceState.myCopyProtectionEnabled || self.chatLocation.peerId?.namespace == Namespaces.Peer.SecretChat
""", """                let isSecret = ((self.presentationInterfaceState.copyProtectionEnabled || self.presentationInterfaceState.myCopyProtectionEnabled) && !VisualGramLocalAppearance.shared.deviceSettings.allowProtectedScreenshots) || self.chatLocation.peerId?.namespace == Namespaces.Peer.SecretChat
""")
    replace_once(context, "extension ChatControllerImpl {\n", """extension ChatControllerImpl {
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
""")


if __name__ == "__main__":
    apply(Path(sys.argv[1]).resolve())
    print("VisualGram local profile, banner, and message hooks applied.")
