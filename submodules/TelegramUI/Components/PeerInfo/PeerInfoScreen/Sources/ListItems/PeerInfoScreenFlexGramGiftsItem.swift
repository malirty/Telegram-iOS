import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import FlexGram
import FlexGramUI

/// A visual preview of gifts stored only in this FlexGram installation.
final class PeerInfoScreenFlexGramGiftsItem: PeerInfoScreenItem {
    let id: AnyHashable
    let gifts: [FlexGramGift]

    init(id: AnyHashable, gifts: [FlexGramGift]) {
        self.id = id
        self.gifts = gifts
    }

    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenFlexGramGiftsItemNode()
    }
}

private final class PeerInfoScreenFlexGramGiftsItemNode: PeerInfoScreenItemNode {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let scrollView = UIScrollView()
    private var artworkViews: [FlexGramGiftArtView] = []

    override init() {
        super.init()
        self.isOpaque = false
        self.titleLabel.font = .systemFont(ofSize: 16.0, weight: .semibold)
        self.titleLabel.text = "Локальные подарки"
        self.subtitleLabel.font = .systemFont(ofSize: 12.0)
        self.subtitleLabel.text = "Видны только вам"
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.alwaysBounceHorizontal = true
    }

    override func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenFlexGramGiftsItem else { return 0.0 }
        let bounds = CGRect(x: safeInsets.left, y: 0.0, width: max(0.0, width - safeInsets.left - safeInsets.right), height: 155.0)
        self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.titleLabel.textColor = presentationData.theme.list.itemPrimaryTextColor
        self.subtitleLabel.textColor = presentationData.theme.list.itemSecondaryTextColor
        if self.titleLabel.superview == nil {
            self.view.addSubview(self.titleLabel)
            self.view.addSubview(self.subtitleLabel)
            self.view.addSubview(self.scrollView)
        }
        self.titleLabel.frame = CGRect(x: bounds.minX + 16.0, y: 12.0, width: bounds.width - 32.0, height: 22.0)
        self.subtitleLabel.frame = CGRect(x: bounds.minX + 16.0, y: 34.0, width: bounds.width - 32.0, height: 18.0)
        self.scrollView.frame = CGRect(x: bounds.minX + 16.0, y: 57.0, width: max(0.0, bounds.width - 32.0), height: 90.0)
        self.artworkViews.forEach { $0.removeFromSuperview() }
        self.artworkViews.removeAll()
        for (index, gift) in item.gifts.reversed().prefix(12).enumerated() {
            let artwork = FlexGramGiftArtView(context: context)
            artwork.frame = CGRect(x: CGFloat(index) * 98.0, y: 0.0, width: 90.0, height: 90.0)
            artwork.setGift(gift, presentationData: presentationData)
            self.scrollView.addSubview(artwork)
            self.artworkViews.append(artwork)
        }
        self.scrollView.contentSize = CGSize(width: CGFloat(self.artworkViews.count) * 98.0, height: 90.0)
        return bounds.height
    }
}
