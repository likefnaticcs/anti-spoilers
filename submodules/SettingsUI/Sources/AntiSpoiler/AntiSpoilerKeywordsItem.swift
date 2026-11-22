import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI

/// Input with keywords as removable chips. A keyword is added with Return or a comma and removed with a tap or backspace.
final class AntiSpoilerKeywordsItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let keywords: [String]
    let text: String
    let placeholder: String
    let sectionId: ItemListSectionId
    let textUpdated: (String) -> Void
    let add: (String) -> Void
    let remove: (String) -> Void
    
    let selectable = false
    
    init(presentationData: ItemListPresentationData, keywords: [String], text: String, placeholder: String, sectionId: ItemListSectionId, textUpdated: @escaping (String) -> Void, add: @escaping (String) -> Void, remove: @escaping (String) -> Void) {
        self.presentationData = presentationData
        self.keywords = keywords
        self.text = text
        self.placeholder = placeholder
        self.sectionId = sectionId
        self.textUpdated = textUpdated
        self.add = add
        self.remove = remove
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = AntiSpoilerKeywordsItemNode()
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
            guard let nodeValue = node() as? AntiSpoilerKeywordsItemNode else {
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

private final class AntiSpoilerKeywordsTextField: UITextField {
    var deleteBackwardWhileEmpty: (() -> Void)?
    
    override func deleteBackward() {
        if (self.text ?? "").isEmpty {
            self.deleteBackwardWhileEmpty?()
        }
        super.deleteBackward()
    }
}

private final class AntiSpoilerKeywordsItemNode: ListViewItemNode, UITextFieldDelegate {
    private let backgroundNode: ASDisplayNode
    private var chipNodes: [String: HighlightableButtonNode] = [:]
    private var textField: AntiSpoilerKeywordsTextField?
    private var item: AntiSpoilerKeywordsItem?
    
    override var canBeSelected: Bool {
        return false
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.backgroundNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.backgroundNode.cornerRadius = 26.0
        self.backgroundNode.layer.cornerCurve = .continuous
        
        let textField = AntiSpoilerKeywordsTextField()
        textField.delegate = self
        textField.returnKeyType = .done
        textField.autocorrectionType = .no
        textField.addTarget(self, action: #selector(self.textChanged), for: .editingChanged)
        textField.deleteBackwardWhileEmpty = { [weak self] in
            guard let item = self?.item, let keyword = item.keywords.last else {
                return
            }
            item.remove(keyword)
        }
        self.textField = textField
        self.view.addSubview(textField)
        
        self.view.addGestureRecognizer({
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(self.focus))
            recognizer.cancelsTouchesInView = false
            return recognizer
        }())
    }
    
    func asyncLayout() -> (_ item: AntiSpoilerKeywordsItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { [weak self] item, params, neighbors in
            let backgroundWidth = params.width - params.leftInset - params.rightInset
            let chipHeight: CGFloat = 32.0
            let spacing: CGFloat = 8.0
            let chipInset: CGFloat = 12.0
            let verticalInset: CGFloat = 10.0
            let sideInset: CGFloat = item.keywords.isEmpty ? 16.0 : 10.0
            let minInputWidth: CGFloat = 110.0
            let maxWidth = max(1.0, backgroundWidth - sideInset * 2.0)
            
            let theme = item.presentationData.theme
            let chipFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            let inputFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            
            var chips: [(keyword: String, title: NSAttributedString, frame: CGRect)] = []
            var origin = CGPoint()
            for keyword in item.keywords {
                let title = NSMutableAttributedString(string: keyword, font: chipFont, textColor: theme.list.itemAccentColor)
                title.append(NSAttributedString(string: "  ✕", font: Font.regular(chipFont.pointSize - 3.0), textColor: theme.list.itemAccentColor.withMultipliedAlpha(0.6)))
                let titleSize = title.boundingRect(with: CGSize(width: maxWidth - chipInset * 2.0, height: chipHeight), options: [.usesLineFragmentOrigin], context: nil).size
                let size = CGSize(width: min(maxWidth, ceil(titleSize.width) + chipInset * 2.0), height: chipHeight)
                if origin.x != 0.0 && origin.x + size.width > maxWidth {
                    origin = CGPoint(x: 0.0, y: origin.y + chipHeight + spacing)
                }
                chips.append((keyword, title, CGRect(origin: CGPoint(x: params.leftInset + sideInset + origin.x, y: verticalInset + origin.y), size: size)))
                origin.x += size.width + spacing
            }
            if origin.x != 0.0 && maxWidth - origin.x < minInputWidth {
                origin = CGPoint(x: 0.0, y: origin.y + chipHeight + spacing)
            }
            let inputFrame = CGRect(x: params.leftInset + sideInset + origin.x, y: verticalInset + origin.y, width: maxWidth - origin.x, height: chipHeight)
            
            let contentSize = CGSize(width: params.width, height: inputFrame.maxY + verticalInset)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: itemListNeighborsGroupedInsets(neighbors, params))
            
            return (layout, {
                guard let self else {
                    return
                }
                self.item = item
                
                self.backgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor
                self.backgroundNode.frame = CGRect(x: params.leftInset, y: 0.0, width: backgroundWidth, height: contentSize.height)
                
                for (keyword, title, frame) in chips {
                    let chipNode: HighlightableButtonNode
                    if let current = self.chipNodes[keyword] {
                        chipNode = current
                    } else {
                        chipNode = HighlightableButtonNode()
                        chipNode.cornerRadius = chipHeight / 2.0
                        chipNode.addTarget(self, action: #selector(self.chipPressed(_:)), forControlEvents: .touchUpInside)
                        self.chipNodes[keyword] = chipNode
                        self.addSubnode(chipNode)
                    }
                    chipNode.backgroundColor = theme.list.itemAccentColor.withMultipliedAlpha(0.1)
                    chipNode.setAttributedTitle(title, for: [])
                    chipNode.accessibilityLabel = keyword
                    chipNode.frame = frame
                }
                for (keyword, chipNode) in self.chipNodes where !item.keywords.contains(keyword) {
                    chipNode.removeFromSupernode()
                    self.chipNodes.removeValue(forKey: keyword)
                }
                
                let _ = self.view
                if let textField = self.textField {
                    textField.font = inputFont
                    textField.textColor = theme.list.itemPrimaryTextColor
                    textField.tintColor = theme.list.itemAccentColor
                    textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
                    textField.attributedPlaceholder = item.keywords.isEmpty ? NSAttributedString(string: item.placeholder, font: inputFont, textColor: theme.list.itemPlaceholderTextColor) : nil
                    if textField.text != item.text {
                        textField.text = item.text
                    }
                    textField.frame = inputFrame
                }
            })
        }
    }
    
    @objc private func focus() {
        self.textField?.becomeFirstResponder()
    }
    
    @objc private func chipPressed(_ sender: HighlightableButtonNode) {
        guard let item = self.item, let keyword = self.chipNodes.first(where: { $0.value === sender })?.key else {
            return
        }
        item.remove(keyword)
    }
    
    @objc private func textChanged() {
        guard let item = self.item, let text = self.textField?.text else {
            return
        }
        if text.contains(",") {
            item.add(text)
        } else {
            item.textUpdated(text)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let text = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            textField.resignFirstResponder()
        } else {
            self.item?.add(text)
        }
        return false
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
