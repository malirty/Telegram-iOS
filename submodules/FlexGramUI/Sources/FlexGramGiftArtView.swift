import UIKit
import ComponentFlow
import GiftItemComponent
import TelegramCore
import TelegramPresentationData
import AccountContext
import FlexGram

/// Uses Telegram's gift renderer and catalogue media without creating a server-side gift.
public final class FlexGramGiftArtView: UIView {
    private let context: AccountContext
    private let componentView = ComponentView<Empty>()
    private let fallbackView = UIImageView(image: UIImage(systemName: "gift.fill"))
    private var gift: FlexGramGift?
    private var presentationData: PresentationData?

    public init(context: AccountContext) {
        self.context = context
        super.init(frame: .zero)
        self.clipsToBounds = true
        self.layer.cornerRadius = 12.0
        self.fallbackView.contentMode = .scaleAspectFit
        self.addSubview(self.fallbackView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setGift(_ gift: FlexGramGift, presentationData: PresentationData) {
        self.gift = gift
        self.presentationData = presentationData
        self.accessibilityLabel = "Локальный подарок: \(gift.kind)"
        self.setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        self.fallbackView.frame = self.bounds.insetBy(dx: self.bounds.width * 0.25, dy: self.bounds.height * 0.25)
        guard let gift = self.gift, let presentationData = self.presentationData, self.bounds.width > 0.0, self.bounds.height > 0.0 else {
            return
        }

        let subject: GiftItemComponent.Subject?
        if let attributes = gift.collectibleAttributes, attributes.contains(where: {
            if case .model = $0 { return true }
            return false
        }) {
            subject = .preview(attributes: attributes, rarity: nil)
        } else if let catalogueGift = gift.catalogueGift {
            switch catalogueGift {
            case let .generic(value):
                subject = .starGift(gift: value, price: "")
            case let .unique(value):
                subject = .uniqueGift(gift: value, price: nil)
            }
        } else {
            subject = nil
        }

        guard let subject else {
            self.fallbackView.isHidden = false
            self.fallbackView.tintColor = presentationData.theme.list.itemAccentColor
            self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
            self.componentView.view?.isHidden = true
            return
        }

        self.fallbackView.isHidden = true
        self.backgroundColor = .clear
        let number: Int32?
        if let localNumber = gift.localNumber {
            number = localNumber
        } else if let catalogueGift = gift.catalogueGift, case let .unique(value) = catalogueGift {
            number = value.number
        } else {
            number = nil
        }
        let _ = self.componentView.update(
            transition: .immediate,
            component: AnyComponent(GiftItemComponent(
                context: self.context,
                style: .glass,
                theme: presentationData.theme,
                strings: presentationData.strings,
                subject: subject,
                ribbon: number.map { GiftItemComponent.Ribbon(text: "#\($0)", font: .monospaced, color: .blue) },
                mode: .grid,
                allowAnimations: false
            )),
            environment: {},
            containerSize: self.bounds.size
        )
        if let view = self.componentView.view {
            if view.superview !== self {
                self.addSubview(view)
                self.sendSubviewToBack(view)
            }
            view.isHidden = false
            view.frame = self.bounds
        }
    }
}
