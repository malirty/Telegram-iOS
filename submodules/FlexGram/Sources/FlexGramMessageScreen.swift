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
        private let scrollView = UIScrollView()
        private let stack = UIStackView()
        private let textView = UITextView()
        private let statusLabel = UILabel()

        init(accountId: Int64, messageId: String, originalText: String) {
            self.accountId = accountId
            self.messageId = messageId
            super.init()
            self.backgroundColor = UIColor(rgb: 0x101116)
            self.scrollView.keyboardDismissMode = .interactive
            self.stack.axis = .vertical
            self.stack.spacing = 14
            self.stack.isLayoutMarginsRelativeArrangement = true
            self.stack.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)

            let description = UILabel()
            description.text = "Этот текст изменится только в вашем FlexGram. Собеседник увидит исходное сообщение."
            description.textColor = UIColor(white: 0.7, alpha: 1)
            description.numberOfLines = 0
            self.stack.addArrangedSubview(description)

            self.textView.text = FlexGramOverrides.messageText(accountId: accountId, messageId: messageId) ?? originalText
            self.textView.font = .systemFont(ofSize: 17)
            self.textView.textColor = .white
            self.textView.backgroundColor = UIColor(rgb: 0x1B1D25)
            self.textView.layer.cornerRadius = 10
            self.textView.heightAnchor.constraint(equalToConstant: 180).isActive = true
            self.stack.addArrangedSubview(self.textView)
            self.stack.addArrangedSubview(self.makeButton("Сохранить локально", action: #selector(self.save)))
            self.stack.addArrangedSubview(self.makeButton("Показать исходное сообщение", action: #selector(self.reset)))
            self.statusLabel.numberOfLines = 0
            self.statusLabel.textColor = UIColor(white: 0.7, alpha: 1)
            self.stack.addArrangedSubview(self.statusLabel)
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

        @objc private func save() {
            FlexGramOverrides.setMessageText(self.textView.text, accountId: self.accountId, messageId: self.messageId)
            self.statusLabel.text = "Сохранено. Откройте чат заново, чтобы увидеть локальный текст."
            self.textView.resignFirstResponder()
        }

        @objc private func reset() {
            FlexGramOverrides.setMessageText(nil, accountId: self.accountId, messageId: self.messageId)
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
        self.displayNode = Node(accountId: self.accountId, messageId: self.messageId, originalText: self.originalText)
        super.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.node.updateLayout(size: layout.size, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY)
    }
}
