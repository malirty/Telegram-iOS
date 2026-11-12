import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext
import FlexGram

/// Local aliases and gift copies. Swipe actions never call Telegram payment or profile APIs.
public final class FlexGramManageListsScreen: ViewController {
    private final class Node: ViewControllerTracingNode, UITableViewDataSource, UITableViewDelegate {
        private let context: AccountContext
        private let presentationData: PresentationData
        private let accountId: Int64
        private let peerId: Int64
        private let tableView = UITableView(frame: .zero, style: .insetGrouped)
        private var names: [String] = []
        private var gifts: [FlexGramGift] = []
        var onAddAlias: (() -> Void)?

        init(context: AccountContext, peerId: Int64, presentationData: PresentationData) {
            self.context = context
            self.presentationData = presentationData
            self.accountId = context.account.peerId.toInt64()
            self.peerId = peerId
            super.init()
            self.backgroundColor = presentationData.theme.list.plainBackgroundColor
            self.tableView.backgroundColor = presentationData.theme.list.plainBackgroundColor
            self.tableView.delegate = self
            self.tableView.dataSource = self
            self.tableView.rowHeight = 72.0
            self.tableView.estimatedRowHeight = 72.0
            self.refresh()
        }

        override func didLoad() {
            super.didLoad()
            self.view.addSubview(self.tableView)
        }

        func updateLayout(size: CGSize, navigationHeight: CGFloat) {
            self.tableView.frame = CGRect(x: 0.0, y: navigationHeight, width: size.width, height: max(0.0, size.height - navigationHeight))
        }

        func refresh() {
            self.names = FlexGramOverrides.aliases(accountId: self.accountId, peerId: self.peerId)
            self.gifts = FlexGramOverrides.gifts(accountId: self.accountId, peerId: self.peerId)
            self.tableView.reloadData()
        }

        func numberOfSections(in tableView: UITableView) -> Int { 2 }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            section == 0 ? self.names.count + 1 : max(1, self.gifts.count)
        }

        func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            section == 0 ? "ЛОКАЛЬНЫЕ ИМЕНА" : "ЛОКАЛЬНЫЕ ПОДАРКИ"
        }

        func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
            section == 0
                ? "Нажмите на имя, чтобы показывать его в этом приложении. Смахните влево, чтобы удалить."
                : "Смахните подарок влево для локального удаления или продажи. Другие пользователи изменений не увидят."
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let colors = self.presentationData.theme.list
            if indexPath.section == 0 {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.backgroundColor = colors.itemBlocksBackgroundColor
                cell.textLabel?.textColor = colors.itemPrimaryTextColor
                if indexPath.row == self.names.count {
                    cell.textLabel?.text = "Добавить локальное имя"
                    cell.textLabel?.textColor = colors.itemAccentColor
                    cell.accessoryType = .none
                } else {
                    let name = self.names[indexPath.row]
                    cell.textLabel?.text = name
                    cell.accessoryType = FlexGramOverrides.name(accountId: self.accountId, peerId: self.peerId) == name ? .checkmark : .none
                    cell.tintColor = colors.itemAccentColor
                }
                return cell
            }

            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = colors.itemBlocksBackgroundColor
            guard self.gifts.indices.contains(indexPath.row) else {
                cell.textLabel?.text = "Локальных подарков пока нет"
                cell.textLabel?.textColor = colors.itemSecondaryTextColor
                return cell
            }
            let gift = self.gifts[indexPath.row]
            let artwork = FlexGramGiftArtView(context: self.context)
            artwork.translatesAutoresizingMaskIntoConstraints = false
            artwork.setGift(gift, presentationData: self.presentationData)
            cell.contentView.addSubview(artwork)
            let title = UILabel()
            title.text = gift.kind
            title.font = .systemFont(ofSize: 16.0)
            title.textColor = colors.itemPrimaryTextColor
            title.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(title)
            let subtitle = UILabel()
            subtitle.text = self.peerId == self.accountId ? "Нажмите для карты кошелька · локально" : "Только на этом устройстве"
            subtitle.font = .systemFont(ofSize: 12.0)
            subtitle.textColor = colors.itemSecondaryTextColor
            subtitle.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(subtitle)
            NSLayoutConstraint.activate([
                artwork.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 14.0),
                artwork.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                artwork.widthAnchor.constraint(equalToConstant: 56.0),
                artwork.heightAnchor.constraint(equalToConstant: 56.0),
                title.leadingAnchor.constraint(equalTo: artwork.trailingAnchor, constant: 12.0),
                title.trailingAnchor.constraint(lessThanOrEqualTo: cell.contentView.trailingAnchor, constant: -12.0),
                title.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 15.0),
                subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                subtitle.trailingAnchor.constraint(lessThanOrEqualTo: cell.contentView.trailingAnchor, constant: -12.0),
                subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4.0)
            ])
            if self.peerId == self.accountId && gift.localId == FlexGramOverrides.walletCardGiftId(accountId: self.accountId) {
                cell.accessoryType = .checkmark
                cell.tintColor = colors.itemAccentColor
            }
            return cell
        }

        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            if indexPath.section == 0 {
                if indexPath.row == self.names.count {
                    self.onAddAlias?()
                } else if self.names.indices.contains(indexPath.row) {
                    FlexGramOverrides.setName(self.names[indexPath.row], accountId: self.accountId, peerId: self.peerId)
                    self.refresh()
                }
            } else if self.peerId == self.accountId && self.gifts.indices.contains(indexPath.row) {
                FlexGramOverrides.setWalletCardGiftId(self.gifts[indexPath.row].localId, accountId: self.accountId)
                self.refresh()
            }
        }

        func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
            if indexPath.section == 0 {
                guard self.names.indices.contains(indexPath.row) else { return nil }
                let alias = self.names[indexPath.row]
                let delete = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] _, _, done in
                    guard let self else { done(false); return }
                    let changed = FlexGramOverrides.removeAlias(alias, accountId: self.accountId, peerId: self.peerId)
                    done(changed)
                    DispatchQueue.main.async { self.refresh() }
                }
                return UISwipeActionsConfiguration(actions: [delete])
            }
            guard self.gifts.indices.contains(indexPath.row), let localId = self.gifts[indexPath.row].localId else { return nil }
            let delete = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] _, _, done in
                guard let self else { done(false); return }
                let changed = FlexGramOverrides.removeGift(localId: localId, accountId: self.accountId, peerId: self.peerId)
                done(changed)
                DispatchQueue.main.async { self.refresh() }
            }
            var actions = [delete]
            if self.peerId == self.accountId {
                let sell = UIContextualAction(style: .normal, title: "+75 ★") { [weak self] _, _, done in
                    guard let self else { done(false); return }
                    let changed = FlexGramOverrides.sellGift(localId: localId, accountId: self.accountId, peerId: self.peerId)
                    done(changed)
                    DispatchQueue.main.async { self.refresh() }
                }
                sell.backgroundColor = self.presentationData.theme.list.itemAccentColor
                actions.insert(sell, at: 0)
            }
            return UISwipeActionsConfiguration(actions: actions)
        }
    }

    private let context: AccountContext
    private let peerId: Int64
    private let presentationData: PresentationData
    private var node: Node { self.displayNode as! Node }

    public init(context: AccountContext, peerId: Int64) {
        self.context = context
        self.peerId = peerId
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = "VisualGram · списки"
    }

    required init(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override public func loadDisplayNode() {
        let node = Node(context: self.context, peerId: self.peerId, presentationData: self.presentationData)
        node.onAddAlias = { [weak self] in self?.addAlias() }
        self.displayNode = node
        super.displayNodeDidLoad()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.isNodeLoaded { self.node.refresh() }
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.node.updateLayout(size: layout.size, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY)
    }

    private func addAlias() {
        let alert = UIAlertController(title: "Локальное имя", message: "Имя увидите только вы на этом устройстве.", preferredStyle: .alert)
        alert.addTextField { field in field.placeholder = "Введите имя" }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Добавить", style: .default, handler: { [weak self, weak alert] _ in
            guard let self, let name = alert?.textFields?.first?.text else { return }
            if FlexGramOverrides.addAlias(name, accountId: self.context.account.peerId.toInt64(), peerId: self.peerId) {
                self.node.refresh()
            }
        }))
        self.present(alert, animated: true)
    }
}
