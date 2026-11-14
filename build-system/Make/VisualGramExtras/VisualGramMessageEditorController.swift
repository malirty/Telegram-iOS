import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData

/// Edits only the local presentation overlay. The underlying Postbox message is untouched.
final class VisualGramMessageEditorController: ViewController, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private enum Mark {
        static let bold = NSAttributedString.Key("visualGram.bold")
        static let italic = NSAttributedString.Key("visualGram.italic")
        static let underline = NSAttributedString.Key("visualGram.underline")
        static let strike = NSAttributedString.Key("visualGram.strike")
        static let code = NSAttributedString.Key("visualGram.code")
        static let spoiler = NSAttributedString.Key("visualGram.spoiler")
        static let quote = NSAttributedString.Key("visualGram.quote")
        static let link = NSAttributedString.Key("visualGram.link")
    }

    private let context: AccountContext
    private let message: EngineMessage
    private let textView = UITextView()
    private let hint = UILabel()
    private let formatBar = UIScrollView()
    private let photoPreview = UIImageView()
    private var formatButtons: [UIButton] = []
    private var localImage: VisualGramLocalImage?
    private var hasSaved = false

    init(context: AccountContext, message: EngineMessage) {
        self.context = context
        self.message = message
        self.localImage = VisualGramLocalAppearance.shared.messageOverride(message.id)?.image
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: context.sharedContext.currentPresentationData.with { $0 }))
        self.title = "Изменить локально"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Сохранить", style: .done, target: self, action: #selector(self.save))
        self.attemptNavigation = { [weak self] continueNavigation in
            guard let self, !self.hasSaved else { return true }
            let alert = UIAlertController(title: "Закрыть редактор?", message: "Несохранённые изменения будут потеряны.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Продолжить", style: .cancel))
            alert.addAction(UIAlertAction(title: "Закрыть", style: .destructive, handler: { _ in continueNavigation() }))
            self.present(alert, animated: true)
            return false
        }
    }

    required init(coder: NSCoder) { preconditionFailure() }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNodeDidLoad()
        let theme = self.context.sharedContext.currentPresentationData.with { $0 }.theme
        self.displayNode.backgroundColor = theme.list.blocksBackgroundColor

        self.hint.text = "Выдели текст, затем выбери оформление. Изменения видны только на этом устройстве."
        self.hint.textColor = theme.list.itemSecondaryTextColor
        self.hint.font = UIFont.preferredFont(forTextStyle: .footnote)
        self.hint.adjustsFontForContentSizeCategory = true
        self.hint.numberOfLines = 0
        self.view.addSubview(self.hint)

        self.textView.delegate = self
        self.textView.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.textView.textColor = theme.list.itemPrimaryTextColor
        self.textView.font = UIFont.preferredFont(forTextStyle: .body)
        self.textView.adjustsFontForContentSizeCategory = true
        self.textView.layer.cornerRadius = 14
        self.textView.textContainerInset = UIEdgeInsets(top: 14, left: 10, bottom: 14, right: 10)
        self.textView.keyboardDismissMode = .interactive
        self.textView.dataDetectorTypes = []
        self.textView.accessibilityLabel = "Текст локального сообщения"
        self.view.addSubview(self.textView)
        self.loadOriginalFormatting()

        self.formatBar.showsHorizontalScrollIndicator = false
        self.view.addSubview(self.formatBar)
        let titles = ["Ж", "К", "Ч", "З", "{}", "◌", "Цитата", "Ссылка", "Фото"]
        for (index, title) in titles.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.backgroundColor = theme.list.itemBlocksBackgroundColor
            button.tintColor = theme.list.itemAccentColor
            button.layer.cornerRadius = 10
            button.addTarget(self, action: #selector(self.formatPressed(_:)), for: .touchUpInside)
            button.accessibilityLabel = ["Жирный", "Курсив", "Подчёркнутый", "Зачёркнутый", "Моноширинный", "Спойлер", "Цитата", "Добавить ссылку", "Добавить фото"][index]
            self.formatBar.addSubview(button)
            self.formatButtons.append(button)
        }
        self.photoPreview.contentMode = .scaleAspectFill
        self.photoPreview.clipsToBounds = true
        self.photoPreview.layer.cornerRadius = 9
        self.view.addSubview(self.photoPreview)
        self.updatePhotoPreview()
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        let left = layout.safeInsets.left + 16
        let width = max(0, layout.size.width - layout.safeInsets.left - layout.safeInsets.right - 32)
        let bottom = max(layout.inputHeight ?? 0, layout.intrinsicInsets.bottom)
        let availableHeight = max(0, layout.size.height - bottom - top)
        let showHint = availableHeight >= 180
        self.hint.isHidden = !showHint
        let hintHeight = showHint ? min(ceil(self.hint.sizeThatFits(CGSize(width: max(0, width - 4), height: .greatestFiniteMagnitude)).height), availableHeight * 0.27) : 0
        self.hint.frame = CGRect(x: left + 2, y: top + 12, width: max(0, width - 4), height: hintHeight)
        let barHeight = min(64, max(48, UIFont.preferredFont(forTextStyle: .body).lineHeight + 18))
        let barY = max(top, layout.size.height - bottom - barHeight - 10)
        self.formatBar.frame = CGRect(x: left, y: barY, width: width, height: barHeight)
        var x: CGFloat = 0
        for (index, button) in self.formatButtons.enumerated() {
            let minimumWidth: CGFloat = index == 6 || index == 7 ? 90 : (index == 8 ? 68 : 48)
            let buttonWidth = max(minimumWidth, ceil(button.titleLabel?.sizeThatFits(CGSize(width: .greatestFiniteMagnitude, height: barHeight)).width ?? 0) + 20)
            button.frame = CGRect(x: x, y: 0, width: buttonWidth, height: barHeight - 4)
            x += buttonWidth + 7
        }
        self.formatBar.contentSize = CGSize(width: x, height: barHeight)
        let editorY = top + (showHint ? hintHeight + 22 : 12)
        self.textView.frame = CGRect(x: left, y: editorY, width: width, height: max(0, barY - editorY - 10))
        self.photoPreview.frame = CGRect(x: self.textView.frame.maxX - 60, y: self.textView.frame.maxY - 60, width: 48, height: 48)
        self.photoPreview.isHidden = self.localImage == nil || self.textView.frame.height < 64
    }

    private func loadOriginalFormatting() {
        let local = VisualGramLocalAppearance.shared.messageOverride(self.message.id)
        let text = local?.text ?? self.message.text
        let value = NSMutableAttributedString(string: text)
        // Automatic URL and phone entities are intentionally omitted: their
        // ranges belong to the original server text, not a local replacement.
        let originalEntities = self.message._asMessage().attributes.compactMap { $0 as? TextEntitiesMessageAttribute }.first?.entities ?? []
        let entities = local?.text == nil ? originalEntities : (local?.entities ?? [])
        for entity in entities {
            let range = NSRange(location: entity.range.lowerBound, length: entity.range.count)
            guard range.location >= 0, range.length > 0, NSMaxRange(range) <= value.length else { continue }
            switch entity.type {
            case .Bold: value.addAttribute(Mark.bold, value: true, range: range)
            case .Italic: value.addAttribute(Mark.italic, value: true, range: range)
            case .Underline: value.addAttribute(Mark.underline, value: true, range: range)
            case .Strikethrough: value.addAttribute(Mark.strike, value: true, range: range)
            case .Code: value.addAttribute(Mark.code, value: true, range: range)
            case .Spoiler: value.addAttribute(Mark.spoiler, value: true, range: range)
            case .BlockQuote: value.addAttribute(Mark.quote, value: true, range: range)
            case let .TextUrl(url): value.addAttribute(Mark.link, value: url, range: range)
            default: break
            }
        }
        self.renderFormatting(value, selectedRange: NSRange(location: value.length, length: 0))
    }

    private func renderFormatting(_ value: NSMutableAttributedString, selectedRange: NSRange) {
        let theme = self.context.sharedContext.currentPresentationData.with { $0 }.theme
        let full = NSRange(location: 0, length: value.length)
        let snapshot = NSAttributedString(attributedString: value)
        for key in [NSAttributedString.Key.font, .foregroundColor, .backgroundColor, .underlineStyle, .strikethroughStyle] {
            value.removeAttribute(key, range: full)
        }
        snapshot.enumerateAttributes(in: full, options: []) { attributes, range, _ in
            let base = UIFont.preferredFont(forTextStyle: .body)
            let isBold = attributes[Mark.bold] != nil
            let isItalic = attributes[Mark.italic] != nil
            let font: UIFont
            if attributes[Mark.code] != nil {
                font = UIFont.monospacedSystemFont(ofSize: base.pointSize, weight: isBold ? .semibold : .regular)
            } else {
                var traits: UIFontDescriptor.SymbolicTraits = []
                if isBold { traits.insert(.traitBold) }
                if isItalic { traits.insert(.traitItalic) }
                font = base.fontDescriptor.withSymbolicTraits(traits).map { UIFont(descriptor: $0, size: base.pointSize) } ?? base
            }
            value.addAttribute(.font, value: font, range: range)
            value.addAttribute(.foregroundColor, value: attributes[Mark.link] == nil ? theme.list.itemPrimaryTextColor : theme.list.itemAccentColor, range: range)
            if attributes[Mark.underline] != nil || attributes[Mark.link] != nil { value.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
            if attributes[Mark.strike] != nil { value.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
            if attributes[Mark.spoiler] != nil { value.addAttribute(.backgroundColor, value: theme.list.itemSecondaryTextColor.withAlphaComponent(0.25), range: range) }
            if attributes[Mark.quote] != nil { value.addAttribute(.backgroundColor, value: theme.list.itemAccentColor.withAlphaComponent(0.12), range: range) }
        }
        self.textView.attributedText = value
        self.textView.selectedRange = selectedRange
    }

    @objc private func formatPressed(_ button: UIButton) {
        if button.tag == 8 { self.choosePhoto(); return }
        let range = self.textView.selectedRange
        guard range.length > 0 else {
            self.showMessage("Сначала выдели часть сообщения.")
            return
        }
        if button.tag == 7 { self.editLink(range: range); return }
        let keys = [Mark.bold, Mark.italic, Mark.underline, Mark.strike, Mark.code, Mark.spoiler, Mark.quote]
        guard keys.indices.contains(button.tag) else { return }
        let key = keys[button.tag]
        let value = NSMutableAttributedString(attributedString: self.textView.attributedText)
        if value.attribute(key, at: range.location, effectiveRange: nil) == nil {
            value.addAttribute(key, value: true, range: range)
        } else {
            value.removeAttribute(key, range: range)
        }
        self.renderFormatting(value, selectedRange: range)
        self.textView.becomeFirstResponder()
    }

    private func editLink(range: NSRange) {
        let existing = self.textView.attributedText.attribute(Mark.link, at: range.location, effectiveRange: nil) as? String
        let alert = UIAlertController(title: "Ссылка", message: "Адрес откроется только при нажатии на выделенный текст.", preferredStyle: .alert)
        alert.addTextField { field in field.placeholder = "https://example.com"; field.text = existing; field.keyboardType = .URL; field.autocapitalizationType = .none }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        if existing != nil {
            alert.addAction(UIAlertAction(title: "Убрать ссылку", style: .destructive, handler: { [weak self] _ in
                guard let self else { return }
                let value = NSMutableAttributedString(attributedString: self.textView.attributedText)
                value.removeAttribute(Mark.link, range: range)
                self.renderFormatting(value, selectedRange: range)
            }))
        }
        alert.addAction(UIAlertAction(title: "Добавить", style: .default, handler: { [weak self, weak alert] _ in
            guard let self, let url = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let components = URLComponents(string: url), ["http", "https"].contains(components.scheme?.lowercased() ?? ""), components.host != nil else {
                self?.showMessage("Укажи адрес http:// или https://.")
                return
            }
            let value = NSMutableAttributedString(attributedString: self.textView.attributedText)
            value.addAttribute(Mark.link, value: url, range: range)
            self.renderFormatting(value, selectedRange: range)
        }))
        self.present(alert, animated: true)
    }

    private func choosePhoto() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        self.present(picker, animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage, let saved = VisualGramLocalAppearance.saveImage(image) else {
            self.showMessage("Не удалось сохранить фото.")
            return
        }
        self.localImage = saved
        self.updatePhotoPreview()
    }

    private func updatePhotoPreview() {
        if let image = self.localImage, let url = VisualGramLocalAppearance.imageURL(image) {
            self.photoPreview.image = UIImage(contentsOfFile: url.path)
            self.photoPreview.isHidden = self.textView.frame.height < 64
        } else {
            self.photoPreview.image = nil
            self.photoPreview.isHidden = true
        }
    }

    private func collectEntities() -> [MessageTextEntity] {
        let text = self.textView.attributedText ?? NSAttributedString(string: "")
        let full = NSRange(location: 0, length: text.length)
        var entities: [MessageTextEntity] = []
        let simple: [(NSAttributedString.Key, MessageTextEntityType)] = [
            (Mark.bold, .Bold), (Mark.italic, .Italic), (Mark.underline, .Underline),
            (Mark.strike, .Strikethrough), (Mark.code, .Code), (Mark.spoiler, .Spoiler),
            (Mark.quote, .BlockQuote(isCollapsed: false))
        ]
        for (key, type) in simple {
            text.enumerateAttribute(key, in: full, options: []) { value, range, _ in
                if value != nil, range.length > 0 { entities.append(MessageTextEntity(range: range.location ..< NSMaxRange(range), type: type)) }
            }
        }
        text.enumerateAttribute(Mark.link, in: full, options: []) { value, range, _ in
            if let url = value as? String, range.length > 0 {
                entities.append(MessageTextEntity(range: range.location ..< NSMaxRange(range), type: .TextUrl(url: url)))
            }
        }
        return entities.sorted { $0.range.lowerBound == $1.range.lowerBound ? $0.range.upperBound < $1.range.upperBound : $0.range.lowerBound < $1.range.lowerBound }
    }

    @objc private func save() {
        let text = self.textView.text ?? ""
        let entities = self.collectEntities()
        let image = self.localImage
        VisualGramLocalAppearance.shared.updateMessage(self.message.id) { value in
            value.text = text
            value.entities = entities
            value.image = image
        }
        self.hasSaved = true
        self.dismiss()
    }

    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: "VisualGram", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
}
