import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext
import SwiftSignalKit
import FlexGram

/// Edits only this installation's presentation of a peer and its local gift collection.
public final class FlexGramPeerScreen: ViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private final class Node: ViewControllerTracingNode {
        private let context: AccountContext
        private let presentationData: PresentationData
        private let accountId: Int64
        private let peerId: Int64
        private let scrollView = UIScrollView()
        private let stack = UIStackView()
        private let avatarView = UIImageView()
        private let nameField = UITextField()
        private let badgeField = UITextField()
        private let bioField = UITextField()
        private let greetingField = UITextField()
        private let hoursField = UITextField()
        private let locationField = UITextField()
        private let galleryScroll = UIScrollView()
        private let galleryStack = UIStackView()
        private let emptyGalleryLabel = UILabel()
        private let upgradeButton = UIButton(type: .system)
        private let sellButton = UIButton(type: .system)
        private let transferScroll = UIScrollView()
        private let transferStack = UIStackView()
        private let transferButton = UIButton(type: .system)
        private let transferStatus = UILabel()
        private let catalogueScroll = UIScrollView()
        private let catalogueStack = UIStackView()
        private let catalogueStatus = UILabel()
        private let previewArt: FlexGramGiftArtView
        private let modelButton = UIButton(type: .system)
        private let backdropButton = UIButton(type: .system)
        private let patternButton = UIButton(type: .system)
        private let balanceLabel = UILabel()
        private let statusLabel = UILabel()
        private let deliveryPicker = UIDatePicker()
        private let secondsStepper = UIStepper()
        private let secondsLabel = UILabel()
        private let pendingStack = UIStackView()
        private var displayedPending: [FlexGramScheduledGift] = []

        private var catalogue: [StarGift.Gift] = []
        private var displayedGallery: [FlexGramGift] = []
        private var selectedGalleryId: String?
        private var displayedTransferGifts: [FlexGramGift] = []
        private var selectedTransferId: String?
        private var selectedGift: StarGift.Gift?
        private var models: [StarGift.UniqueGift.Attribute] = []
        private var backdrops: [StarGift.UniqueGift.Attribute] = []
        private var patterns: [StarGift.UniqueGift.Attribute] = []
        private var modelIndex = 0
        private var backdropIndex = 0
        private var patternIndex = 0
        private var catalogueDisposable: Disposable?
        private var catalogueUpdateDisposable: Disposable?
        private var attributesDisposable: Disposable?
        var onPickAvatar: (() -> Void)?
        var onManageLists: (() -> Void)?

        init(context: AccountContext, peerId: Int64, title: String, presentationData: PresentationData) {
            self.context = context
            self.presentationData = presentationData
            self.accountId = context.account.peerId.toInt64()
            self.peerId = peerId
            self.previewArt = FlexGramGiftArtView(context: context)
            super.init()

            let colors = presentationData.theme.list
            self.backgroundColor = colors.plainBackgroundColor
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.keyboardDismissMode = .interactive
            self.stack.axis = .vertical
            self.stack.spacing = 18.0
            self.stack.isLayoutMarginsRelativeArrangement = true
            self.stack.layoutMargins = UIEdgeInsets(top: 20.0, left: 16.0, bottom: 32.0, right: 16.0)

            self.addHeader(title)
            self.addDescription("Имя, аватар и подарки ниже видны только в этом приложении.")

            let identityCard = self.makeGroup()
            self.avatarView.contentMode = .scaleAspectFill
            self.avatarView.clipsToBounds = true
            self.avatarView.layer.cornerRadius = 48.0
            self.avatarView.backgroundColor = colors.mediaPlaceholderColor
            self.avatarView.image = FlexGramOverrides.avatar(accountId: self.accountId, peerId: peerId)
            let avatarContainer = UIView()
            avatarContainer.heightAnchor.constraint(equalToConstant: 100.0).isActive = true
            self.avatarView.translatesAutoresizingMaskIntoConstraints = false
            avatarContainer.addSubview(self.avatarView)
            NSLayoutConstraint.activate([
                self.avatarView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
                self.avatarView.topAnchor.constraint(equalTo: avatarContainer.topAnchor, constant: 2.0),
                self.avatarView.widthAnchor.constraint(equalToConstant: 96.0),
                self.avatarView.heightAnchor.constraint(equalToConstant: 96.0)
            ])
            identityCard.addArrangedSubview(avatarContainer)
            identityCard.addArrangedSubview(self.makeTextButton("Выбрать аватар", action: #selector(self.pickAvatar)))
            identityCard.addArrangedSubview(self.makeTextButton("Вернуть исходный аватар", action: #selector(self.clearAvatar)))
            self.nameField.text = FlexGramOverrides.name(accountId: self.accountId, peerId: peerId)
            self.nameField.placeholder = "Локальное имя"
            self.nameField.textColor = colors.itemPrimaryTextColor
            self.nameField.tintColor = colors.itemAccentColor
            self.nameField.backgroundColor = colors.plainBackgroundColor
            self.nameField.layer.cornerRadius = 10.0
            self.nameField.leftView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 12.0, height: 1.0))
            self.nameField.leftViewMode = .always
            self.nameField.heightAnchor.constraint(equalToConstant: 46.0).isActive = true
            self.nameField.addTarget(self, action: #selector(self.nameChanged), for: .editingChanged)
            identityCard.addArrangedSubview(self.nameField)
            self.badgeField.text = FlexGramOverrides.chatBadge(accountId: self.accountId, peerId: peerId)
            self.badgeField.placeholder = "Значок чата · например ★"
            self.badgeField.textColor = colors.itemPrimaryTextColor
            self.badgeField.tintColor = colors.itemAccentColor
            self.badgeField.backgroundColor = colors.plainBackgroundColor
            self.badgeField.layer.cornerRadius = 10.0
            self.badgeField.leftView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 12.0, height: 1.0))
            self.badgeField.leftViewMode = .always
            self.badgeField.heightAnchor.constraint(equalToConstant: 46.0).isActive = true
            self.badgeField.addTarget(self, action: #selector(self.badgeChanged), for: .editingChanged)
            identityCard.addArrangedSubview(self.badgeField)
            identityCard.addArrangedSubview(self.makeTextButton("Имена и подарки · управление списками", action: #selector(self.manageLists)))
            self.stack.addArrangedSubview(identityCard)

            self.addSectionTitle("ЛОКАЛЬНЫЙ ПРОФИЛЬ И БИЗНЕС")
            let businessCard = self.makeGroup()
            self.configureProfileField(self.bioField, field: .bio, tag: 0, placeholder: "О себе · локально")
            self.configureProfileField(self.greetingField, field: .businessGreeting, tag: 1, placeholder: "Приветствие бизнеса · локально")
            self.configureProfileField(self.hoursField, field: .businessHours, tag: 2, placeholder: "Время работы · локально")
            self.configureProfileField(self.locationField, field: .businessLocation, tag: 3, placeholder: "Адрес бизнеса · локально")
            businessCard.addArrangedSubview(self.bioField)
            businessCard.addArrangedSubview(self.greetingField)
            businessCard.addArrangedSubview(self.hoursField)
            businessCard.addArrangedSubview(self.locationField)
            self.stack.addArrangedSubview(businessCard)

            self.addSectionTitle("ПОДАРКИ В ПРОФИЛЕ")
            let galleryCard = self.makeGroup()
            self.emptyGalleryLabel.text = "Пока нет локальных подарков"
            self.emptyGalleryLabel.textColor = colors.itemSecondaryTextColor
            self.emptyGalleryLabel.font = .systemFont(ofSize: 15.0)
            galleryCard.addArrangedSubview(self.emptyGalleryLabel)
            self.galleryScroll.showsHorizontalScrollIndicator = false
            self.galleryScroll.heightAnchor.constraint(equalToConstant: 104.0).isActive = true
            self.configureHorizontalScroll(self.galleryScroll, stack: self.galleryStack)
            galleryCard.addArrangedSubview(self.galleryScroll)
            self.upgradeButton.setTitle("Применить оформление к выбранному подарку", for: .normal)
            self.upgradeButton.setTitleColor(colors.itemAccentColor, for: .normal)
            self.upgradeButton.titleLabel?.numberOfLines = 0
            self.upgradeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44.0).isActive = true
            self.upgradeButton.addTarget(self, action: #selector(self.upgradeOwnedGift), for: .touchUpInside)
            galleryCard.addArrangedSubview(self.upgradeButton)
            if peerId == self.accountId {
                self.sellButton.setTitle("Продать выбранный локально · +75 виртуальных Stars", for: .normal)
                self.sellButton.setTitleColor(colors.itemAccentColor, for: .normal)
                self.sellButton.titleLabel?.numberOfLines = 0
                self.sellButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44.0).isActive = true
                self.sellButton.addTarget(self, action: #selector(self.sellOwnedGift), for: .touchUpInside)
                galleryCard.addArrangedSubview(self.sellButton)
            }
            self.stack.addArrangedSubview(galleryCard)

            if peerId != self.accountId {
                self.addSectionTitle("ПЕРЕДАТЬ МОЙ ПОДАРОК")
                let transferCard = self.makeGroup()
                self.transferStatus.font = .systemFont(ofSize: 14.0)
                self.transferStatus.textColor = colors.itemSecondaryTextColor
                self.transferStatus.numberOfLines = 0
                transferCard.addArrangedSubview(self.transferStatus)
                self.transferScroll.showsHorizontalScrollIndicator = false
                self.transferScroll.heightAnchor.constraint(equalToConstant: 104.0).isActive = true
                self.configureHorizontalScroll(self.transferScroll, stack: self.transferStack)
                transferCard.addArrangedSubview(self.transferScroll)
                self.transferButton.setTitle("Передать выбранный · комиссия 25 виртуальных Stars", for: .normal)
                self.transferButton.setTitleColor(colors.itemAccentColor, for: .normal)
                self.transferButton.titleLabel?.numberOfLines = 0
                self.transferButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44.0).isActive = true
                self.transferButton.addTarget(self, action: #selector(self.transferOwnedGift), for: .touchUpInside)
                transferCard.addArrangedSubview(self.transferButton)
                self.stack.addArrangedSubview(transferCard)
            }

            self.addSectionTitle("КАТАЛОГ TELEGRAM · ЛОКАЛЬНАЯ КОПИЯ")
            let makerCard = self.makeGroup()
            self.catalogueStatus.text = "Загружаю изображения подарков…"
            self.catalogueStatus.textColor = colors.itemSecondaryTextColor
            self.catalogueStatus.font = .systemFont(ofSize: 14.0)
            self.catalogueStatus.numberOfLines = 0
            makerCard.addArrangedSubview(self.catalogueStatus)
            self.catalogueScroll.showsHorizontalScrollIndicator = false
            self.catalogueScroll.heightAnchor.constraint(equalToConstant: 136.0).isActive = true
            self.configureHorizontalScroll(self.catalogueScroll, stack: self.catalogueStack)
            makerCard.addArrangedSubview(self.catalogueScroll)

            let previewContainer = UIView()
            previewContainer.heightAnchor.constraint(equalToConstant: 176.0).isActive = true
            self.previewArt.translatesAutoresizingMaskIntoConstraints = false
            self.previewArt.isUserInteractionEnabled = false
            previewContainer.addSubview(self.previewArt)
            NSLayoutConstraint.activate([
                self.previewArt.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
                self.previewArt.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 8.0),
                self.previewArt.widthAnchor.constraint(equalToConstant: 160.0),
                self.previewArt.heightAnchor.constraint(equalToConstant: 160.0)
            ])
            makerCard.addArrangedSubview(previewContainer)
            self.configureChoice(self.modelButton, action: #selector(self.nextModel))
            self.configureChoice(self.backdropButton, action: #selector(self.nextBackdrop))
            self.configureChoice(self.patternButton, action: #selector(self.nextPattern))
            makerCard.addArrangedSubview(self.modelButton)
            makerCard.addArrangedSubview(self.backdropButton)
            makerCard.addArrangedSubview(self.patternButton)
            makerCard.addArrangedSubview(self.makePrimaryButton("Добавить в профиль · 100 виртуальных Stars", action: #selector(self.sendGift)))
            self.deliveryPicker.datePickerMode = .dateAndTime
            self.deliveryPicker.preferredDatePickerStyle = .compact
            self.deliveryPicker.minimumDate = Date()
            self.deliveryPicker.date = Date().addingTimeInterval(300.0)
            self.deliveryPicker.tintColor = colors.itemAccentColor
            self.deliveryPicker.heightAnchor.constraint(greaterThanOrEqualToConstant: 44.0).isActive = true
            makerCard.addArrangedSubview(self.deliveryPicker)
            let secondsRow = UIStackView()
            secondsRow.axis = .horizontal
            secondsRow.alignment = .center
            secondsRow.spacing = 12.0
            self.secondsLabel.text = "Секунды: 00"
            self.secondsLabel.font = .systemFont(ofSize: 14.0)
            self.secondsLabel.textColor = colors.itemSecondaryTextColor
            secondsRow.addArrangedSubview(self.secondsLabel)
            self.secondsStepper.minimumValue = 0.0
            self.secondsStepper.maximumValue = 59.0
            self.secondsStepper.stepValue = 1.0
            self.secondsStepper.addTarget(self, action: #selector(self.secondsChanged), for: .valueChanged)
            secondsRow.addArrangedSubview(self.secondsStepper)
            makerCard.addArrangedSubview(secondsRow)
            makerCard.addArrangedSubview(self.makeTextButton("Запланировать локально · 100 Stars", action: #selector(self.scheduleGift)))
            self.pendingStack.axis = .vertical
            self.pendingStack.spacing = 8.0
            makerCard.addArrangedSubview(self.pendingStack)
            self.balanceLabel.font = .systemFont(ofSize: 14.0)
            self.balanceLabel.textColor = colors.itemSecondaryTextColor
            makerCard.addArrangedSubview(self.balanceLabel)
            self.statusLabel.font = .systemFont(ofSize: 14.0)
            self.statusLabel.textColor = colors.itemSecondaryTextColor
            self.statusLabel.numberOfLines = 0
            makerCard.addArrangedSubview(self.statusLabel)
            self.stack.addArrangedSubview(makerCard)

            self.refreshGallery()
            self.refreshTransferGifts()
            self.refreshBalance()
            self.refreshPending()
            self.refreshPreview()
            self.catalogueDisposable = (context.engine.payments.cachedStarGifts()
            |> deliverOnMainQueue).start(next: { [weak self] gifts in
                self?.updateCatalogue(gifts ?? [])
            })
            self.catalogueUpdateDisposable = context.engine.payments.keepStarGiftsUpdated().start()
        }

        deinit {
            self.catalogueDisposable?.dispose()
            self.catalogueUpdateDisposable?.dispose()
            self.attributesDisposable?.dispose()
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

        func refreshLocalValues() {
            if !self.nameField.isFirstResponder { self.nameField.text = FlexGramOverrides.name(accountId: self.accountId, peerId: self.peerId) }
            if !self.badgeField.isFirstResponder { self.badgeField.text = FlexGramOverrides.chatBadge(accountId: self.accountId, peerId: self.peerId) }
            self.refreshGallery()
            self.refreshTransferGifts()
            self.refreshBalance()
            self.refreshPending()
        }

        func updateAvatar(_ image: UIImage?) {
            self.avatarView.image = image
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

        private func addHeader(_ text: String) {
            let label = UILabel()
            label.text = text
            label.font = .systemFont(ofSize: 28.0, weight: .bold)
            label.textColor = self.presentationData.theme.list.itemPrimaryTextColor
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

        private func addSectionTitle(_ text: String) {
            let label = UILabel()
            label.text = text
            label.font = .systemFont(ofSize: 13.0, weight: .semibold)
            label.textColor = self.presentationData.theme.list.itemSecondaryTextColor
            label.numberOfLines = 0
            self.stack.addArrangedSubview(label)
        }

        private func makeTextButton(_ text: String, action: Selector) -> UIButton {
            let button = UIButton(type: .system)
            button.setTitle(text, for: .normal)
            button.setTitleColor(self.presentationData.theme.list.itemAccentColor, for: .normal)
            button.contentHorizontalAlignment = .left
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 40.0).isActive = true
            button.addTarget(self, action: action, for: .touchUpInside)
            return button
        }

        private func configureProfileField(_ fieldView: UITextField, field: FlexGramProfileField, tag: Int, placeholder: String) {
            fieldView.tag = tag
            fieldView.text = FlexGramOverrides.profileField(field, accountId: self.accountId, peerId: self.peerId)
            fieldView.placeholder = placeholder
            fieldView.textColor = self.presentationData.theme.list.itemPrimaryTextColor
            fieldView.tintColor = self.presentationData.theme.list.itemAccentColor
            fieldView.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            fieldView.layer.cornerRadius = 10.0
            fieldView.leftView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 12.0, height: 1.0))
            fieldView.leftViewMode = .always
            fieldView.heightAnchor.constraint(equalToConstant: 46.0).isActive = true
            fieldView.addTarget(self, action: #selector(self.profileFieldChanged(_:)), for: .editingChanged)
        }

        private func makePrimaryButton(_ text: String, action: Selector) -> UIButton {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.filled()
            configuration.title = text
            configuration.baseForegroundColor = .white
            configuration.baseBackgroundColor = self.presentationData.theme.list.itemAccentColor
            configuration.cornerStyle = .medium
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 12.0, leading: 12.0, bottom: 12.0, trailing: 12.0)
            button.configuration = configuration
            button.titleLabel?.numberOfLines = 0
            button.addTarget(self, action: action, for: .touchUpInside)
            return button
        }

        private func configureChoice(_ button: UIButton, action: Selector) {
            button.contentHorizontalAlignment = .left
            button.setTitleColor(self.presentationData.theme.list.itemAccentColor, for: .normal)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 42.0).isActive = true
            button.addTarget(self, action: action, for: .touchUpInside)
        }

        private func configureHorizontalScroll(_ scroll: UIScrollView, stack: UIStackView) {
            stack.axis = .horizontal
            stack.spacing = 10.0
            stack.translatesAutoresizingMaskIntoConstraints = false
            scroll.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
                stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
                stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
            ])
        }

        private func updateCatalogue(_ gifts: [StarGift]) {
            let generic = gifts.compactMap { item -> StarGift.Gift? in
                if case let .generic(gift) = item { return gift }
                return nil
            }
            let upgradeable = generic.filter { $0.upgradeVariantsCount != nil || $0.upgradeStars != nil }
            let regular = generic.filter { $0.upgradeVariantsCount == nil && $0.upgradeStars == nil }
            self.catalogue = Array((upgradeable + regular).prefix(40))
            self.catalogueStatus.text = self.catalogue.isEmpty ? "Каталог пока недоступен. Проверьте соединение и откройте экран позже." : "Выберите подарок из каталога. Изображения загружаются через Telegram."
            self.catalogueStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for (index, gift) in self.catalogue.enumerated() {
                let tile = UIButton(type: .custom)
                tile.tag = index
                tile.accessibilityLabel = "Локальная копия подарка: \(gift.title ?? "Подарок")"
                tile.widthAnchor.constraint(equalToConstant: 108.0).isActive = true
                tile.heightAnchor.constraint(equalToConstant: 132.0).isActive = true
                tile.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
                tile.layer.cornerRadius = 12.0
                let artwork = FlexGramGiftArtView(context: self.context)
                artwork.isUserInteractionEnabled = false
                artwork.translatesAutoresizingMaskIntoConstraints = false
                artwork.setGift(FlexGramGift(kind: gift.title ?? "Подарок", background: "", pattern: "", catalogueGift: .generic(gift)), presentationData: self.presentationData)
                tile.addSubview(artwork)
                let titleLabel = UILabel()
                titleLabel.text = gift.title ?? "Подарок"
                titleLabel.font = .systemFont(ofSize: 11.0, weight: .medium)
                titleLabel.textColor = self.presentationData.theme.list.itemPrimaryTextColor
                titleLabel.textAlignment = .center
                titleLabel.lineBreakMode = .byTruncatingTail
                titleLabel.translatesAutoresizingMaskIntoConstraints = false
                tile.addSubview(titleLabel)
                NSLayoutConstraint.activate([
                    artwork.topAnchor.constraint(equalTo: tile.topAnchor, constant: 4.0),
                    artwork.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
                    artwork.widthAnchor.constraint(equalToConstant: 100.0),
                    artwork.heightAnchor.constraint(equalToConstant: 100.0),
                    titleLabel.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 4.0),
                    titleLabel.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -4.0),
                    titleLabel.topAnchor.constraint(equalTo: artwork.bottomAnchor, constant: 3.0),
                    titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: tile.bottomAnchor, constant: -3.0)
                ])
                tile.addTarget(self, action: #selector(self.selectCatalogueGift(_:)), for: .touchUpInside)
                self.catalogueStack.addArrangedSubview(tile)
            }
            if self.selectedGift == nil, !self.catalogue.isEmpty {
                self.selectGift(at: 0)
            }
        }

        @objc private func selectCatalogueGift(_ sender: UIButton) {
            self.selectGift(at: sender.tag)
        }

        private func selectGift(at index: Int) {
            guard self.catalogue.indices.contains(index) else { return }
            let gift = self.catalogue[index]
            self.selectedGift = gift
            self.models = []
            self.backdrops = []
            self.patterns = []
            self.modelIndex = 0
            self.backdropIndex = 0
            self.patternIndex = 0
            for (tileIndex, view) in self.catalogueStack.arrangedSubviews.enumerated() {
                view.layer.borderWidth = tileIndex == index ? 2.0 : 0.0
                view.layer.borderColor = self.presentationData.theme.list.itemAccentColor.cgColor
            }
            self.refreshPreview()
            self.attributesDisposable?.dispose()
            self.attributesDisposable = (self.context.engine.payments.getStarGiftUpgradeAttributes(giftId: gift.id)
            |> deliverOnMainQueue).start(next: { [weak self] attributes in
                self?.setAttributes(attributes ?? [])
            })
        }

        private func setAttributes(_ attributes: [StarGift.UniqueGift.Attribute]) {
            self.models = attributes.filter {
                if case let .model(_, _, _, crafted) = $0 { return !crafted }
                return false
            }
            self.patterns = attributes.filter { if case .pattern = $0 { return true }; return false }
            self.backdrops = attributes.filter { if case .backdrop = $0 { return true }; return false }
            self.refreshPreview()
        }

        private func attributeName(_ attribute: StarGift.UniqueGift.Attribute?) -> String {
            guard let attribute else { return "не выбран" }
            switch attribute {
            case let .model(name, _, _, _): return name
            case let .pattern(name, _, _): return name
            case let .backdrop(name, _, _, _, _, _, _): return name
            case .originalInfo: return ""
            }
        }

        private func currentGift() -> FlexGramGift? {
            guard let selectedGift else { return nil }
            var attributes: [StarGift.UniqueGift.Attribute] = []
            if !self.models.isEmpty { attributes.append(self.models[self.modelIndex]) }
            if !self.patterns.isEmpty { attributes.append(self.patterns[self.patternIndex]) }
            if !self.backdrops.isEmpty { attributes.append(self.backdrops[self.backdropIndex]) }
            return FlexGramGift(
                kind: self.models.isEmpty ? (selectedGift.title ?? "Подарок") : self.attributeName(self.models[self.modelIndex]),
                background: self.backdrops.isEmpty ? "" : self.attributeName(self.backdrops[self.backdropIndex]),
                pattern: self.patterns.isEmpty ? "" : self.attributeName(self.patterns[self.patternIndex]),
                catalogueGift: .generic(selectedGift),
                collectibleAttributes: self.models.isEmpty ? nil : attributes
            )
        }

        private func refreshPreview() {
            self.modelButton.setTitle("Модель: \(self.models.isEmpty ? "ожидание каталога" : self.attributeName(self.models[self.modelIndex]))  ›", for: .normal)
            self.backdropButton.setTitle("Фон: \(self.backdrops.isEmpty ? "не выбран" : self.attributeName(self.backdrops[self.backdropIndex]))  ›", for: .normal)
            self.patternButton.setTitle("Узор: \(self.patterns.isEmpty ? "не выбран" : self.attributeName(self.patterns[self.patternIndex]))  ›", for: .normal)
            self.modelButton.isEnabled = !self.models.isEmpty
            self.backdropButton.isEnabled = !self.backdrops.isEmpty
            self.patternButton.isEnabled = !self.patterns.isEmpty
            self.previewArt.isHidden = self.selectedGift == nil
            if let gift = self.currentGift() {
                self.previewArt.setGift(gift, presentationData: self.presentationData)
            }
            self.upgradeButton.isEnabled = self.selectedGalleryId != nil && !self.models.isEmpty
        }

        private func refreshGallery() {
            let gifts = FlexGramOverrides.gifts(accountId: self.accountId, peerId: self.peerId)
            self.emptyGalleryLabel.isHidden = !gifts.isEmpty
            self.galleryScroll.isHidden = gifts.isEmpty
            self.upgradeButton.isHidden = gifts.isEmpty
            self.sellButton.isHidden = gifts.isEmpty
            self.galleryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            self.displayedGallery = Array(gifts.reversed().prefix(12))
            if !self.displayedGallery.contains(where: { $0.localId == self.selectedGalleryId }) {
                self.selectedGalleryId = self.displayedGallery.first?.localId
            }
            for (index, gift) in self.displayedGallery.enumerated() {
                let tile = UIButton(type: .custom)
                tile.tag = index
                tile.widthAnchor.constraint(equalToConstant: 96.0).isActive = true
                tile.heightAnchor.constraint(equalToConstant: 96.0).isActive = true
                tile.layer.cornerRadius = 12.0
                tile.layer.borderWidth = gift.localId == self.selectedGalleryId ? 2.0 : 0.0
                tile.layer.borderColor = self.presentationData.theme.list.itemAccentColor.cgColor
                tile.accessibilityLabel = "Локальный подарок: \(gift.kind)"
                tile.addTarget(self, action: #selector(self.selectOwnedGift(_:)), for: .touchUpInside)
                let artwork = FlexGramGiftArtView(context: self.context)
                artwork.isUserInteractionEnabled = false
                artwork.translatesAutoresizingMaskIntoConstraints = false
                artwork.setGift(gift, presentationData: self.presentationData)
                tile.addSubview(artwork)
                NSLayoutConstraint.activate([
                    artwork.leadingAnchor.constraint(equalTo: tile.leadingAnchor),
                    artwork.trailingAnchor.constraint(equalTo: tile.trailingAnchor),
                    artwork.topAnchor.constraint(equalTo: tile.topAnchor),
                    artwork.bottomAnchor.constraint(equalTo: tile.bottomAnchor)
                ])
                self.galleryStack.addArrangedSubview(tile)
            }
            self.upgradeButton.isEnabled = self.selectedGalleryId != nil && !self.models.isEmpty
            self.sellButton.isEnabled = self.selectedGalleryId != nil
        }

        private func refreshTransferGifts() {
            guard self.peerId != self.accountId else { return }
            let gifts = FlexGramOverrides.gifts(accountId: self.accountId, peerId: self.accountId)
            self.displayedTransferGifts = Array(gifts.reversed().prefix(20))
            if !self.displayedTransferGifts.contains(where: { $0.localId == self.selectedTransferId }) {
                self.selectedTransferId = self.displayedTransferGifts.first?.localId
            }
            self.transferStatus.text = gifts.isEmpty
                ? "В вашем локальном профиле пока нет подарков."
                : "Подарок переместится только на этом устройстве. Собеседник его не увидит."
            self.transferScroll.isHidden = gifts.isEmpty
            self.transferButton.isEnabled = self.selectedTransferId != nil && FlexGramOverrides.virtualStars >= 25
            self.transferStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for (index, gift) in self.displayedTransferGifts.enumerated() {
                let tile = UIButton(type: .custom)
                tile.tag = index
                tile.widthAnchor.constraint(equalToConstant: 96.0).isActive = true
                tile.heightAnchor.constraint(equalToConstant: 96.0).isActive = true
                tile.layer.cornerRadius = 12.0
                tile.layer.borderWidth = gift.localId == self.selectedTransferId ? 2.0 : 0.0
                tile.layer.borderColor = self.presentationData.theme.list.itemAccentColor.cgColor
                tile.accessibilityLabel = "Передать локальный подарок: \(gift.kind)"
                tile.addTarget(self, action: #selector(self.selectTransferGift(_:)), for: .touchUpInside)
                let artwork = FlexGramGiftArtView(context: self.context)
                artwork.isUserInteractionEnabled = false
                artwork.translatesAutoresizingMaskIntoConstraints = false
                artwork.setGift(gift, presentationData: self.presentationData)
                tile.addSubview(artwork)
                NSLayoutConstraint.activate([
                    artwork.leadingAnchor.constraint(equalTo: tile.leadingAnchor),
                    artwork.trailingAnchor.constraint(equalTo: tile.trailingAnchor),
                    artwork.topAnchor.constraint(equalTo: tile.topAnchor),
                    artwork.bottomAnchor.constraint(equalTo: tile.bottomAnchor)
                ])
                self.transferStack.addArrangedSubview(tile)
            }
        }

        @objc private func selectTransferGift(_ sender: UIButton) {
            guard self.displayedTransferGifts.indices.contains(sender.tag) else { return }
            self.selectedTransferId = self.displayedTransferGifts[sender.tag].localId
            self.refreshTransferGifts()
        }

        @objc private func transferOwnedGift() {
            guard let localId = self.selectedTransferId else { return }
            guard FlexGramOverrides.transferGift(localId: localId, accountId: self.accountId, fromPeerId: self.accountId, toPeerId: self.peerId) else {
                self.transferStatus.text = "Не удалось передать подарок. Проверьте баланс виртуальных Stars."
                return
            }
            self.refreshLocalValues()
            self.transferStatus.text = "Подарок передан локально. Другой пользователь его не увидит."
        }

        @objc private func selectOwnedGift(_ sender: UIButton) {
            guard self.displayedGallery.indices.contains(sender.tag) else { return }
            let gift = self.displayedGallery[sender.tag]
            self.selectedGalleryId = gift.localId
            self.refreshGallery()
            if let catalogueGift = gift.catalogueGift, case let .generic(value) = catalogueGift,
               let index = self.catalogue.firstIndex(where: { $0.id == value.id }) {
                self.selectGift(at: index)
            }
        }

        @objc private func upgradeOwnedGift() {
            guard let selectedId = self.selectedGalleryId,
                  let owned = self.displayedGallery.first(where: { $0.localId == selectedId }),
                  let preview = self.currentGift(), let attributes = preview.collectibleAttributes else {
                self.statusLabel.text = "Выберите подарок и его модель из каталога."
                return
            }
            guard let ownedGift = owned.catalogueGift, case let .generic(original) = ownedGift,
                  let previewGift = preview.catalogueGift, case let .generic(selected) = previewGift,
                  original.id == selected.id else {
                self.statusLabel.text = "Выберите в каталоге тот же подарок, который хотите оформить."
                return
            }
            let updated = FlexGramGift(kind: preview.kind, background: preview.background, pattern: preview.pattern, catalogueGift: owned.catalogueGift, collectibleAttributes: attributes, localId: selectedId)
            guard FlexGramOverrides.replaceGift(localId: selectedId, accountId: self.accountId, peerId: self.peerId, with: updated) else {
                self.statusLabel.text = "Не удалось сохранить оформление подарка."
                return
            }
            self.refreshGallery()
            self.statusLabel.text = "Локальное оформление подарка обновлено. Реальный NFT не создан."
        }

        @objc private func sellOwnedGift() {
            guard self.peerId == self.accountId, let selectedId = self.selectedGalleryId else { return }
            guard FlexGramOverrides.sellGift(localId: selectedId, accountId: self.accountId, peerId: self.peerId) else {
                self.statusLabel.text = "Не удалось продать локальный подарок."
                return
            }
            self.refreshLocalValues()
            self.statusLabel.text = "Подарок удалён только из локального профиля, начислено 75 виртуальных Stars."
        }

        private func refreshBalance() {
            self.balanceLabel.text = "Доступно: \(FlexGramOverrides.virtualStars) виртуальных Stars · \(String(format: "%.2f", FlexGramOverrides.virtualTon)) TON · \(String(format: "%.2f", FlexGramOverrides.virtualGram)) GRAM"
        }

        private func refreshPending() {
            let pending = FlexGramOverrides.scheduledGifts(accountId: self.accountId, peerId: self.peerId)
            self.displayedPending = Array(pending.prefix(3))
            self.pendingStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            guard !pending.isEmpty else {
                let label = UILabel()
                label.text = "Запланированных локальных подарков нет"
                label.font = .systemFont(ofSize: 13.0)
                label.textColor = self.presentationData.theme.list.itemSecondaryTextColor
                self.pendingStack.addArrangedSubview(label)
                return
            }
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            for (index, item) in self.displayedPending.enumerated() {
                let row = UIStackView()
                row.axis = .horizontal
                row.alignment = .center
                row.spacing = 8.0
                let artwork = FlexGramGiftArtView(context: self.context)
                artwork.widthAnchor.constraint(equalToConstant: 58.0).isActive = true
                artwork.heightAnchor.constraint(equalToConstant: 58.0).isActive = true
                artwork.setGift(item.gift, presentationData: self.presentationData)
                row.addArrangedSubview(artwork)
                let label = UILabel()
                label.text = "\(item.gift.kind)\n\(formatter.string(from: item.deliveryDate))"
                label.font = .systemFont(ofSize: 12.0)
                label.textColor = self.presentationData.theme.list.itemPrimaryTextColor
                label.numberOfLines = 2
                row.addArrangedSubview(label)
                let cancel = UIButton(type: .system)
                cancel.setTitle("Отмена", for: .normal)
                cancel.setTitleColor(self.presentationData.theme.list.itemAccentColor, for: .normal)
                cancel.tag = index
                cancel.addTarget(self, action: #selector(self.cancelPending(_:)), for: .touchUpInside)
                row.addArrangedSubview(cancel)
                self.pendingStack.addArrangedSubview(row)
            }
            if pending.count > self.displayedPending.count {
                let more = UILabel()
                more.text = "Ещё \(pending.count - self.displayedPending.count) запланировано"
                more.font = .systemFont(ofSize: 12.0)
                more.textColor = self.presentationData.theme.list.itemSecondaryTextColor
                self.pendingStack.addArrangedSubview(more)
            }
        }

        @objc private func pickAvatar() { self.onPickAvatar?() }

        @objc private func clearAvatar() {
            FlexGramOverrides.setAvatar(nil, accountId: self.accountId, peerId: self.peerId)
            self.updateAvatar(nil)
            self.statusLabel.text = "Исходный аватар появится после повторного открытия профиля."
        }

        @objc private func nameChanged() {
            FlexGramOverrides.setName(self.nameField.text, accountId: self.accountId, peerId: self.peerId)
        }

        @objc private func badgeChanged() {
            FlexGramOverrides.setChatBadge(self.badgeField.text, accountId: self.accountId, peerId: self.peerId)
        }

        @objc private func manageLists() { self.onManageLists?() }

        @objc private func profileFieldChanged(_ sender: UITextField) {
            let field: FlexGramProfileField
            switch sender.tag {
            case 0: field = .bio
            case 1: field = .businessGreeting
            case 2: field = .businessHours
            case 3: field = .businessLocation
            default: return
            }
            FlexGramOverrides.setProfileField(field, value: sender.text, accountId: self.accountId, peerId: self.peerId)
        }

        @objc private func nextModel() {
            guard !self.models.isEmpty else { return }
            self.modelIndex = (self.modelIndex + 1) % self.models.count
            self.refreshPreview()
        }

        @objc private func nextBackdrop() {
            guard !self.backdrops.isEmpty else { return }
            self.backdropIndex = (self.backdropIndex + 1) % self.backdrops.count
            self.refreshPreview()
        }

        @objc private func nextPattern() {
            guard !self.patterns.isEmpty else { return }
            self.patternIndex = (self.patternIndex + 1) % self.patterns.count
            self.refreshPreview()
        }

        @objc private func secondsChanged() {
            self.secondsLabel.text = String(format: "Секунды: %02d", Int(self.secondsStepper.value))
        }

        @objc private func scheduleGift() {
            guard let gift = self.currentGift() else {
                self.statusLabel.text = "Сначала выберите подарок из каталога."
                return
            }
            var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: self.deliveryPicker.date)
            components.second = Int(self.secondsStepper.value)
            guard let date = Calendar.current.date(from: components), date > Date() else {
                self.statusLabel.text = "Выберите время в будущем."
                return
            }
            guard FlexGramOverrides.scheduleGift(gift, accountId: self.accountId, peerId: self.peerId, deliveryDate: date) else {
                self.statusLabel.text = "Не удалось запланировать подарок. Проверьте виртуальный баланс."
                return
            }
            self.refreshBalance()
            self.refreshPending()
            self.statusLabel.text = "Подарок появится в этом профиле после указанного времени, когда приложение открыто."
        }

        @objc private func cancelPending(_ sender: UIButton) {
            guard self.displayedPending.indices.contains(sender.tag) else { return }
            let item = self.displayedPending[sender.tag]
            guard FlexGramOverrides.cancelScheduledGift(id: item.id, accountId: self.accountId) else {
                self.statusLabel.text = "Подарок уже доставлен локально."
                self.refreshLocalValues()
                return
            }
            self.refreshLocalValues()
            self.statusLabel.text = "Планирование отменено, виртуальные Stars возвращены."
        }

        @objc private func sendGift() {
            guard let gift = self.currentGift() else {
                self.statusLabel.text = "Сначала выберите подарок из каталога."
                return
            }
            guard FlexGramOverrides.virtualStars >= 100 else {
                self.statusLabel.text = "Нужно 100 виртуальных Stars. Добавьте их в Настройки → VisualGram."
                return
            }
            guard FlexGramOverrides.addGift(gift, accountId: self.accountId, peerId: self.peerId, cost: 100) else {
                self.statusLabel.text = "Не удалось сохранить подарок. Баланс не изменён."
                return
            }
            self.refreshGallery()
            self.refreshBalance()
            self.statusLabel.text = self.peerId == self.accountId ? "Локальная копия добавлена в ваш профиль." : "Локальная копия добавлена в профиль собеседника только на этом устройстве."
        }
    }

    private let context: AccountContext
    private let peerId: Int64
    private let peerTitle: String
    private let presentationData: PresentationData
    private var deliveryTimer: Timer?

    public init(context: AccountContext, peerId: Int64, peerTitle: String) {
        self.context = context
        self.peerId = peerId
        self.peerTitle = peerTitle
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = "VisualGram · профиль"
    }

    required init(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var node: Node { self.displayNode as! Node }

    override public func loadDisplayNode() {
        let node = Node(context: self.context, peerId: self.peerId, title: self.peerTitle, presentationData: self.presentationData)
        node.onPickAvatar = { [weak self] in self?.pickAvatar() }
        node.onManageLists = { [weak self] in
            guard let self else { return }
            self.push(FlexGramManageListsScreen(context: self.context, peerId: self.peerId))
        }
        self.displayNode = node
        super.displayNodeDidLoad()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.isNodeLoaded { self.node.refreshLocalValues() }
        self.deliveryTimer?.invalidate()
        self.deliveryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if FlexGramOverrides.deliverDueGifts() > 0, self.isNodeLoaded {
                self.node.refreshLocalValues()
            }
        }
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.deliveryTimer?.invalidate()
        self.deliveryTimer = nil
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
            FlexGramOverrides.setAvatar(image, accountId: self.context.account.peerId.toInt64(), peerId: self.peerId)
            self.node.updateAvatar(FlexGramOverrides.avatar(accountId: self.context.account.peerId.toInt64(), peerId: self.peerId))
        }
        picker.dismiss(animated: true, completion: nil)
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
