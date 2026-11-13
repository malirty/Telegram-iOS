"""Attach local VisualGram profile and message presentation to the pinned Telegram UI."""
from pathlib import Path
import sys


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
    replace_once(history, "        var message = entry.message.withAppliedEphemeralReplacementMessage()\n", """        var message = entry.message.withAppliedEphemeralReplacementMessage()
        message = VisualGramLocalAppearance.shared.displayMessage(message)
        if let author = message.author,
           let displayed = VisualGramLocalAppearance.shared.displayPeer(EnginePeer(author), accountId: context.account.peerId),
           case let .user(localUser) = displayed {
            message = message.withUpdatedAuthor(localUser)
        }
""")

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
    replace_once(context, "extension ChatControllerImpl {\n", """private final class VisualGramMessagePhotoPicker: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    static let shared = VisualGramMessagePhotoPicker()
    private var completion: ((UIImage) -> Void)?

    func choose(from presenter: UIViewController, completion: @escaping (UIImage) -> Void) {
        self.completion = completion
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        presenter.present(picker, animated: true)
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.completion = nil
        picker.dismiss(animated: true)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[.originalImage] as? UIImage
        let completion = self.completion
        self.completion = nil
        picker.dismiss(animated: true) { if let image { completion?(image) } }
    }
}

extension ChatControllerImpl {
    private func visualGramEditLocalMessage(_ message: EngineMessage) {
        let original = message._asMessage()
        let local = VisualGramLocalAppearance.shared.messageOverride(original.id)
        let alert = UIAlertController(title: "Изменить сообщение", message: "Изменение видно только в этом приложении.", preferredStyle: .alert)
        alert.addTextField { field in
            field.text = local?.text ?? original.text
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { [weak alert] _ in
            let text = alert?.textFields?.first?.text ?? ""
            VisualGramLocalAppearance.shared.updateMessage(original.id) { $0.text = text }
        }))
        alert.addAction(UIAlertAction(title: "Добавить фото", style: .default, handler: { [weak self, weak alert] _ in
            let text = alert?.textFields?.first?.text ?? original.text
            VisualGramLocalAppearance.shared.updateMessage(original.id) { $0.text = text }
            guard let presenter = self?.view.window?.rootViewController else { return }
            DispatchQueue.main.async {
                VisualGramMessagePhotoPicker.shared.choose(from: presenter) { image in
                    guard let saved = VisualGramLocalAppearance.saveImage(image) else { return }
                    VisualGramLocalAppearance.shared.updateMessage(original.id) { $0.image = saved }
                }
            }
        }))
        if local?.image != nil {
            alert.addAction(UIAlertAction(title: "Убрать фото", style: .destructive, handler: { _ in
                VisualGramLocalAppearance.shared.updateMessage(original.id) { $0.image = nil }
            }))
        }
        self.view.window?.rootViewController?.present(alert, animated: true)
    }
""")
    replace_once(context, "                var actions = actions\n", """                var actions = actions
                let isVisualGramEditable = message.effectivelyIncoming(self.context.account.peerId)
                    && message.id.namespace != Int32.max - 42
                    && message.adAttribute == nil
                    && !message.media.contains(where: { $0 is TelegramMediaAction })
                if isVisualGramEditable {
                    let edit: ContextMenuItem = .action(ContextMenuActionItem(text: "Изменить", icon: { theme in
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
