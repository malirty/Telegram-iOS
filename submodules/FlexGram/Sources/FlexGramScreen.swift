import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext

/// Client-only presentation overrides. Telegram account and message records are never written.
public enum FlexGramLocalSettings {
    private static let defaults = UserDefaults.standard

    public static var profileDisplayNameOverride: String? {
        get { Self.nonEmptyValue(forKey: "flexgram.profileDisplayName") }
        set { Self.store(newValue, forKey: "flexgram.profileDisplayName") }
    }

    public static var outgoingAuthorNameOverride: String? {
        get { Self.nonEmptyValue(forKey: "flexgram.outgoingAuthorName") }
        set { Self.store(newValue, forKey: "flexgram.outgoingAuthorName") }
    }

    private static func nonEmptyValue(forKey key: String) -> String? {
        guard let value = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func store(_ value: String?, forKey key: String) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            defaults.set(String(trimmed.prefix(64)), forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

private final class FlexGramChoiceButton: UIButton {
    var onPress: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func pressed() {
        self.onPress?()
    }
}

private struct FlexGramGift: Codable {
    var kind: String
    var background: String
    var pattern: String
}

private enum FlexGramLocalStore {
    private static let defaults = UserDefaults.standard

    static var stars: Int {
        get { max(0, defaults.integer(forKey: "flexgram.virtualStars")) }
        set { defaults.set(max(0, newValue), forKey: "flexgram.virtualStars") }
    }

    static var ton: Double {
        get { max(0, defaults.double(forKey: "flexgram.virtualTon")) }
        set { defaults.set(max(0, newValue), forKey: "flexgram.virtualTon") }
    }

    static var displayName: String {
        get { FlexGramLocalSettings.profileDisplayNameOverride ?? "Мой профиль" }
        set { FlexGramLocalSettings.profileDisplayNameOverride = newValue }
    }

    static var messageAlias: String {
        get { FlexGramLocalSettings.outgoingAuthorNameOverride ?? "Имя отправителя" }
        set { FlexGramLocalSettings.outgoingAuthorNameOverride = newValue }
    }

    static var gifts: [FlexGramGift] {
        get {
            guard let data = defaults.data(forKey: "flexgram.gifts"),
                  let gifts = try? JSONDecoder().decode([FlexGramGift].self, from: data) else {
                return []
            }
            return gifts
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: "flexgram.gifts")
        }
    }
}

/// A client-only playground. Values are persisted in this installation and are never sent to Telegram.
public final class FlexGramScreen: ViewController {
    private final class Node: ViewControllerTracingNode {
        private let content = UIScrollView()
        private let stack = UIStackView()
        private let starsLabel = UILabel()
        private let tonLabel = UILabel()
        private var nameField = UITextField()
        private var messageField = UITextField()
        private let previewLabel = UILabel()
        private let giftsLabel = UILabel()
        private var giftKind = "Звезда"
        private var giftBackground = "Ночной"
        private var giftPattern = "Искры"

        override init() {
            super.init()
            self.backgroundColor = UIColor(rgb: 0x101116)
            self.content.alwaysBounceVertical = true
            self.content.keyboardDismissMode = .interactive
            self.stack.axis = .vertical
            self.stack.spacing = 14
            self.stack.isLayoutMarginsRelativeArrangement = true
            self.stack.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 28, right: 16)
            self.starsLabel.textColor = .white
            self.tonLabel.textColor = .white
            self.giftsLabel.textColor = UIColor(white: 0.82, alpha: 1)

            self.addTitle("Флекс", size: 30, weight: .bold)
            self.addText("Локальная песочница FlexGram. Балансы, профиль и подарки существуют только на этом устройстве.", secondary: true)
            self.addCard(title: "Виртуальный баланс")
            self.stack.addArrangedSubview(self.starsLabel)
            self.stack.addArrangedSubview(self.makeCounterRow(title: "Stars", decrement: #selector(self.decreaseStars), increment: #selector(self.increaseStars)))
            self.stack.addArrangedSubview(self.tonLabel)
            self.stack.addArrangedSubview(self.makeCounterRow(title: "TON", decrement: #selector(self.decreaseTon), increment: #selector(self.increaseTon)))
            self.addText("Демо-значения: их нельзя потратить или отправить.", secondary: true)

            self.addCard(title: "Профиль и сообщения · локальный предпросмотр")
            self.nameField = self.makeTextField(placeholder: "Локальное имя профиля", value: FlexGramLocalSettings.profileDisplayNameOverride ?? "")
            self.messageField = self.makeTextField(placeholder: "Локальное имя автора", value: FlexGramLocalSettings.outgoingAuthorNameOverride ?? "")
            self.stack.addArrangedSubview(self.nameField)
            self.stack.addArrangedSubview(self.messageField)
            self.previewLabel.text = "\(FlexGramLocalStore.displayName)\n\(FlexGramLocalStore.messageAlias) · только предпросмотр"
            self.previewLabel.textColor = .white
            self.previewLabel.numberOfLines = 0
            self.stack.addArrangedSubview(self.previewLabel)
            self.nameField.addTarget(self, action: #selector(self.profileChanged), for: .editingChanged)
            self.messageField.addTarget(self, action: #selector(self.messageChanged), for: .editingChanged)

            self.addCard(title: "Конструктор подарка")
            self.addChoiceRow("Предмет", values: ["Звезда", "Роза", "Сердце"], selected: { [weak self] in self?.giftKind ?? "Звезда" }, update: { [weak self] in self?.giftKind = $0 })
            self.addChoiceRow("Фон", values: ["Ночной", "Мятный", "Персиковый"], selected: { [weak self] in self?.giftBackground ?? "Ночной" }, update: { [weak self] in self?.giftBackground = $0 })
            self.addChoiceRow("Узор", values: ["Искры", "Волны", "Точки"], selected: { [weak self] in self?.giftPattern ?? "Искры" }, update: { [weak self] in self?.giftPattern = $0 })
            self.stack.addArrangedSubview(self.giftsLabel)
            self.stack.addArrangedSubview(self.makeButton("Сохранить подарок локально", action: #selector(self.saveGift)))
            self.refreshValues()
            self.refreshGifts()
        }

        override func didLoad() {
            super.didLoad()
            self.view.addSubview(self.content)
            self.content.addSubview(self.stack)
        }

        func updateLayout(size: CGSize, navigationHeight: CGFloat) {
            self.content.frame = CGRect(x: 0, y: navigationHeight, width: size.width, height: max(0, size.height - navigationHeight))
            let width = self.content.bounds.width
            let fitting = self.stack.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
            self.stack.frame = CGRect(origin: .zero, size: CGSize(width: width, height: max(fitting.height, self.content.bounds.height + 1)))
            self.content.contentSize = self.stack.bounds.size
        }

        private func addTitle(_ text: String, size: CGFloat, weight: UIFont.Weight) {
            let label = UILabel()
            label.text = text
            label.textColor = .white
            label.font = .systemFont(ofSize: size, weight: weight)
            self.stack.addArrangedSubview(label)
        }

        private func addText(_ text: String, secondary: Bool) {
            let label = UILabel()
            label.text = text
            label.numberOfLines = 0
            label.textColor = secondary ? UIColor(white: 0.62, alpha: 1) : .white
            label.font = .systemFont(ofSize: secondary ? 14 : 16, weight: .regular)
            self.stack.addArrangedSubview(label)
        }

        private func addCard(title: String) {
            let label = UILabel()
            label.text = title
            label.textColor = UIColor(rgb: 0x77D6B3)
            label.font = .systemFont(ofSize: 17, weight: .semibold)
            label.backgroundColor = UIColor(rgb: 0x1B1D25)
            label.layer.cornerRadius = 12
            label.layer.masksToBounds = true
            label.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 8, right: 12)
            self.stack.addArrangedSubview(label)
        }

        private func makeCounterRow(title: String, decrement: Selector, increment: Selector) -> UIView {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8
            row.alignment = .center
            let label = UILabel()
            label.text = title
            label.textColor = .white
            row.addArrangedSubview(label)
            row.addArrangedSubview(UIView())
            row.addArrangedSubview(self.makeButton("−", action: decrement))
            row.addArrangedSubview(self.makeButton("+", action: increment))
            return row
        }

        private func makeButton(_ title: String, action: Selector) -> UIButton {
            let button = FlexGramChoiceButton(type: .system)
            button.setTitle(title, for: .normal)
            button.setTitleColor(UIColor(rgb: 0x101116), for: .normal)
            button.backgroundColor = UIColor(rgb: 0x77D6B3)
            button.layer.cornerRadius = 10
            button.contentEdgeInsets = UIEdgeInsets(top: 9, left: 14, bottom: 9, right: 14)
            button.addTarget(self, action: action, for: .touchUpInside)
            return button
        }

        private func makeTextField(placeholder: String, value: String) -> UITextField {
            let field = UITextField()
            field.text = value
            field.placeholder = placeholder
            field.textColor = .white
            field.tintColor = UIColor(rgb: 0x77D6B3)
            field.backgroundColor = UIColor(rgb: 0x1B1D25)
            field.layer.cornerRadius = 10
            field.setLeftPadding(12)
            field.heightAnchor.constraint(equalToConstant: 44).isActive = true
            return field
        }

        private func addChoiceRow(_ title: String, values: [String], selected: @escaping () -> String, update: @escaping (String) -> Void) {
            let button = FlexGramChoiceButton(type: .system)
            button.contentHorizontalAlignment = .left
            button.titleLabel?.numberOfLines = 0
            button.setTitleColor(.white, for: .normal)
            func updateTitle() { button.setTitle("\(title): \(selected())  ·  Нажмите, чтобы сменить", for: .normal) }
            updateTitle()
            button.backgroundColor = UIColor(rgb: 0x1B1D25)
            button.layer.cornerRadius = 10
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            button.onPress = {
                let currentIndex = values.firstIndex(of: selected()) ?? 0
                update(values[(currentIndex + 1) % values.count])
                updateTitle()
            }
            self.stack.addArrangedSubview(button)
        }

        private func refreshValues() {
            self.starsLabel.text = "⭐  \(FlexGramLocalStore.stars)  ·  виртуально"
            self.tonLabel.text = "◆  \(String(format: "%.2f", FlexGramLocalStore.ton))  ·  виртуально"
        }

        private func refreshGifts() {
            let descriptions = FlexGramLocalStore.gifts.map { "\($0.kind) · \($0.background) · \($0.pattern)" }
            self.giftsLabel.text = descriptions.isEmpty ? "Пока нет сохранённых подарков" : "Мои подарки:\n" + descriptions.joined(separator: "\n")
        }

        @objc private func increaseStars() { FlexGramLocalStore.stars += 100; self.refreshValues() }
        @objc private func decreaseStars() { FlexGramLocalStore.stars = max(0, FlexGramLocalStore.stars - 100); self.refreshValues() }
        @objc private func increaseTon() { FlexGramLocalStore.ton += 1; self.refreshValues() }
        @objc private func decreaseTon() { FlexGramLocalStore.ton = max(0, FlexGramLocalStore.ton - 1); self.refreshValues() }
        @objc private func profileChanged() {
            FlexGramLocalStore.displayName = self.nameField.text ?? ""
            self.updatePreview()
        }
        @objc private func messageChanged() {
            FlexGramLocalStore.messageAlias = self.messageField.text ?? ""
            self.updatePreview()
        }
        private func updatePreview() {
            self.previewLabel.text = "\(FlexGramLocalStore.displayName)\n\(FlexGramLocalStore.messageAlias) · только предпросмотр"
        }
        @objc private func saveGift() {
            var gifts = FlexGramLocalStore.gifts
            gifts.append(FlexGramGift(kind: self.giftKind, background: self.giftBackground, pattern: self.giftPattern))
            FlexGramLocalStore.gifts = gifts
            self.refreshGifts()
        }
    }

    private let context: AccountContext
    private var presentationData: PresentationData

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = "FlexGram"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var node: Node { self.displayNode as! Node }

    override public func loadDisplayNode() {
        self.displayNode = Node()
        super.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.node.updateLayout(size: layout.size, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY)
    }
}

private extension UITextField {
    func setLeftPadding(_ amount: CGFloat) {
        let spacer = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: 1))
        self.leftView = spacer
        self.leftViewMode = .always
    }
}
