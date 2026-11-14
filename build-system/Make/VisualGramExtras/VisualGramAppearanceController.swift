import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import GiftOptionsScreen
import GiftViewScreen
import GiftCraftScreen
import EntityKeyboard
import EmojiStatusSelectionComponent
import ChatScheduleTimeController
import ConfettiEffect
import PeerNameColorScreen
import SettingsUI
import BusinessHoursSetupScreen
import BusinessLocationSetupScreen

private final class VisualGramProfilePhotoPicker: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let completion: (UIImage) -> Void
    init(completion: @escaping (UIImage) -> Void) { self.completion = completion }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        picker.dismiss(animated: true) { [completion] in if let image { completion(image) } }
    }
}

private struct VisualGramAppearanceEntry: ItemListNodeEntry {
    enum Kind: Equatable { case toggle(Bool), button(String), info }
    let stableId: Int32
    let section: ItemListSectionId
    let title: String
    let kind: Kind
    let theme: PresentationTheme

    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.stableId == rhs.stableId && lhs.section == rhs.section && lhs.title == rhs.title && lhs.kind == rhs.kind && lhs.theme === rhs.theme
    }

    static func <(lhs: Self, rhs: Self) -> Bool {
        func rank(_ id: Int32) -> Int32 { switch id { case 24: return 18; case 23: return 21; case 27: return 25; default: return id } }
        return lhs.section == rhs.section ? rank(lhs.stableId) < rank(rhs.stableId) : lhs.section < rhs.section
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let actions = arguments as! VisualGramAppearanceActions
        let icon: UIImage?
        switch self.stableId {
        case 900: icon = PresentationResourcesSettings.myProfile
        case 901: icon = PresentationResourcesSettings.premiumGift
        case 902: icon = PresentationResourcesSettings.stars
        case 904: icon = PresentationResourcesSettings.appearance
        case 905, 100: icon = PresentationResourcesSettings.security
        case 1, 102: icon = PresentationResourcesSettings.premium
        case 2, 3: icon = PresentationResourcesSettings.emojiStatus
        case 101: icon = PresentationResourcesSettings.channels
        case 103: icon = PresentationResourcesSettings.messages
        case 104, 120: icon = PresentationResourcesSettings.recentActions
        case 105: icon = PresentationResourcesSettings.photosBlue
        case 110: icon = PresentationResourcesSettings.block
        case 130: icon = PresentationResourcesSettings.chatAppearance
        default: icon = nil
        }
        switch self.kind {
        case let .toggle(value):
            return ItemListSwitchItem(presentationData: presentationData, icon: icon, title: self.title, value: value, sectionId: self.section, style: .blocks, updated: { actions.toggle(self.stableId, value: $0) })
        case let .button(label):
            return ItemListDisclosureItem(presentationData: presentationData, icon: icon, title: self.title, label: label, sectionId: self.section, style: .blocks, action: { actions.open(self.stableId) })
        case .info:
            return ItemListTextItem(presentationData: presentationData, text: .plain(self.title), sectionId: self.section)
        }
    }
}

private final class VisualGramAppearanceActions {
    let context: AccountContext
    weak var controller: ItemListController?
    let disposables = DisposableSet()
    let activeSection = ValuePromise<Int32>(-1, ignoreRepeated: true)
    var currentSection: Int32 = -1
    let expandedLists = ValuePromise<Int32>(-1, ignoreRepeated: true)
    private var expandedListBits: Int32 = 0
    var targetPeerId: EnginePeer.Id
    var targetTitle = "Мой профиль"
    private var counterpartyId: Int64?
    private var direction: VisualGramGift.Direction = .received
    private var giftDate = Int32(Date().timeIntervalSince1970)
    private var giftText = ""
    private var photoPicker: VisualGramProfilePhotoPicker?

    init(context: AccountContext) { self.context = context; self.targetPeerId = context.account.peerId }
    deinit { self.disposables.dispose() }

    var appearance: VisualGramAppearance { return VisualGramLocalAppearance.shared.appearance(accountId: self.context.account.peerId, targetPeerId: self.targetPeerId) }
    private var scheduledGifts: [VisualGramScheduledGift] {
        return VisualGramLocalAppearance.shared.pendingScheduledGifts.filter { $0.targetPeerId == self.targetPeerId.toInt64() }.sorted { $0.deliveryDate < $1.deliveryDate }
    }

    private func presentNative(_ alert: UIAlertController) {
        var presenter: UIViewController? = self.controller?.navigationController?.view.window?.rootViewController ?? self.controller
        while let presented = presenter?.presentedViewController { presenter = presented }
        presenter?.present(alert, animated: true)
    }

    func update(_ f: (inout VisualGramAppearance) -> Void) {
        VisualGramLocalAppearance.shared.update(accountId: self.context.account.peerId, targetPeerId: self.targetPeerId, f)
    }

    func toggle(_ id: Int32, value: Bool) {
        if (100...105).contains(id) || id == 122 {
            VisualGramLocalAppearance.shared.updateDeviceSettings { settings in
                switch id {
                case 100: settings.ghostMode = value
                case 101: settings.hideSponsoredMessages = value
                case 102: settings.localPremiumPresentation = value
                case 103: settings.confirmMediaSends = value
                case 104: settings.messageHistoryEnabled = value
                case 105: settings.allowProtectedScreenshots = value
                case 122: settings.keepTimedMedia = value
                default: break
                }
            }
            return
        }
        if id == 3 {
            if value { self.configureVerification() } else { self.update { $0.verification = nil } }
            return
        }
        self.update {
            switch id {
            case 0: $0.enabled = value
            case 1: $0.premium = value; $0.enabled = true
            case 2: $0.verified = value; $0.enabled = true
            default: break
            }
        }
    }

    func toggleList(_ bit: Int32) {
        self.expandedListBits ^= bit
        self.expandedLists.set(self.expandedListBits)
    }

    func message(_ text: String) {
        let alert = UIAlertController(title: "VisualGram", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.presentNative(alert)
    }

    private func openMessageJournal() {
        let accountId = self.context.account.peerId
        let events = VisualGramMessageJournal.shared.events(accountId: accountId)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        self.controller?.push(VisualGramListController(context: self.context, target: accountId, title: "История сообщений", rows: {
            events.map { event in
                let title = event.kind == .edited ? "Изменено · чат \(event.peerId)" : "Удалено · чат \(event.peerId)"
                let preview = event.previousText.isEmpty ? (VisualGramMessageJournal.shared.archivedMedia(event.archivedMedia) == nil ? "Медиа недоступно" : "Медиа сохранено в чате") : event.previousText.replacingOccurrences(of: "\n", with: " ")
                return .init(id: event.id, title: title, subtitle: formatter.string(from: Date(timeIntervalSince1970: TimeInterval(event.date))) + " · " + String(preview.prefix(90)), gift: nil)
            }
        }, reorder: nil, open: { [weak self] id in
            guard let self, let event = events.first(where: { $0.id == id }) else { return }
            let original = event.previousText.isEmpty ? (VisualGramMessageJournal.shared.archivedMedia(event.archivedMedia) == nil ? "Медиа недоступно" : "Медиа сохранено в чате") : event.previousText
            let detail = event.updatedText.map { "Было:\n\(original)\n\nСтало:\n\($0)" } ?? "Удалённый текст:\n\(original)"
            self.message(detail)
        }, edit: { _ in }, delete: { _ in }, allowsEditing: false))
    }

    private func clearMessageJournal() {
        let alert = UIAlertController(title: "Очистить историю?", message: "Локальные копии удалённых и изменённых сообщений этого аккаунта будут удалены.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Очистить", style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            VisualGramMessageJournal.shared.clear(accountId: self.context.account.peerId)
            VisualGramLocalAppearance.shared.updateDeviceSettings { _ in }
        }))
        self.presentNative(alert)
    }

    func form(title: String, fields: [(String, String)], save: @escaping ([String]) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        for (placeholder, value) in fields {
            alert.addTextField { field in
                field.placeholder = placeholder
                field.text = value
                field.autocapitalizationType = .none
                field.autocorrectionType = .no
                if title == "Баланс звёзд" || title == "Баланс GRAM" {
                    let imageView = UIImageView(image: title == "Баланс звёзд" ? PresentationResourcesSettings.stars : PresentationResourcesSettings.money)
                    imageView.contentMode = .scaleAspectFit
                    imageView.frame = CGRect(x: 0, y: 0, width: 28, height: 28)
                    field.leftView = imageView
                    field.leftViewMode = .always
                    field.keyboardType = title == "Баланс звёзд" ? .numberPad : .decimalPad
                }
            }
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { [weak alert] _ in
            save(alert?.textFields?.map { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" } ?? [])
        }))
        self.presentNative(alert)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }

    private func minorAmount(_ text: String, scale: Decimal) -> Int64? {
        guard let value = Decimal(string: text.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")), value >= 0 else { return nil }
        let result = value * scale
        guard result <= Decimal(Int64.max) else { return nil }
        return NSDecimalNumber(decimal: result).int64Value
    }

    func open(_ id: Int32) {
        if (900...902).contains(id) || id == 904 || id == 905 {
            let section = id == 904 ? 3 : (id == 905 ? 4 : id - 900)
            self.controller?.push(visualGramAppearanceController(context: self.context, initialSection: section, targetPeerId: self.targetPeerId, targetTitle: self.targetTitle))
            return
        }

        switch id {
        case 3: self.configureVerification()
        case 4: self.selectEmoji()
        case 5:
            self.update { $0.overridesEmojiStatus = true; $0.emojiStatus = nil }
        case 7: self.selectTarget()
        case 8: self.configureVerification(forceSetup: true)
        case 10: self.editUsername(index: nil)
        case 11: self.editPhone()
        case 12: self.editRating()
        case 13: self.openUsernames()
        case 26: self.openGiftList(history: true)
        case 20:
            self.direction = .received; self.counterpartyId = nil; self.giftDate = Int32(clamping: Int64(Date().timeIntervalSince1970)); self.giftText = ""
            self.selectOrdinaryGift()
        case 21: self.configureReceipt { [weak self] in self?.importUniqueGift() }
        case 22: self.configureReceipt(direction: .sent) { [weak self] in self?.selectOrdinaryGift() }
        case 23: self.configureReceipt(direction: .sent) { [weak self] in self?.importUniqueGift() }
        case 24:
            self.direction = .received
            self.counterpartyId = nil
            self.giftDate = Int32(Date().timeIntervalSince1970)
            self.giftText = ""
            self.importUniqueGift()
        case 14:
            self.controller?.push(UserAppearanceScreen(context: self.context, visualGramTarget: self.targetPeerId))
        case 15:
            self.controller?.push(BusinessHoursSetupScreen(context: self.context, initialValue: self.appearance.businessHours, completion: { _ in }, visualGramTarget: self.targetPeerId))
        case 16:
            self.controller?.push(BusinessLocationSetupScreen(context: self.context, initialValue: self.appearance.businessLocation, completion: { _ in }, visualGramTarget: self.targetPeerId))
        case 27: self.openGiftList(history: false)
        case 903: self.returnToMenu()
        case 110:
            self.form(title: "Скрывать сообщения со словами", fields: [("Слова или фразы, разделённые запятыми", VisualGramLocalAppearance.shared.deviceSettings.filteredWords.joined(separator: ", "))]) { values in
                guard let input = values.first else { return }
                let words = input.components(separatedBy: CharacterSet(charactersIn: ",\n"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                VisualGramLocalAppearance.shared.updateDeviceSettings { $0.filteredWords = Array(words.prefix(100)) }
            }
        case 120: self.openMessageJournal()
        case 121: self.clearMessageJournal()
        case 130: self.controller?.push(themeSettingsController(context: self.context, focusOnItemTag: .icon))
        case 32:
            self.form(title: "Баланс GRAM", fields: [("GRAM", self.appearance.grams.map { VisualGramLocalAppearance.formatGrams($0) } ?? "")]) { [weak self] values in
                guard let self, values.count == 1 else { return }
                if values[0].isEmpty { self.update { $0.grams = nil }; return }
                guard let balance = VisualGramLocalAppearance.parseGrams(values[0]) else { self.message("Введите баланс: до 9 знаков после запятой."); return }
                self.update {
                    let delta = balance - ($0.grams ?? 0)
                    var history = $0.gramHistory ?? []
                    if delta != 0 { history.append(.init(id: UUID().uuidString, date: Int32(clamping: Int64(Date().timeIntervalSince1970)), amount: delta, kind: delta > 0 ? .topUp : .adjustment, title: nil, peerId: nil, gift: nil)) }
                    $0.grams = balance; $0.gramHistory = history; $0.enabled = true
                }
            }
        case 33: self.controller?.push(VisualGramCardEditorController(context: self.context, target: self.targetPeerId))
        case 30:
            self.form(title: "Баланс звёзд", fields: [("Баланс", self.appearance.stars.map(String.init) ?? "")]) { [weak self] values in
                guard let self, values.count == 1 else { return }
                if values[0].isEmpty { self.update { $0.stars = nil }; return }
                guard let stars = Int64(values[0]), stars >= 0 else { self.message("Введите целое число от 0 до \(Int64.max)"); return }
                self.update {
                    let previous = $0.stars ?? 0
                    let delta = stars - previous
                    VisualGramLocalAppearance.recordStarsTransaction(value: &$0, amount: delta, kind: delta > 0 ? .topUp : .adjustment, peerId: nil, gift: nil, now: Int32(clamping: Int64(Date().timeIntervalSince1970)))
                    $0.stars = stars; $0.enabled = true
                }
            }
        case 31:
            self.form(title: "Добавить операцию", fields: [("Звёзды: +100 или -25", ""), ("Дата: ГГГГ-ММ-ДД ЧЧ:ММ", self.dateFormatter.string(from: Date()))]) { [weak self] values in
                guard let self, values.count == 2, let amount = Int64(values[0]), amount != 0, let date = self.dateFormatter.date(from: values[1]) else { self?.message("Проверь сумму и дату"); return }
                let current = self.appearance.stars ?? 0
                let (balance, overflow) = current.addingReportingOverflow(amount)
                guard !overflow, balance >= 0 else { self.message("Недостаточно звёзд"); return }
                self.update {
                    $0.enabled = true; $0.stars = balance
                    VisualGramLocalAppearance.recordStarsTransaction(value: &$0, amount: amount, kind: amount > 0 ? .topUp : .adjustment, peerId: nil, gift: nil, now: Int32(clamping: Int64(date.timeIntervalSince1970)))
                }
            }
        case 40:
            let alert = UIAlertController(title: "Сбросить оформление?", message: "Локальные подарки, юзернеймы, номер, рейтинг, значки и статусы выбранного профиля будут удалены.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            alert.addAction(UIAlertAction(title: "Сбросить", style: .destructive, handler: { [weak self] _ in
                guard let self else { return }
                VisualGramLocalAppearance.shared.reset(accountId: self.context.account.peerId, targetPeerId: self.targetPeerId)
            }))
            self.presentNative(alert)
        case 50:
            self.form(title: "Локальное имя", fields: [("Имя", self.appearance.localName ?? "")]) { [weak self] values in
                guard let self, let name = values.first, name.count <= 128 else { return }
                self.update { $0.enabled = true; $0.localName = name.isEmpty ? nil : name }
            }
        case 51:
            self.form(title: "Локальный юзернейм", fields: [("Юзернейм без @", self.appearance.localUsername ?? "")]) { [weak self] values in
                guard let self, let raw = values.first else { return }
                let name = raw.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
                guard name.isEmpty || name.range(of: "^[A-Za-z][A-Za-z0-9_]{3,31}$", options: .regularExpression) != nil else { self.message("Укажи юзернейм от 4 до 32 символов."); return }
                self.update { $0.enabled = true; $0.localUsername = name.isEmpty ? nil : name }
            }
        case 52:
            self.form(title: "Локальное описание", fields: [("Описание профиля", self.appearance.localBio ?? "")]) { [weak self] values in
                guard let self, let bio = values.first, bio.count <= 512 else { return }
                self.update { $0.enabled = true; $0.localBio = bio.isEmpty ? nil : bio }
            }
        case 53: self.chooseProfileImage(banner: false)
        case 54: self.chooseProfileImage(banner: true)
        case 55:
            self.update { $0.localName = nil; $0.localUsername = nil; $0.localBio = nil; $0.localAvatar = nil; $0.localBanner = nil }
        case 1000..<2000: self.editUsername(index: Int(id - 1000))
        case 2000..<3000: self.openGift(index: Int(id - 2000))
        case 3000..<4000: self.openScheduledGift(index: Int(id - 3000))
        default: break
        }
    }

    func returnToMenu() {
        if self.currentSection >= 0 {
            self.controller?.navigationController?.popViewController(animated: true)
        }
    }

    private func chooseProfileImage(banner: Bool) {
        let alert = UIAlertController(title: banner ? "Баннер профиля" : "Аватар профиля", message: "Изображение видно только в этом приложении.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Выбрать фото", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let target = self.targetPeerId
            let delegate = VisualGramProfilePhotoPicker { [weak self] image in
                guard let self, let saved = VisualGramLocalAppearance.saveImage(image) else { self?.message("Не удалось сохранить изображение."); return }
                VisualGramLocalAppearance.shared.update(accountId: self.context.account.peerId, targetPeerId: target) { value in
                    value.enabled = true
                    if banner { value.localBanner = saved } else { value.localAvatar = saved }
                }
            }
            self.photoPicker = delegate
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.allowsEditing = !banner
            picker.delegate = delegate
            DispatchQueue.main.async { self.controller?.navigationController?.view.window?.rootViewController?.present(picker, animated: true) }
        }))
        alert.addAction(UIAlertAction(title: "Убрать", style: .destructive, handler: { [weak self] _ in
            self?.update { if banner { $0.localBanner = nil } else { $0.localAvatar = nil } }
        }))
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        self.presentNative(alert)
    }

    private func usdAmount(ton: Int64) -> Int64? {
        guard let rate = self.context.currentAppConfiguration.with({ $0 }).data?["ton_usd_rate"] as? Double, rate.isFinite, rate > 0 else { return nil }
        var amount = Decimal(ton) / 1_000_000_000 * Decimal(rate) * 100
        var rounded = Decimal(); NSDecimalRound(&rounded, &amount, 0, .plain)
        guard rounded >= 0, rounded <= Decimal(Int64.max) else { return nil }
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    private func resolvePerson(_ input: String, completion: @escaping (EnginePeer?) -> Void) {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw = Int64(value), raw > 0 {
            self.disposables.add((self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: EnginePeer.Id(raw))) |> deliverOnMainQueue).start(next: { peer in
                if let peer, case .user = peer { completion(peer) } else { completion(nil) }
            }))
        } else {
            let name = value.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            self.disposables.add((self.context.engine.peers.resolvePeerByName(name: name, referrer: nil) |> deliverOnMainQueue).start(next: { result in
                guard case let .result(peer) = result else { return }
                if let peer, case .user = peer { completion(peer) } else { completion(nil) }
            }))
        }
    }

    private func editUsername(index: Int?) {
        let item = index.flatMap { self.appearance.usernames.indices.contains($0) ? self.appearance.usernames[$0] : nil }
        let originalName = item?.name
        self.controller?.push(VisualGramDetailsController(context: self.context, title: "NFT-юзернейм", fields: [("Юзернейм без @", item?.name ?? ""), ("Цена TON", item.map { VisualGramLocalAppearance.formatGrams($0.tonAmount) } ?? "")], date: item?.purchaseDate ?? Int32(clamping: Int64(Date().timeIntervalSince1970)), tonIndex: 1, save: { [weak self] texts, date in
            guard let self, texts.count == 2 else { return false }
            let name = texts[0].trimmingCharacters(in: CharacterSet(charactersIn: "@ "))
            guard name.range(of: "^[A-Za-z][A-Za-z0-9_]{3,31}$", options: .regularExpression) != nil, let ton = VisualGramLocalAppearance.parseGrams(texts[1]), let usd = self.usdAmount(ton: ton) else { self.message("Проверь юзернейм и цену. Для расчёта USDT нужен загруженный курс TON."); return false }
            guard !self.appearance.usernames.contains(where: { $0.name.lowercased() == name.lowercased() && $0.name.lowercased() != originalName?.lowercased() }) else { self.message("Этот юзернейм уже добавлен."); return false }
            if let originalName, !self.appearance.usernames.contains(where: { $0.name == originalName }) { self.message("Этот юзернейм уже удалён."); return false }
            let username = VisualGramUsername(name: name, purchaseDate: date, tonAmount: ton, usdAmount: usd)
            self.update { value in
                value.enabled = true
                if let originalName, let position = value.usernames.firstIndex(where: { $0.name == originalName }) { value.usernames[position] = username }
                else { value.usernames.append(username) }
            }
            return true
        }))
    }

    private func selectTarget() {
        self.form(title: "Чей профиль оформить", fields: [("@юзернейм или ID (пусто — мой профиль)", self.targetPeerId == self.context.account.peerId ? "" : String(self.targetPeerId.toInt64()))]) { [weak self] texts in
            guard let self, let input = texts.first else { return }
            if input.isEmpty {
                self.targetPeerId = self.context.account.peerId; self.targetTitle = "Мой профиль"
                VisualGramLocalAppearance.shared.update(accountId: self.context.account.peerId) { _ in }; return
            }
            self.resolvePerson(input) { [weak self] peer in
                guard let self, let peer else { self?.message("Профиль не найден. Для неизвестного ID сначала открой чат с человеком или укажи @юзернейм."); return }
                self.targetPeerId = peer.id; self.targetTitle = peer.compactDisplayTitle
                VisualGramLocalAppearance.shared.update(accountId: self.context.account.peerId) { _ in }
            }
        }
    }

    private func editPhone() {
        let item = self.appearance.phoneNumber
        self.controller?.push(VisualGramDetailsController(context: self.context, title: "Номер профиля", fields: [("Номер: +7… или +888…", item.map { "+" + $0.name } ?? ""), ("Цена TON", item.map { VisualGramLocalAppearance.formatGrams($0.tonAmount) } ?? "")], date: item?.purchaseDate ?? Int32(clamping: Int64(Date().timeIntervalSince1970)), tonIndex: 1, phoneMode: true, save: { [weak self] texts, date in
            guard let self, texts.count == 2 else { return false }
            if texts[0].isEmpty { self.update { $0.phoneNumber = nil }; return true }
            let number = texts[0].filter { $0.isNumber }
            guard number.range(of: "^[0-9]{5,15}$", options: .regularExpression) != nil else { self.message("Проверь номер."); return false }
            var ton: Int64 = 0, usd: Int64 = 0
            if number.hasPrefix("888") {
                guard let price = VisualGramLocalAppearance.parseGrams(texts[1]), let dollar = self.usdAmount(ton: price) else { self.message("Проверь цену и подключение для загрузки курса TON."); return false }
                ton = price; usd = dollar
            }
            self.update { $0.enabled = true; $0.phoneNumber = VisualGramUsername(name: number, purchaseDate: date, tonAmount: ton, usdAmount: usd) }
            return true
        }))
    }

    private func editRating() {
        let rating = self.appearance.starRating
        self.form(title: "Уровень Telegram", fields: [("Уровень (пусто — настоящий рейтинг)", rating.map { String($0.level) } ?? ""), ("Звёзды на начало уровня", rating.map { String($0.currentLevelStars) } ?? "0"), ("Текущие звёзды рейтинга", rating.map { String($0.stars) } ?? "0"), ("Звёзды следующего уровня (необязательно)", rating?.nextLevelStars.map(String.init) ?? "1000")]) { [weak self] values in
            guard let self, values.count == 4 else { return }
            if values[0].isEmpty { self.update { $0.starRating = nil }; return }
            guard let level = Int32(values[0]), (-1...1_000_000).contains(level), let current = Int64(values[1]), let stars = Int64(values[2]) else { self.message("Проверь уровень и числа звёзд."); return }
            let next = values[3].isEmpty ? nil : Int64(values[3])
            guard values[3].isEmpty || next != nil, current != Int64.min, stars != Int64.min, current <= stars, (level < 0 ? stars < 0 && (next.map { $0 <= 0 } ?? true) : current >= 0), next.map({ $0 > stars && $0 > current }) ?? true else { self.message("Начало уровня должно быть не выше текущих звёзд, а следующий порог — выше них. Для отрицательного рейтинга укажи уровень -1, отрицательные звёзды и следующий порог не выше 0."); return }
            self.update { $0.enabled = true; $0.starRating = TelegramStarRating(level: level, currentLevelStars: current, stars: stars, nextLevelStars: next) }
        }
    }

    private func configureVerification(forceSetup: Bool = false) {
        let target = self.targetPeerId
        let alert = UIAlertController(title: "Верификация", message: nil, preferredStyle: .alert)
        for (title, source) in [("Major", "starsov"), ("Hold", "hold")] {
            alert.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] _ in
                guard let self else { return }
                self.resolvePerson(source) { [weak self] peer in
                    guard let self, let peer else { self?.message("Не удалось загрузить @" + source); return }
                    self.disposables.add((self.context.engine.peers.fetchAndUpdateCachedPeerData(peerId: peer.id)
                    |> mapToSignal { _ in self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.CachedData(id: peer.id)) }
                    |> deliverOnMainQueue).start(next: { [weak self] cached in
                        guard let self else { return }
                        let template: PeerVerification
                        if let existing = (cached as? CachedUserData)?.verification { template = existing }
                        else if let settings = (cached as? CachedUserData)?.botInfo?.verifierSettings { template = PeerVerification(botId: peer.id, iconFileId: settings.iconFileId, description: settings.customDescription ?? settings.companyName, descriptionEntities: settings.customDescriptionEntities ?? []) }
                        else { self.message("Исходный значок @" + source + " сейчас недоступен."); return }
                        VisualGramLocalAppearance.shared.update(accountId: self.context.account.peerId, targetPeerId: target) { $0.enabled = true; $0.verification = template; $0.verificationSource = source }
                    }))
                }
            }))
        }
        alert.addAction(UIAlertAction(title: "Выключить", style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            VisualGramLocalAppearance.shared.update(accountId: self.context.account.peerId, targetPeerId: target) { $0.verification = nil; $0.verificationSource = nil }
        }))
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel)); self.presentNative(alert)
    }

    private func selectEmoji() {
        guard let controller = self.controller else { return }
        self.update { $0.enabled = true; $0.premium = true }
        let current = self.appearance.emojiStatus?.fileId
        let picker = EmojiStatusSelectionController(context: self.context, mode: .customStatusSelection(completion: { [weak self] file, expiration in
            guard let self else { return }
            _ = VisualGramLocalAppearance.shared.setLocalEmojiStatus(accountId: self.context.account.peerId, targetPeerId: self.targetPeerId, status: file.map { PeerEmojiStatus(content: .emoji(fileId: $0.fileId.id), expirationDate: expiration) })
        }), sourceView: controller.view, emojiContent: EmojiPagerContentComponent.emojiInputData(context: self.context, animationCache: self.context.animationCache, animationRenderer: self.context.animationRenderer, isStandalone: false, subject: .status, hasTrending: false, topReactionItems: [], areUnicodeEmojiEnabled: false, areCustomEmojiEnabled: true, chatPeerId: self.context.account.peerId, selectedItems: [], topStatusTitle: nil, forceHasPremium: true), currentSelection: current, destinationItemView: { nil })
        picker.pushController = { [weak controller] in controller?.push($0) }
        controller.present(picker, in: .window(.root))
    }

    private func configureReceipt(direction: VisualGramGift.Direction = .received, completion: @escaping () -> Void) {
        let target = self.targetPeerId
        self.direction = direction
        weak var details: ViewController?
        let form = VisualGramDetailsController(context: self.context, title: direction == .sent ? "Отправить подарок" : "Добавить подарок", fields: [(direction == .sent ? "Получатель: @юзернейм или ID" : "Отправитель: @юзернейм или ID", ""), ("Подпись", "")], date: Int32(clamping: Int64(Date().timeIntervalSince1970)), seconds: true, save: { [weak self] texts, date in
            guard let self, self.targetPeerId == target, texts.count == 2 else { return false }
            self.giftDate = date; self.giftText = texts[1]
            if texts[0].isEmpty && direction == .received { self.counterpartyId = nil; details?.dismiss(); completion(); return false }
            self.resolvePerson(texts[0]) { [weak self] peer in
                guard let self, self.targetPeerId == target, let peer else { self?.message("Пользователь не найден или выбран другой профиль."); return }
                self.counterpartyId = peer.id.toInt64(); details?.dismiss(); completion()
            }
            return false
        })
        details = form; self.controller?.push(form)
    }

    private func selectOrdinaryGift() {
        guard let controller = self.controller, let stars = self.context.starsContext else { return }
        let options = GiftOptionsScreen(context: self.context, starsContext: stars, peerId: self.targetPeerId, premiumOptions: [], hasBirthday: false)
        options.visualGramGiftSelected = { [weak self] gift in
            self?.previewGift(gift)
        }
        controller.push(options)
    }

    private func importUniqueGift() {
        self.form(title: "Добавить NFT-подарки", fields: [("Ссылки или slug через пробел или новую строку", "")]) { [weak self] values in
            guard let self, let input = values.first else { return }
            guard let slugs = VisualGramLocalAppearance.nftSlugs(from: input) else { self.message("Вставь до 100 ссылок t.me/nft/… или slug, например PlushPepe-1. Раздели их пробелами или переносами строк."); return }
            let targetPeerId = self.targetPeerId
            let counterpartyId = self.counterpartyId, direction = self.direction, date = self.giftDate, text = self.giftText
            // Resolve in order, without opening a preview for each link. A failed link
            // aborts the batch before any profile or queue changes are committed.
            var signal: Signal<[StarGift.UniqueGift], GetUniqueStarGiftError> = .single([])
            for slug in slugs {
                signal = signal |> mapToSignal { [context = self.context] gifts in
                    context.engine.payments.getUniqueStarGift(slug: slug) |> map { gifts + [$0] }
                }
            }
            self.disposables.add((signal |> deliverOnMainQueue).start(next: { [weak self] gifts in
                guard let self else { return }
                let batch = gifts.map { VisualGramGift(gift: .unique($0), counterpartyId: counterpartyId, direction: direction, date: date, text: text) }
                guard let first = batch.first else { return }
                self.chooseGiftDelivery(first) { [weak self] deliveryDate in
                    guard let self else { return }
                    if batch.count == 1 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.showGiftPreview(first, targetPeerId: targetPeerId, deliveryDate: deliveryDate) }
                        return
                    }
                    if let deliveryDate {
                        VisualGramLocalAppearance.shared.scheduleGifts(accountId: self.context.account.peerId, targetPeerId: targetPeerId, gifts: batch, deliveryDate: deliveryDate)
                    } else {
                        VisualGramLocalAppearance.shared.addGifts(accountId: self.context.account.peerId, targetPeerId: targetPeerId, gifts: batch)
                        self.animateGiftDelivery()
                    }
                }
            }, error: { [weak self] _ in self?.message("Не удалось загрузить все подарки. Проверь ссылки и подключение; ни один подарок не добавлен.") }))
        }
    }

    private func previewGift(_ gift: StarGift) {
        let local = VisualGramGift(gift: gift, counterpartyId: self.counterpartyId, direction: self.direction, date: self.giftDate, text: self.giftText)
        let targetPeerId = self.targetPeerId
        self.chooseGiftDelivery(local) { [weak self] deliveryDate in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self?.showGiftPreview(local, targetPeerId: targetPeerId, deliveryDate: deliveryDate)
            }
        }
    }

    private func showGiftPreview(_ local: VisualGramGift, targetPeerId: EnginePeer.Id, deliveryDate: Int32?) {
        guard let controller = self.controller else { return }
        let subject: GiftViewScreen.Subject
        switch local.gift {
        case let .unique(value): subject = .uniqueGift(value, nil)
        case let .generic(value): subject = .soldOutGift(value)
        }
        let title = deliveryDate == nil ? (local.direction == .sent ? "Отправить" : "Получить") : "Отложить"
        let preview = GiftViewScreen(context: self.context, subject: subject, customAction: .init(title: title, action: { [weak self] in
            guard let self else { return }
            if let deliveryDate {
                VisualGramLocalAppearance.shared.scheduleGift(accountId: self.context.account.peerId, targetPeerId: targetPeerId, gift: local, deliveryDate: deliveryDate)
            } else {
                self.deliverGift(local, targetPeerId: targetPeerId)
            }
        }))
        preview.visualGramPreview = true
        controller.push(preview)
    }

    private func deliverGift(_ gift: VisualGramGift, targetPeerId: EnginePeer.Id) {
        VisualGramLocalAppearance.shared.addGift(accountId: self.context.account.peerId, targetPeerId: targetPeerId, gift: gift)
        self.animateGiftDelivery()
    }

    private func animateGiftDelivery() {
        guard !UIAccessibility.isReduceMotionEnabled, let view = self.controller?.navigationController?.view ?? self.controller?.view, view.window != nil else { return }
        view.addSubview(ConfettiView(frame: view.bounds))
    }

    private func chooseGiftDelivery(_ gift: VisualGramGift, completion: @escaping (Int32?) -> Void) {
        if gift.date > Int32(clamping: Int64(Date().timeIntervalSince1970)) { completion(gift.date); return }
        let receiving = gift.direction == .received
        let alert = UIAlertController(title: receiving ? "Получить подарок" : "Отправить подарок", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: receiving ? "Получить сейчас" : "Отправить сейчас", style: .default, handler: { _ in completion(nil) }))
        alert.addAction(UIAlertAction(title: receiving ? "Отложить получение" : "Отложить отправку", style: .default, handler: { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self?.pickDeliveryDate(currentTime: nil) { time in
                completion(time)
            } }
        }))
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        self.presentNative(alert)
    }

    private func pickDeliveryDate(currentTime: Int32?, completion: @escaping (Int32) -> Void) {
        self.controller?.push(VisualGramDetailsController(context: self.context, title: "Дата и время", fields: [], date: currentTime ?? Int32(clamping: Int64(Date().timeIntervalSince1970)) + 60, seconds: true, save: { [weak self] _, time in
            guard time > Int32(clamping: Int64(Date().timeIntervalSince1970)), time < Int32.max - 1 else { self?.message("Выбери время в будущем."); return false }
            completion(time); return true
        }))
    }

    private func openScheduledGift(index: Int) {
        let queue = self.scheduledGifts
        guard queue.indices.contains(index) else { return }
        let pending = queue[index]
        let alert = UIAlertController(title: "Отложенный подарок", message: self.dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(pending.deliveryDate))), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: pending.gift.direction == .received ? "Получить сейчас" : "Отправить сейчас", style: .default, handler: { _ in
            VisualGramLocalAppearance.shared.rescheduleGift(id: pending.id, deliveryDate: Int32(clamping: Int64(Date().timeIntervalSince1970)))
        }))
        alert.addAction(UIAlertAction(title: "Изменить время", style: .default, handler: { [weak self] _ in
            DispatchQueue.main.async { self?.pickDeliveryDate(currentTime: pending.deliveryDate) { time in
                VisualGramLocalAppearance.shared.rescheduleGift(id: pending.id, deliveryDate: time)
            } }
        }))
        alert.addAction(UIAlertAction(title: pending.gift.direction == .received ? "Отменить получение" : "Отменить отправку", style: .destructive, handler: { _ in
            VisualGramLocalAppearance.shared.cancelScheduledGift(id: pending.id)
        }))
        alert.addAction(UIAlertAction(title: "Назад", style: .cancel))
        self.presentNative(alert)
    }

    private func openUsernames() {
        let target = self.targetPeerId, account = self.context.account.peerId
        self.controller?.push(VisualGramListController(context: self.context, target: target, title: "Юзернеймы", rows: {
            VisualGramLocalAppearance.shared.appearance(accountId: account, targetPeerId: target).usernames.map { .init(id: $0.name.lowercased(), title: "@" + $0.name, subtitle: VisualGramLocalAppearance.formatGrams($0.tonAmount) + " TON", gift: nil) }
        }, reorder: { ids in
            var saved = false
            VisualGramLocalAppearance.shared.update(accountId: account, targetPeerId: target) { value in
                guard ids.count == value.usernames.count, Set(ids).count == ids.count, Set(ids) == Set(value.usernames.map { $0.name.lowercased() }) else { return }
                value.usernames = ids.compactMap { id in value.usernames.first(where: { $0.name.lowercased() == id }) }; saved = true
            }
            return saved
        }, open: { [weak self] id in self?.editUsernameNamed(id) }, edit: { [weak self] id in self?.editUsernameNamed(id) }, delete: { id in
            VisualGramLocalAppearance.shared.update(accountId: account, targetPeerId: target) { $0.usernames.removeAll { $0.name.lowercased() == id } }
        }))
    }

    private func editUsernameNamed(_ id: String) {
        guard let index = self.appearance.usernames.firstIndex(where: { $0.name.lowercased() == id }) else { return }
        self.editUsername(index: index)
    }

    private func openGiftList(history: Bool) {
        guard history else { self.showGiftList(history: false, names: [:]); return }
        let operations = VisualGramLocalAppearance.giftOperations(in: self.appearance)
        let ids = Set(operations.flatMap { self.operationParticipants($0).compactMap { $0 } })
        self.loadOperationNames(ids: ids) { [weak self] names in self?.showGiftList(history: true, names: names) }
    }

    private func operationParticipants(_ item: VisualGramGift) -> [Int64?] {
        if item.operationEventId != nil { return [item.operationSenderId, item.operationRecipientId] }
        if item.direction == .sent { return [self.targetPeerId.toInt64(), item.counterpartyId] }
        return [item.counterpartyId, self.targetPeerId.toInt64()]
    }

    private func loadOperationNames(ids: Set<Int64>, completion: @escaping ([Int64: String]) -> Void) {
        guard !ids.isEmpty else { completion([:]); return }
        self.disposables.add((self.context.engine.data.get(EngineDataMap(ids.map { TelegramEngine.EngineData.Item.Peer.Peer(id: EnginePeer.Id($0)) })) |> deliverOnMainQueue).start(next: { peers in
            var names: [Int64: String] = [:]
            for (id, peer) in peers { if let peer { names[id.toInt64()] = peer.compactDisplayTitle } }
            completion(names)
        }))
    }

    private func operationTitle(_ item: VisualGramGift) -> String {
        switch item.operationKind {
        case .craft: return item.operationSucceeded == false ? "Крафт — неудача" : "Крафт"
        case .upgrade: return "Улучшение"
        case .purchase: return "Покупка"
        default: return item.direction == .sent ? "Отправка" : "Получение"
        }
    }

    private func showGiftList(history: Bool, names: [Int64: String]) {
        let target = self.targetPeerId, account = self.context.account.peerId
        let formatter = DateFormatter(); formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        self.controller?.push(VisualGramListController(context: self.context, target: target, title: history ? "История операций" : "Мои подарки", rows: { [weak self] in
            guard let self else { return [] }
            let value = VisualGramLocalAppearance.shared.appearance(accountId: account, targetPeerId: target)
            let gifts = history ? VisualGramLocalAppearance.giftOperations(in: value) : VisualGramLocalAppearance.orderedOwnedGifts(in: value)
            var rows: [VisualGramListRow] = gifts.map { local in
                let title: String
                switch local.gift { case let .unique(gift): title = "\(gift.title) #\(gift.number)"; case let .generic(gift): title = gift.title ?? "Подарок" }
                let operation = self.operationTitle(local)
                let people = self.operationParticipants(local)
                let name: (Int64?) -> String = { id in id.map { names[$0] ?? "ID \($0)" } ?? "Не указан" }
                let parties = local.operationKind == .craft || local.operationKind == .upgrade ? "" : "\(name(people[0])) → \(name(people[1]))\n"
                return .init(id: local.identifier, title: history ? operation + " · " + title : title, subtitle: (history ? parties : "") + formatter.string(from: Date(timeIntervalSince1970: TimeInterval(local.date))), gift: local)
            }
            if history {
                for pending in VisualGramLocalAppearance.shared.pendingScheduledGifts where pending.targetPeerId == target.toInt64() {
                    let title: String
                    switch pending.gift.gift { case let .unique(gift): title = "\(gift.title) #\(gift.number)"; case let .generic(gift): title = gift.title ?? "Подарок" }
                    rows.append(.init(id: "pending:" + pending.id, title: title, subtitle: "Отложено · " + formatter.string(from: Date(timeIntervalSince1970: TimeInterval(pending.deliveryDate))), gift: pending.gift))
                }
            }
            return rows
        }, reorder: history ? nil : { ids in VisualGramLocalAppearance.shared.saveGiftOrder(accountId: account, targetPeerId: target, identifiers: ids) }, open: { [weak self] id in
            guard let self else { return }
            if history { self.openOperation(id) }
            else if let index = self.appearance.gifts.firstIndex(where: { $0.identifier == id }) { self.openGift(index: index) }
        }, edit: { [weak self] id in self?.editGiftDetails(id: id, history: history) }, delete: { [weak self] id in
            if id.hasPrefix("pending:") { VisualGramLocalAppearance.shared.cancelScheduledGift(id: String(id.dropFirst(8))) }
            else if history {
                switch VisualGramLocalAppearance.shared.cancelGiftOperation(accountId: account, targetPeerId: target, identifier: id) {
                case .success: break
                case .legacyUnavailable: self?.message("Эта запись создана старой версией без снимка для отмены. Точно восстановить её состояние невозможно; запись не удалена.")
                case .dependentOperation: self?.message("Подарок уже изменён, передан или использован в следующей операции. Сначала отмени более позднюю операцию.")
                case .balanceChanged: self?.message("Для отмены недостаточно текущего баланса либо изменились данные покупки. Сначала отмени зависимые покупки.")
                default: self?.message("Операция недоступна или её данные изменились. Ничего не отменено.")
                }
            } else { VisualGramLocalAppearance.shared.removeLocalGifts(accountId: account, targetPeerId: target, identifiers: [id]) }
        }, deleteTitle: history ? "Отменить операцию" : "Удалить", deleteConfirmation: history ? "Операция будет отменена: связанные подарки и списания будут восстановлены. Запись исчезнет у всех её участников. Если есть зависимые действия, сначала нужно отменить их." : nil))
    }

    private func operation(_ id: String, history: Bool) -> VisualGramGift? {
        if id.hasPrefix("pending:") { return self.scheduledGifts.first(where: { $0.id == String(id.dropFirst(8)) })?.gift }
        return history ? VisualGramLocalAppearance.giftOperations(in: self.appearance).first(where: { $0.identifier == id }) : self.appearance.gifts.first(where: { $0.identifier == id && $0.isHistoryOnly != true && $0.direction == .received })
    }

    private func openOperation(_ id: String) {
        guard let local = self.operation(id, history: true) else { return }
        if id.hasPrefix("pending:") { self.editGiftDetails(id: id, history: true); return }
        let participants = self.operationParticipants(local)
        let ids = Set(participants.compactMap { $0 })
        let target = self.targetPeerId
        self.loadOperationNames(ids: ids) { [weak self] names in
            guard let self else { return }
            let name: (Int64?) -> String = { id in id.map { names[$0] ?? "ID \($0)" } ?? "Не указан" }
            var rows: [VisualGramListRow] = []
            let formatter = DateFormatter(); formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
            rows.append(.init(id: "event", title: self.operationTitle(local), subtitle: formatter.string(from: Date(timeIntervalSince1970: TimeInterval(local.date))), gift: nil))
            if local.operationKind == .craft || local.operationKind == .upgrade {
                rows.append(.init(id: "owner", title: "Профиль", subtitle: name(participants[1]), gift: nil))
            } else {
                rows.append(.init(id: "from", title: local.operationKind == .purchase ? "Покупатель" : "От кого", subtitle: name(participants[0]), gift: nil))
                rows.append(.init(id: "to", title: "Кому", subtitle: name(participants[1]), gift: nil))
            }
            func addGift(_ gift: StarGift, title: String, id: String) {
                let label: String
                switch gift { case let .unique(gift): label = "\(gift.title) #\(gift.number)"; case let .generic(gift): label = gift.title ?? "Подарок" }
                let preview = VisualGramGift(gift: gift, counterpartyId: nil, date: local.date, text: "")
                rows.append(.init(id: id, title: title, subtitle: label, gift: preview))
            }
            for (index, gift) in (local.operationInputs ?? []).enumerated() { addGift(gift, title: local.operationKind == .upgrade ? "До улучшения" : "Использован NFT", id: "input:\(index)") }
            if local.operationKind == .craft && local.operationEventId == nil {
                rows.append(.init(id: "legacy", title: "Старая запись", subtitle: "Полный состав и результат этой операции не сохранялись старой версией.", gift: nil))
                if local.isCrafted == true { addGift(local.gift, title: "Сохранённый результат", id: "result") }
            } else if local.operationKind == .craft && local.operationSucceeded == false {
                rows.append(.init(id: "failed", title: "Результат: неудача", subtitle: "Новый NFT не получен. Выбранные подарки израсходованы.", gift: nil))
            } else { addGift(local.operationResult ?? local.gift, title: local.operationKind == .upgrade ? "После улучшения" : "Результат", id: "result") }
            if !local.text.isEmpty { rows.append(.init(id: "caption", title: "Подпись", subtitle: local.text, gift: nil)) }
            self.controller?.push(VisualGramListController(context: self.context, target: target, title: "Операция", rows: { rows }, reorder: nil, open: { _ in }, edit: { _ in }, delete: { _ in }, allowsEditing: false))
        }
    }

    private func editGiftDetails(id: String, history: Bool) {
        guard let local = self.operation(id, history: history) else { return }
        let target = self.targetPeerId
        let initialDate = id.hasPrefix("pending:") ? self.scheduledGifts.first(where: { $0.id == String(id.dropFirst(8)) })?.deliveryDate ?? local.date : local.date
        weak var details: ViewController?
        let form = VisualGramDetailsController(context: self.context, title: "Данные подарка", fields: [(local.direction == .sent ? "Получатель: @юзернейм или ID" : "Отправитель: @юзернейм или ID", local.counterpartyId.map(String.init) ?? ""), ("Подпись", local.text)], date: initialDate, seconds: true, save: { [weak self] texts, date in
            guard let self, texts.count == 2 else { return false }
            let apply: (Int64?) -> Void = { [weak self] person in
                guard let self else { return }
                if id.hasPrefix("pending:") {
                    guard date > Int32(clamping: Int64(Date().timeIntervalSince1970)) else { self.message("Выбери время в будущем."); return }
                    var gift = local; gift.counterpartyId = person; gift.date = date; gift.text = texts[1]
                    VisualGramLocalAppearance.shared.editScheduledGift(id: String(id.dropFirst(8)), gift: gift, deliveryDate: date)
                } else {
                    guard VisualGramLocalAppearance.shared.editGiftDetails(accountId: self.context.account.peerId, targetPeerId: target, identifier: id, history: history, counterpartyId: person, date: date, text: texts[1]) else { self.message("Запись изменилась или у получателя уже есть этот NFT."); return }
                }
                details?.dismiss()
            }
            if texts[0].isEmpty { apply(nil) }
            else { self.resolvePerson(texts[0]) { [weak self] peer in guard let peer else { self?.message("Пользователь не найден."); return }; apply(peer.id.toInt64()) } }
            return false
        })
        details = form; self.controller?.push(form)
    }

    private func openGift(index: Int) {
        guard self.appearance.gifts.indices.contains(index), self.controller != nil else { return }
        let local = self.appearance.gifts[index]
            let show: (EnginePeer?) -> Void = { [weak self] sender in
                guard let self else { return }
                let screen: GiftViewScreen
                if local.direction == .sent {
                    let subject: GiftViewScreen.Subject
                    switch local.displayGift(accountId: self.targetPeerId) {
                    case let .unique(gift): subject = .uniqueGift(gift, nil)
                    case let .generic(gift): subject = .soldOutGift(gift)
                    }
                    screen = GiftViewScreen(context: self.context, subject: subject, customAction: .init(title: "Удалить", action: { [weak self] in
                        guard let self else { return }
                        VisualGramLocalAppearance.shared.removeLocalGifts(accountId: self.context.account.peerId, targetPeerId: self.targetPeerId, identifiers: [local.identifier])
                    }))
                    screen.visualGramPreview = true
                } else {
                    screen = GiftViewScreen(context: self.context, subject: .profileGift(self.targetPeerId, local.profileGift(accountId: self.targetPeerId, sender: sender)))
                }
                self.controller?.push(screen)
            }
            if let senderId = local.counterpartyId {
                self.disposables.add((self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: EnginePeer.Id(senderId))) |> deliverOnMainQueue).start(next: show))
            } else { show(nil) }
    }

}

func visualGramAppearanceController(context: AccountContext) -> ViewController {
    return visualGramAppearanceController(context: context, initialSection: -1, targetPeerId: nil, targetTitle: nil)
}

private func visualGramAppearanceController(context: AccountContext, initialSection: Int32, targetPeerId: EnginePeer.Id?, targetTitle: String?) -> ViewController {
    let actions = VisualGramAppearanceActions(context: context)
    actions.currentSection = initialSection
    actions.activeSection.set(initialSection)
    if let targetPeerId { actions.targetPeerId = targetPeerId }
    if let targetTitle { actions.targetTitle = targetTitle }
    let signal = combineLatest(context.sharedContext.presentationData, VisualGramLocalAppearance.shared.changes, actions.expandedLists.get(), actions.activeSection.get())
    |> deliverOnMainQueue
    |> map { presentationData, _, _, activeSection -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let value = actions.appearance
        var entries: [VisualGramAppearanceEntry] = []
        func add(_ id: Int32, _ section: Int32, _ title: String, _ kind: VisualGramAppearanceEntry.Kind) {
            entries.append(VisualGramAppearanceEntry(stableId: id, section: section, title: title, kind: kind, theme: presentationData.theme))
        }
        if activeSection == -1 {
            add(7, -1, "Выбор профиля", .button(actions.targetTitle))
            add(900, 0, "Профиль", .button("")); add(901, 0, "Подарки", .button("")); add(902, 0, "Балансы", .button(""))
            add(904, 1, "Локальный профиль", .button("Имя, фото и баннер"))
            add(905, 1, "Приватность и отображение", .button("Для всех аккаунтов"))
        } else {
            switch activeSection {
            case 0:
                add(1, 0, "Telegram Premium", .toggle(value.premium))
                add(2, 0, "Галочка Telegram", .toggle(value.verified))
                add(3, 0, "Верификация", .button(value.verification == nil ? "Выключена" : (value.verificationSource == "hold" ? "Hold" : "Major")))
                add(10, 1, "Добавить NFT-юзернейм", .button(""))
                add(11, 1, "Номер профиля", .button(value.phoneNumber.map { "+" + $0.name } ?? ""))
                add(12, 1, "Уровень", .button(value.starRating.map { String($0.level) } ?? "Настоящий"))
                add(13, 1, "Юзернеймы", .button(String(value.usernames.count)))
                add(14, 2, "Цвета и фон профиля", .button(""))
                add(15, 2, "Часы работы", .button("")); add(16, 2, "Адрес", .button(""))
            case 1:
                add(24, 0, "Добавить NFT", .button("")); add(20, 0, "Добавить обычный подарок", .button(""))
                add(23, 1, "Отправить NFT", .button("")); add(22, 1, "Отправить обычный подарок", .button(""))
                add(27, 2, "Мои подарки", .button("")); add(26, 2, "История операций", .button(""))
            case 2:
                add(30, 0, "Баланс звёзд", .button(value.stars.map(String.init) ?? "Настоящий баланс"))
                add(31, 0, "Добавить операцию", .button(""))
                add(32, 1, "Баланс GRAM", .button(value.grams.map { VisualGramLocalAppearance.formatGrams($0) } ?? "Не задан"))
                add(33, 1, "Оформить карточку GRAM", .button(""))
            case 3:
                add(50, 0, "Имя", .button(value.localName ?? "Как в Telegram"))
                add(51, 0, "Юзернейм", .button(value.localUsername.map { "@" + $0 } ?? "Как в Telegram"))
                add(52, 0, "Описание", .button(value.localBio ?? "Как в Telegram"))
                add(53, 1, "Аватар", .button(value.localAvatar == nil ? "Как в Telegram" : "Локальное фото"))
                add(54, 1, "Баннер", .button(value.localBanner == nil ? "Не задан" : "Локальное фото"))
                add(55, 2, "Вернуть исходный профиль", .button(""))
            default:
                let settings = VisualGramLocalAppearance.shared.deviceSettings
                add(100, 0, "Режим призрака", .toggle(settings.ghostMode))
                add(101, 0, "Скрывать рекламу каналов", .toggle(settings.hideSponsoredMessages))
                add(102, 1, "Локальный вид Premium", .toggle(settings.localPremiumPresentation))
                add(103, 1, "Подтверждать отправку медиа", .toggle(settings.confirmMediaSends))
                add(104, 2, "История изменений и удалений", .toggle(settings.messageHistoryEnabled))
                add(105, 2, "Снимки в защищённых чатах", .toggle(settings.allowProtectedScreenshots))
                add(122, 2, "Автосохранять медиа с таймером", .toggle(settings.keepTimedMedia))
                add(120, 2, "Открыть историю сообщений", .button(""))
                add(121, 2, "Очистить историю сообщений", .button(""))
                add(110, 3, "Скрываемые слова", .button(settings.filteredWords.isEmpty ? "Не заданы" : String(settings.filteredWords.count)))
                add(130, 3, "Иконка приложения", .button("Встроенные иконки Telegram"))
                add(111, 4, "Режим призрака оставляет чаты непрочитанными на этом устройстве. Другие ваши устройства могут отправить отметку о прочтении.", .info)
                add(112, 4, "Локальный вид Premium не оформляет подписку и не снимает серверные ограничения.", .info)
                add(113, 4, "«Сохранить в Фото» помещает фото или видео в галерею iPhone. Автосохранение медиа с таймером внутри чата включается отдельно и исходно выключено.", .info)
                add(114, 4, "Подтверждение действует для стикеров, GIF и голосовых сообщений.", .info)
                add(115, 4, "Свою картинку иконки нужно включить в следующую сборку приложения. Здесь доступны встроенные варианты Telegram.", .info)
            }
        }
        entries.sort()
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(activeSection == -1 ? "VisualGram" : ["Профиль", "Подарки", "Балансы", "Локальный профиль", "Приватность"][Int(activeSection)]), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: activeSection == -1 ? presentationData.strings.Common_Back : "VisualGram"))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, actions))
    }
    let controller = ItemListController(context: context, state: signal)
    actions.controller = controller
    return controller
}
