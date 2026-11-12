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

/// A local-only wallet and entry point for profile editing and gift copies.
public final class FlexGramScreen: ViewController {
    private final class Node: ViewControllerTracingNode {
        private let presentationData: PresentationData
        private let scrollView = UIScrollView()
        private let stack = UIStackView()
        private let starsLabel = UILabel()
        private let tonLabel = UILabel()
        private let nameField = UITextField()
        private let authorField = UITextField()
        private let profileNote = UILabel()
        var onEditStars: (() -> Void)?
        var onEditTon: (() -> Void)?
        var onOpenMyProfile: (() -> Void)?

        init(presentationData: PresentationData) {
            self.presentationData = presentationData
            super.init()
            let colors = presentationData.theme.list
            self.backgroundColor = colors.plainBackgroundColor
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.keyboardDismissMode = .interactive
            self.stack.axis = .vertical
            self.stack.spacing = 18.0
            self.stack.isLayoutMarginsRelativeArrangement = true
            self.stack.layoutMargins = UIEdgeInsets(top: 20.0, left: 16.0, bottom: 32.0, right: 16.0)

            let titleLabel = UILabel()
            titleLabel.text = "Флекс"
            titleLabel.font = .systemFont(ofSize: 30.0, weight: .bold)
            titleLabel.textColor = colors.itemPrimaryTextColor
            self.stack.addArrangedSubview(titleLabel)
            self.addDescription("Локальные настройки профиля, подарков и виртуального баланса. Они видны только в этом приложении.")

            self.addSectionTitle("ВИРТУАЛЬНЫЙ БАЛАНС")
            let walletCard = self.makeGroup()
            let starsRow = self.makeBalanceRow(symbol: "star.fill", valueLabel: self.starsLabel, decrement: #selector(self.decreaseStars), increment: #selector(self.increaseStars), edit: #selector(self.editStars))
            walletCard.addArrangedSubview(starsRow)
            walletCard.addArrangedSubview(self.separator())
            let tonRow = self.makeBalanceRow(symbol: "diamond.fill", valueLabel: self.tonLabel, decrement: #selector(self.decreaseTon), increment: #selector(self.increaseTon), edit: #selector(self.editTon))
            walletCard.addArrangedSubview(tonRow)
            self.stack.addArrangedSubview(walletCard)
            self.addDescription("Нажмите на сумму, чтобы задать любое значение. При локальном подарке списываются 100 виртуальных Stars. Настоящий баланс Telegram не меняется.")

            self.addSectionTitle("ЛОКАЛЬНЫЙ ПРОФИЛЬ")
            let profileCard = self.makeGroup()
            self.configureField(self.nameField, placeholder: "Имя в моём профиле", text: FlexGramLocalSettings.profileDisplayNameOverride)
            self.configureField(self.authorField, placeholder: "Подпись автора в сообщениях", text: FlexGramLocalSettings.outgoingAuthorNameOverride)
            self.nameField.addTarget(self, action: #selector(self.profileChanged), for: .editingChanged)
            self.authorField.addTarget(self, action: #selector(self.authorChanged), for: .editingChanged)
            profileCard.addArrangedSubview(self.nameField)
            profileCard.addArrangedSubview(self.authorField)
            self.profileNote.text = "Изменения профиля и сообщений появятся после повторного открытия соответствующего экрана."
            self.profileNote.font = .systemFont(ofSize: 13.0)
            self.profileNote.textColor = colors.itemSecondaryTextColor
            self.profileNote.numberOfLines = 0
            profileCard.addArrangedSubview(self.profileNote)
            profileCard.addArrangedSubview(self.makePrimaryButton("Открыть мои локальные подарки", action: #selector(self.openMyProfile)))
            self.stack.addArrangedSubview(profileCard)

            self.addSectionTitle("КАК ЭТО РАБОТАЕТ")
            let infoCard = self.makeGroup()
            let info = UILabel()
            info.text = "Выберите изображение из каталога Telegram в локальном профиле. Подарок появится только в вашем FlexGram и не будет доставлен другому человеку. Реальных платежей нет."
            info.font = .systemFont(ofSize: 14.0)
            info.textColor = colors.itemSecondaryTextColor
            info.numberOfLines = 0
            infoCard.addArrangedSubview(info)
            self.stack.addArrangedSubview(infoCard)
            self.refreshValues()
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
            self.scrollView.frame = CGRect(x: 0.0, y: navigationHeight, width: size.width, height: max(0.0, size.height - navigationHeight))
        }

        func refreshValues() {
            self.starsLabel.text = "\(FlexGramOverrides.virtualStars) Stars"
            self.tonLabel.text = "\(String(format: "%.2f", FlexGramOverrides.virtualTon)) TON"
        }

        private func makeGroup() -> UIStackView {
            let group = UIStackView()
            group.axis = .vertical
            group.spacing = 12.0
            group.isLayoutMarginsRelativeArrangement = true
            group.layoutMargins = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 16.0, right: 16.0)
            group.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
            group.layer.cornerRadius = 14.0
            return group
        }

        private func addSectionTitle(_ text: String) {
            let label = UILabel()
            label.text = text
            label.font = .systemFont(ofSize: 13.0, weight: .semibold)
            label.textColor = self.presentationData.theme.list.itemSecondaryTextColor
            label.numberOfLines = 0
            self.stack.addArrangedSubview(label)
        }

        private func addDescription(_ text: String) {
            let label = UILabel()
            label.text = text
            label.font = .systemFont(ofSize: 14.0)
            label.textColor = self.presentationData.theme.list.itemSecondaryTextColor
            label.numberOfLines = 0
            self.stack.addArrangedSubview(label)
        }

        private func separator() -> UIView {
            let line = UIView()
            line.backgroundColor = self.presentationData.theme.list.itemBlocksSeparatorColor
            line.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
            return line
        }

        private func makeBalanceRow(symbol: String, valueLabel: UILabel, decrement: Selector, increment: Selector, edit: Selector) -> UIView {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8.0
            row.alignment = .center
            let icon = UIImageView(image: UIImage(systemName: symbol))
            icon.tintColor = self.presentationData.theme.list.itemAccentColor
            icon.contentMode = .scaleAspectFit
            icon.widthAnchor.constraint(equalToConstant: 28.0).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 28.0).isActive = true
            row.addArrangedSubview(icon)
            valueLabel.font = .systemFont(ofSize: 20.0, weight: .semibold)
            valueLabel.textColor = self.presentationData.theme.list.itemPrimaryTextColor
            valueLabel.adjustsFontSizeToFitWidth = true
            valueLabel.minimumScaleFactor = 0.75
            let amountButton = UIButton(type: .system)
            amountButton.contentHorizontalAlignment = .left
            amountButton.addSubview(valueLabel)
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                valueLabel.leadingAnchor.constraint(equalTo: amountButton.leadingAnchor),
                valueLabel.trailingAnchor.constraint(equalTo: amountButton.trailingAnchor),
                valueLabel.topAnchor.constraint(equalTo: amountButton.topAnchor),
                valueLabel.bottomAnchor.constraint(equalTo: amountButton.bottomAnchor)
            ])
            amountButton.addTarget(self, action: edit, for: .touchUpInside)
            amountButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44.0).isActive = true
            row.addArrangedSubview(amountButton)
            row.addArrangedSubview(self.makeStepButton("−", action: decrement))
            row.addArrangedSubview(self.makeStepButton("+", action: increment))
            return row
        }

        private func makeStepButton(_ title: String, action: Selector) -> UIButton {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 23.0, weight: .medium)
            button.setTitleColor(self.presentationData.theme.list.itemAccentColor, for: .normal)
            button.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            button.layer.cornerRadius = 10.0
            button.widthAnchor.constraint(equalToConstant: 44.0).isActive = true
            button.heightAnchor.constraint(equalToConstant: 44.0).isActive = true
            button.addTarget(self, action: action, for: .touchUpInside)
            return button
        }

        private func makePrimaryButton(_ title: String, action: Selector) -> UIButton {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.filled()
            configuration.title = title
            configuration.baseForegroundColor = .white
            configuration.baseBackgroundColor = self.presentationData.theme.list.itemAccentColor
            configuration.cornerStyle = .medium
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 11.0, leading: 12.0, bottom: 11.0, trailing: 12.0)
            button.configuration = configuration
            button.titleLabel?.numberOfLines = 0
            button.addTarget(self, action: action, for: .touchUpInside)
            return button
        }

        private func configureField(_ field: UITextField, placeholder: String, text: String?) {
            field.text = text
            field.placeholder = placeholder
            field.textColor = self.presentationData.theme.list.itemPrimaryTextColor
            field.tintColor = self.presentationData.theme.list.itemAccentColor
            field.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            field.layer.cornerRadius = 10.0
            field.leftView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 12.0, height: 1.0))
            field.leftViewMode = .always
            field.heightAnchor.constraint(equalToConstant: 46.0).isActive = true
        }

        @objc private func increaseStars() { FlexGramOverrides.virtualStars += 100; self.refreshValues() }
        @objc private func decreaseStars() { FlexGramOverrides.virtualStars = max(0, FlexGramOverrides.virtualStars - 100); self.refreshValues() }
        @objc private func increaseTon() { FlexGramOverrides.virtualTon += 1.0; self.refreshValues() }
        @objc private func decreaseTon() { FlexGramOverrides.virtualTon = max(0.0, FlexGramOverrides.virtualTon - 1.0); self.refreshValues() }
        @objc private func editStars() { self.onEditStars?() }
        @objc private func editTon() { self.onEditTon?() }
        @objc private func openMyProfile() { self.onOpenMyProfile?() }
        @objc private func profileChanged() { FlexGramLocalSettings.profileDisplayNameOverride = self.nameField.text }
        @objc private func authorChanged() { FlexGramLocalSettings.outgoingAuthorNameOverride = self.authorField.text }
    }

    private let context: AccountContext
    private let presentationData: PresentationData

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = "FlexGram"
    }

    required init(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var node: Node { self.displayNode as! Node }

    override public func loadDisplayNode() {
        let node = Node(presentationData: self.presentationData)
        node.onEditStars = { [weak self] in self?.editBalance(isStars: true) }
        node.onEditTon = { [weak self] in self?.editBalance(isStars: false) }
        node.onOpenMyProfile = { [weak self] in
            guard let self else { return }
            self.push(FlexGramPeerScreen(context: self.context, peerId: self.context.account.peerId.toInt64(), peerTitle: "Мой профиль"))
        }
        self.displayNode = node
        super.displayNodeDidLoad()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.isNodeLoaded { self.node.refreshValues() }
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.node.updateLayout(size: layout.size, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY)
    }

    private func editBalance(isStars: Bool) {
        let alert = UIAlertController(title: isStars ? "Виртуальные Stars" : "Виртуальные TON", message: "Значение хранится только на этом устройстве.", preferredStyle: .alert)
        alert.addTextField { field in
            field.keyboardType = isStars ? .numberPad : .decimalPad
            field.text = isStars ? String(FlexGramOverrides.virtualStars) : String(format: "%.2f", FlexGramOverrides.virtualTon)
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text else { return }
            if isStars {
                if let value = Int(text), value >= 0 { FlexGramOverrides.virtualStars = value }
            } else {
                let normalized = text.replacingOccurrences(of: ",", with: ".")
                if let value = Double(normalized), value.isFinite, value >= 0.0 { FlexGramOverrides.virtualTon = value }
            }
            self?.node.refreshValues()
        }))
        self.present(alert, animated: true)
    }
}
