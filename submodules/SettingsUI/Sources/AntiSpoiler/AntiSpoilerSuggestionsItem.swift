import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI

/// Keyword suggestions, each of them is added with a tap.
final class AntiSpoilerSuggestionsItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let suggestions: [String]
    let sectionId: ItemListSectionId
    let action: (String) -> Void
    
    let selectable = false
    
    init(presentationData: ItemListPresentationData, suggestions: [String], sectionId: ItemListSectionId, action: @escaping (String) -> Void) {
        self.presentationData = presentationData
        self.suggestions = suggestions
        self.sectionId = sectionId
        self.action = action
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = AntiSpoilerSuggestionsItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? AntiSpoilerSuggestionsItemNode else {
                return
            }
            let makeLayout = nodeValue.asyncLayout()
            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
                Queue.mainQueue().async {
                    completion(layout, { _ in
                        apply()
                    })
                }
            }
        }
    }
}

private final class AntiSpoilerSuggestionsItemNode: ListViewItemNode {
    private var buttonNodes: [String: HighlightableButtonNode] = [:]
    private var item: AntiSpoilerSuggestionsItem?
    
    override var canBeSelected: Bool {
        return false
    }
    
    init() {
        super.init(layerBacked: false)
    }
    
    func asyncLayout() -> (_ item: AntiSpoilerSuggestionsItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { [weak self] item, params, neighbors in
            let sideInset: CGFloat = params.leftInset + 16.0
            let maxWidth = max(1.0, params.width - params.leftInset - params.rightInset - 32.0)
            let buttonHeight: CGFloat = 34.0
            let spacing: CGFloat = 8.0
            let buttonInset: CGFloat = 14.0
            let font = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            
            var buttons: [(suggestion: String, title: NSAttributedString, frame: CGRect)] = []
            var origin = CGPoint()
            for suggestion in item.suggestions {
                let title = NSAttributedString(string: "+ " + suggestion, font: font, textColor: item.presentationData.theme.list.itemAccentColor)
                let titleSize = title.boundingRect(with: CGSize(width: maxWidth - buttonInset * 2.0, height: buttonHeight), options: [.usesLineFragmentOrigin], context: nil).size
                let size = CGSize(width: min(maxWidth, ceil(titleSize.width) + buttonInset * 2.0), height: buttonHeight)
                if origin.x != 0.0 && origin.x + size.width > maxWidth {
                    origin = CGPoint(x: 0.0, y: origin.y + buttonHeight + spacing)
                }
                buttons.append((suggestion, title, CGRect(origin: CGPoint(x: sideInset + origin.x, y: origin.y), size: size)))
                origin.x += size.width + spacing
            }
            
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: origin.y + buttonHeight), insets: itemListNeighborsGroupedInsets(neighbors, params))
            
            return (layout, {
                guard let self else {
                    return
                }
                self.item = item
                
                for (suggestion, title, frame) in buttons {
                    let buttonNode: HighlightableButtonNode
                    if let current = self.buttonNodes[suggestion] {
                        buttonNode = current
                    } else {
                        buttonNode = HighlightableButtonNode()
                        buttonNode.cornerRadius = buttonHeight / 2.0
                        buttonNode.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .touchUpInside)
                        self.buttonNodes[suggestion] = buttonNode
                        self.addSubnode(buttonNode)
                    }
                    buttonNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                    buttonNode.setAttributedTitle(title, for: [])
                    buttonNode.accessibilityLabel = suggestion
                    buttonNode.frame = frame
                }
                for (suggestion, buttonNode) in self.buttonNodes where !item.suggestions.contains(suggestion) {
                    buttonNode.removeFromSupernode()
                    self.buttonNodes.removeValue(forKey: suggestion)
                }
            })
        }
    }
    
    @objc private func buttonPressed(_ sender: HighlightableButtonNode) {
        guard let item = self.item, let suggestion = self.buttonNodes.first(where: { $0.value === sender })?.key else {
            return
        }
        item.action(suggestion)
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
