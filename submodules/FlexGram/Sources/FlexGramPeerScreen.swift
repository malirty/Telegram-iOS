import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext

/// Edits the local appearance of one peer. Nothing here calls the Telegram engine.
public final class FlexGramPeerScreen: ViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private final class Node: ViewControllerTracingNode {
        private let accountId: Int64
        private let peerId: Int64
        private let scrollView = UIScrollView()
        private let stack = UIStackView()
        private let avatarView = UIImageView()
        private let nameField = UITextField()
        private let giftsLabel = UILabel()
        private let statusLabel = UILabel()
        private let kindButton = UIButton(type: .system)
        private let backgroundButton = UIButton(type: .system)
        private let patternButton = UIButton(type: .system)
        private let kinds = ["Звезда", "Роза", "Сердце"]
        private let backgrounds = ["Ночной", "Мятный", "Персиковый"]
        private let patterns = ["Искры", "Волны", "Точки"]
        private var kindIndex = 0
        private var backgroundIndex = 0
        private var patternIndex = 0
        var onPickAvatar: (() -> Void)?

        init(accountId: Int64, peerId: Int64, title: String) {
            self.accountId = accountId
            self.peerId = peerId
            super.init()
            self.backgroundColor = UIColor(rgb: 0x101116)
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.keyboardDismissMode = .interactive
            self.stack.axis = .vertical
            self.stack.spacing = 14
            self.stack.isLayoutMarginsRelativeArrangement = true
            self.stack.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 30, right: 16)

            self.addLabel(title, size: 26, color: .white)
            self.addLabel("Изменения видны только вам в FlexGram. Собеседник не получит их в Telegram.", size: 14, color: UIColor(white: 0.65, alpha: 1))
            self.avatarView.contentMode = .scaleAspectFill
            self.avatarView.clipsToBounds = true
            self.avatarView.layer.cornerRadius = 48
            self.avatarView.backgroundColor = UIColor(rgb: 0x343844)
            self.avatarView.frame = CGRect(x: 0, y: 0, width: 96, height: 96)
            self.avatarView.image = FlexGramOverrides.avatar(accountId: accountId, peerId: peerId)
            let avatarContainer = UIView()
            avatarContainer.heightAnchor.constraint(equalToConstant: 96).isActive = true
            avatarContainer.addSubview(self.avatarView)
            self.stack.addArrangedSubview(avatarContainer)
            self.stack.addArrangedSubview(self.makeButton("Выбрать локальную аватарку", action: #selector(self.pickAvatar)))
            self.stack.addArrangedSubview(self.makeButton("Вернуть исходную аватарку", action: #selector(self.clearAvatar)))

            self.nameField.text = FlexGramOverrides.name(accountId: accountId, peerId: peerId)
            self.nameField.placeholder = "Локальный ник собеседника"
            self.nameField.textColor = .white
            self.nameField.backgroundColor = UIColor(rgb: 0x1B1D25)
            self.nameField.layer.cornerRadius = 10
            self.nameField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
            self.nameField.leftViewMode = .always
            self.nameField.heightAnchor.constraint(equalToConstant: 44).isActive = true
            self.nameField.addTarget(self, action: #selector(self.nameChanged), for: .editingChanged)
            self.stack.addArrangedSubview(self.nameField)
            self.addLabel("Подарки в этом профиле", size: 18, color: UIColor(rgb: 0x77D6B3))
            self.giftsLabel.numberOfLines = 0
            self.giftsLabel.textColor = .white
            self.stack.addArrangedSubview(self.giftsLabel)
            self.addLabel("Создать подарок", size: 18, color: UIColor(rgb: 0x77D6B3))
            self.configureChoice(self.kindButton, action: #selector(self.nextKind))
            self.configureChoice(self.backgroundButton, action: #selector(self.nextBackground))
            self.configureChoice(self.patternButton, action: #selector(self.nextPattern))
            self.stack.addArrangedSubview(self.kindButton)
            self.stack.addArrangedSubview(self.backgroundButton)
            self.stack.addArrangedSubview(self.patternButton)
            self.stack.addArrangedSubview(self.makeButton("Добавить подарок в профиль · 100 ⭐", action: #selector(self.sendGift)))
            self.statusLabel.textColor = UIColor(white: 0.7, alpha: 1)
            self.statusLabel.numberOfLines = 0
            self.stack.addArrangedSubview(self.statusLabel)
            self.refresh()
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didLoad() {
            super.didLoad()
            self.view.addSubview(self.scrollView)
            self.scrollView.addSubview(self.stack)
        }

        func updateLayout(size: CGSize, navigationHeight: CGFloat) {
            self.scrollView.frame = CGRect(x: 0, y: navigationHeight, width: size.width, height: max(0, size.height - navigationHeight))
            let fit = self.stack.systemLayoutSizeFitting(CGSize(width: size.width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
            self.stack.frame = CGRect(x: 0, y: 0, width: size.width, height: max(fit.height, self.scrollView.bounds.height + 1))
            self.scrollView.contentSize = self.stack.bounds.size
        }

        func updateAvatar(_ image: UIImage?) { self.avatarView.image = image }

        private func addLabel(_ text: String, size: CGFloat, color: UIColor) {
            let label = UILabel()
            label.text = text
            label.font = .systemFont(ofSize: size, weight: .medium)
            label.textColor = color
            label.numberOfLines = 0
            self.stack.addArrangedSubview(label)
        }

        private func makeButton(_ title: String, action: Selector) -> UIButton {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.filled()
            configuration.title = title
            configuration.baseForegroundColor = UIColor(rgb: 0x101116)
            configuration.baseBackgroundColor = UIColor(rgb: 0x77D6B3)
            configuration.cornerStyle = .medium
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
            button.configuration = configuration
            button.addTarget(self, action: action, for: .touchUpInside)
            return button
        }

        private func configureChoice(_ button: UIButton, action: Selector) {
            button.contentHorizontalAlignment = .left
            var configuration = UIButton.Configuration.filled()
            configuration.baseForegroundColor = .white
            configuration.baseBackgroundColor = UIColor(rgb: 0x1B1D25)
            configuration.cornerStyle = .medium
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
            button.configuration = configuration
            button.addTarget(self, action: action, for: .touchUpInside)
        }

        private func refresh() {
            self.kindButton.configuration?.title = "Предмет: \(self.kinds[self.kindIndex])"
            self.backgroundButton.configuration?.title = "Фон: \(self.backgrounds[self.backgroundIndex])"
            self.patternButton.configuration?.title = "Узор: \(self.patterns[self.patternIndex])"
            let gifts = FlexGramOverrides.gifts(accountId: self.accountId, peerId: self.peerId)
            self.giftsLabel.text = gifts.isEmpty ? "Пока нет подарков" : gifts.map { "🎁 \($0.kind) · \($0.background) · \($0.pattern)" }.joined(separator: "\n")
            self.statusLabel.text = "Виртуальный баланс: \(FlexGramOverrides.virtualStars) ⭐ · \(String(format: "%.2f", FlexGramOverrides.virtualTon)) TON"
        }

        @objc private func pickAvatar() { self.onPickAvatar?() }
        @objc private func clearAvatar() {
            FlexGramOverrides.setAvatar(nil, accountId: self.accountId, peerId: self.peerId)
            self.updateAvatar(nil)
            self.statusLabel.text = "Исходная аватарка вернётся после повторного открытия профиля."
        }
        @objc private func nameChanged() { FlexGramOverrides.setName(self.nameField.text, accountId: self.accountId, peerId: self.peerId) }
        @objc private func nextKind() { self.kindIndex = (self.kindIndex + 1) % self.kinds.count; self.refresh() }
        @objc private func nextBackground() { self.backgroundIndex = (self.backgroundIndex + 1) % self.backgrounds.count; self.refresh() }
        @objc private func nextPattern() { self.patternIndex = (self.patternIndex + 1) % self.patterns.count; self.refresh() }
        @objc private func sendGift() {
            guard FlexGramOverrides.virtualStars >= 100 else {
                self.statusLabel.text = "Нужно 100 виртуальных Stars. Добавьте их в Настройки → Флекс."
                return
            }
            FlexGramOverrides.virtualStars -= 100
            FlexGramOverrides.addGift(FlexGramGift(kind: self.kinds[self.kindIndex], background: self.backgrounds[self.backgroundIndex], pattern: self.patterns[self.patternIndex]), accountId: self.accountId, peerId: self.peerId)
            self.refresh()
        }
    }

    private let accountId: Int64
    private let peerId: Int64
    private let peerTitle: String
    private let presentationData: PresentationData

    public init(context: AccountContext, peerId: Int64, peerTitle: String) {
        self.accountId = context.account.peerId.toInt64()
        self.peerId = peerId
        self.peerTitle = peerTitle
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = "Флекс · профиль"
    }

    required init(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var node: Node { self.displayNode as! Node }

    override public func loadDisplayNode() {
        let node = Node(accountId: self.accountId, peerId: self.peerId, title: self.peerTitle)
        node.onPickAvatar = { [weak self] in self?.pickAvatar() }
        self.displayNode = node
        super.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.node.updateLayout(size: layout.size, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY)
    }

    private func pickAvatar() {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        self.present(picker, animated: true, completion: nil)
    }

    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
        if let image {
            FlexGramOverrides.setAvatar(image, accountId: self.accountId, peerId: self.peerId)
            self.node.updateAvatar(FlexGramOverrides.avatar(accountId: self.accountId, peerId: self.peerId))
        }
        picker.dismiss(animated: true, completion: nil)
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
