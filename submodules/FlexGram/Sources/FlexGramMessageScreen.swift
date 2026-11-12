import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext

/// Replaces the rendered text of one message on this device. It never edits or sends a message.
public final class FlexGramMessageScreen: ViewController {
    private final class Node: ViewControllerTracingNode {
        private let accountId: Int64
        private let messageId: String
        private let originalText: String
        private let presentationData: PresentationData
        private let scrollView = UIScrollView()
        private let stack = UIStackView()
        private let textView = UITextView()
        private let statusLabel = UILabel()

        init(accountId: Int64, messageId: String, originalText: String, presentationData: PresentationData) {
            self.accountId = accountId
            self.messageId = messageId
            self.originalText = originalText
            self.presentationData = presentationData
            super.init()
            let colors = presentationData.theme.list
            self.backgroundColor = colors.plainBackgroundColor
            self.scrollView.keyboardDismissMode = .interactive
            self.scrollView.alwaysBounceVertical = true
            self.stack.axis = .vertical
            self.stack.spacing = 16
            self.stack.isLayoutMarginsRelativeArrangement = true
            self.stack.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 32, right: 16)

            let title = UILabel()
            title.text = "Сообщение"
            title.font = .systemFont(ofSize: 28, weight: .bold)
            title.textColor = colors.itemPrimaryTextColor
            self.stack.addArrangedSubview(title)

            let description = UILabel()
            description.text = "Этот текст изменится только в вашем FlexGram. Собеседник увидит исходное сообщение."
            description.font = .systemFont(ofSize: 14)
            description.textColor = colors.itemSecondaryTextColor
            description.numberOfLines = 0
            self.stack.addArrangedSubview(description)

            self.textView.text = FlexGramOverrides.messageText(accountId: accountId, messageId: messageId) ?? originalText
            self.textView.font = .systemFont(ofSize: 17)
            self.textView.textColor = colors.itemPrimaryTextColor
            self.textView.tintColor = colors.itemAccentColor
            self.textView.backgroundColor = colors.itemBlocksBackgroundColor
            self.textView.layer.cornerRadius = 14
            self.textView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
            self.textView.heightAnchor.constraint(equalToConstant: 180).isActive = true
            self.stack.addArrangedSubview(self.textView)
            self.stack.addArrangedSubview(self.makeButton("Сохранить локально", primary: true, action: #selector(self.save)))
            self.stack.addArrangedSubview(self.makeButton("Показать исходное сообщение", primary: false, action: #selector(self.reset)))
            self.statusLabel.numberOfLines = 0
            self.statusLabel.font = .systemFont(ofSize: 14)
            self.statusLabel.textColor = colors.itemSecondaryTextColor
            self.stack.addArrangedSubview(self.statusLabel)
        }

        override func didLoad() {
            super.didLoad()
            self.view.addSubview(self.scrollView)
            self.stack.translatesAutoresizingMaskIntoConstraints = false
            self.scrollView.addSubview(self.stack)
            NSLayoutConstraint.activate([
                self.stack.leadingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.leadingAnchor),
                self.stack.trailingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.trailingAnchor),
                self.stack.topAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.topAnchor),
                self.stack.bottomAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.bottomAnchor),
                self.stack.widthAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.widthAnchor)
            ])
        }

        func updateLayout(size: CGSize, navigationHeight: CGFloat) {
            self.scrollView.frame = CGRect(x: 0, y: navigationHeight, width: size.width, height: max(0, size.height - navigationHeight))
        }

        private func makeButton(_ title: String, primary: Bool, action: Selector) -> UIButton {
            let button = UIButton(type: .system)
            var configuration = primary ? UIButton.Configuration.filled() : UIButton.Configuration.plain()
            configuration.title = title
            configuration.baseForegroundColor = primary ? .white : self.presentationData.theme.list.itemAccentColor
            configuration.baseBackgroundColor = primary ? self.presentationData.theme.list.itemAccentColor : .clear
            configuration.cornerStyle = .medium
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
            button.configuration = configuration
            button.addTarget(self, action: action, for: .touchUpInside)
            return button
        }

        @objc private func save() {
            FlexGramOverrides.setMessageText(self.textView.text, accountId: self.accountId, messageId: self.messageId)
            self.statusLabel.text = "Сохранено. Откройте чат заново, чтобы увидеть локальный текст."
            self.textView.resignFirstResponder()
        }

        @objc private func reset() {
            FlexGramOverrides.setMessageText(nil, accountId: self.accountId, messageId: self.messageId)
            self.textView.text = self.originalText
            self.statusLabel.text = "Исходное сообщение появится после повторного открытия чата."
            self.textView.resignFirstResponder()
        }
    }

    private let accountId: Int64
    private let messageId: String
    private let originalText: String
    private let presentationData: PresentationData

    public init(context: AccountContext, messageId: String, originalText: String) {
        self.accountId = context.account.peerId.toInt64()
        self.messageId = messageId
        self.originalText = originalText
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = "Флекс · сообщение"
    }

    required init(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var node: Node { self.displayNode as! Node }

    override public func loadDisplayNode() {
        self.displayNode = Node(accountId: self.accountId, messageId: self.messageId, originalText: self.originalText, presentationData: self.presentationData)
        super.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.node.updateLayout(size: layout.size, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY)
    }
}
