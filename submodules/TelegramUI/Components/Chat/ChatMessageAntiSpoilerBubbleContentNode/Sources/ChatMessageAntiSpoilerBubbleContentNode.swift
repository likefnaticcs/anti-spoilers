import Foundation
import LottieSettings
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import AppBundle
import AccountContext
import ChatMessageBubbleContentNode
import ChatMessageItemCommon

/// "Possible spoiler" label displayed above the hidden text of a message.
public final class ChatMessageAntiSpoilerBubbleContentNode: ChatMessageBubbleContentNode {
    private let iconNode: ASImageNode
    private let textNode: TextNode
    
    required public init(lottieSettings: LottieRenderingSettings) {
        self.iconNode = ASImageNode()
        self.textNode = TextNode()
        
        super.init(lottieSettings: lottieSettings)
        
        self.iconNode.displaysAsynchronously = false
        self.addSubnode(self.iconNode)
        
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .topLeft
        self.textNode.contentsScale = UIScreenScale
        self.textNode.displaysAsynchronously = false
        self.addSubnode(self.textNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        return { [weak self] item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, _ in
                let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
                
                let topic = item.associatedData.antiSpoilerTopics[item.message.id] ?? ""
                let text = item.presentationData.strings.AntiSpoiler_PossibleSpoiler(topic).string
                
                let iconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/AgeRestricted"), color: messageTheme.accentTextColor)
                let iconSize = iconImage?.size ?? CGSize()
                let iconSpacing: CGFloat = 4.0
                
                let sideInsets = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                let textConstrainedSize = CGSize(width: max(1.0, constrainedSize.width - sideInsets - iconSize.width - iconSpacing), height: constrainedSize.height)
                
                let font = Font.semibold(floor(item.presentationData.fontSize.baseDisplaySize * 13.0 / 17.0))
                let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: text, font: font, textColor: messageTheme.accentTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                let contentHeight = max(iconSize.height, textLayout.size.height)
                let topInset = layoutConstants.text.bubbleInsets.top
                let suggestedWidth = sideInsets + iconSize.width + iconSpacing + textLayout.size.width
                
                return (suggestedWidth, { boundingWidth in
                    return (CGSize(width: boundingWidth, height: topInset + contentHeight), { _, _, _ in
                        guard let self else {
                            return
                        }
                        self.item = item
                        
                        let _ = textApply()
                        
                        self.iconNode.image = iconImage
                        self.iconNode.frame = CGRect(origin: CGPoint(x: layoutConstants.text.bubbleInsets.left, y: topInset + floorToScreenPixels((contentHeight - iconSize.height) / 2.0)), size: iconSize)
                        self.textNode.frame = CGRect(origin: CGPoint(x: layoutConstants.text.bubbleInsets.left + iconSize.width + iconSpacing, y: topInset + floorToScreenPixels((contentHeight - textLayout.size.height) / 2.0)), size: textLayout.size)
                    })
                })
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
}
