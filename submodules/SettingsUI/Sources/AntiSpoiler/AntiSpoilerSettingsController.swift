import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import ItemListPeerActionItem
import ItemListPeerItem

private final class AntiSpoilerSettingsControllerArguments {
    let context: AccountContext
    let updateEnabled: (Bool) -> Void
    let updateHideMedia: (Bool) -> Void
    let updateMode: (AntiSpoilerMode) -> Void
    let openTopic: (AntiSpoilerTopic?) -> Void
    let addPopularTopic: (AntiSpoilerTopic) -> Void
    let addException: () -> Void
    let removeException: (EnginePeer.Id) -> Void
    let updateRevealedPeerId: (EnginePeer.Id?, EnginePeer.Id?) -> Void
    
    init(
        context: AccountContext,
        updateEnabled: @escaping (Bool) -> Void,
        updateHideMedia: @escaping (Bool) -> Void,
        updateMode: @escaping (AntiSpoilerMode) -> Void,
        openTopic: @escaping (AntiSpoilerTopic?) -> Void,
        addPopularTopic: @escaping (AntiSpoilerTopic) -> Void,
        addException: @escaping () -> Void,
        removeException: @escaping (EnginePeer.Id) -> Void,
        updateRevealedPeerId: @escaping (EnginePeer.Id?, EnginePeer.Id?) -> Void
    ) {
        self.context = context
        self.updateEnabled = updateEnabled
        self.updateHideMedia = updateHideMedia
        self.updateMode = updateMode
        self.openTopic = openTopic
        self.addPopularTopic = addPopularTopic
        self.addException = addException
        self.removeException = removeException
        self.updateRevealedPeerId = updateRevealedPeerId
    }
}

private enum AntiSpoilerSettingsSection: Int32 {
    case general
    case topics
    case completed
    case popular
    case mode
    case exceptions
}

private enum AntiSpoilerSettingsEntryId: Hashable {
    case index(Int)
    case topic(Int64)
    case peer(EnginePeer.Id)
}

private enum AntiSpoilerSettingsEntry: ItemListNodeEntry {
    case enabled(Bool)
    case hideMedia(Bool)
    case enabledInfo
    case topicsHeader
    case addTopic
    case topic(index: Int, topic: AntiSpoilerTopic)
    case topicsInfo
    case popularHeader
    case popularTopic(index: Int, topic: AntiSpoilerTopic)
    case modeHeader
    case modeAll(isSelected: Bool)
    case modeSpoilers(isSelected: Bool, isLocked: Bool)
    case modeInfo
    case exceptionsHeader
    case addException
    case exception(index: Int, peer: EnginePeer, isRevealed: Bool)
    case exceptionsInfo
    case completedHeader
    case completedTopic(index: Int, topic: AntiSpoilerTopic)
    
    var section: ItemListSectionId {
        switch self {
        case .enabled, .hideMedia, .enabledInfo:
            return AntiSpoilerSettingsSection.general.rawValue
        case .topicsHeader, .addTopic, .topic, .topicsInfo:
            return AntiSpoilerSettingsSection.topics.rawValue
        case .popularHeader, .popularTopic:
            return AntiSpoilerSettingsSection.popular.rawValue
        case .modeHeader, .modeAll, .modeSpoilers, .modeInfo:
            return AntiSpoilerSettingsSection.mode.rawValue
        case .exceptionsHeader, .addException, .exception, .exceptionsInfo:
            return AntiSpoilerSettingsSection.exceptions.rawValue
        case .completedHeader, .completedTopic:
            return AntiSpoilerSettingsSection.completed.rawValue
        }
    }
    
    var stableId: AntiSpoilerSettingsEntryId {
        switch self {
        case let .topic(_, topic), let .popularTopic(_, topic), let .completedTopic(_, topic):
            return .topic(topic.id)
        case let .exception(_, peer, _):
            return .peer(peer.id)
        default:
            return .index(self.sortIndex)
        }
    }
    
    private var sortIndex: Int {
        switch self {
        case .enabled:
            return 0
        case .hideMedia:
            return 1
        case .enabledInfo:
            return 2
        case .topicsHeader:
            return 3
        case .addTopic:
            return 4
        case let .topic(index, _):
            return 1000 + index
        case .topicsInfo:
            return 2000
        case .popularHeader:
            return 2900
        case let .popularTopic(index, _):
            return 3000 + index
        case .modeHeader:
            return 4000
        case .modeAll:
            return 4001
        case .modeSpoilers:
            return 4002
        case .modeInfo:
            return 4003
        case .exceptionsHeader:
            return 4004
        case .addException:
            return 4005
        case let .exception(index, _, _):
            return 5000 + index
        case .exceptionsInfo:
            return 6000
        case .completedHeader:
            return 2001
        case let .completedTopic(index, _):
            return 2100 + index
        }
    }
    
    static func <(lhs: AntiSpoilerSettingsEntry, rhs: AntiSpoilerSettingsEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AntiSpoilerSettingsControllerArguments
        let strings = presentationData.strings
        switch self {
        case let .enabled(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.AntiSpoiler_Enabled, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateEnabled(value)
            })
        case let .hideMedia(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.AntiSpoiler_HideMedia, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateHideMedia(value)
            })
        case .enabledInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.AntiSpoiler_EnabledInfo), sectionId: self.section)
        case .topicsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.AntiSpoiler_TopicsHeader, sectionId: self.section)
        case .addTopic:
            return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.plusIconImage(presentationData.theme), title: strings.AntiSpoiler_AddTopic, sectionId: self.section, height: .generic, editing: false, action: {
                arguments.openTopic(nil)
            })
        case let .topic(_, topic), let .completedTopic(_, topic):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: topic.title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openTopic(topic)
            })
        case .topicsInfo:
            return ItemListTextItem(presentationData: presentationData, text: .markdown(strings.AntiSpoiler_TopicsInfo), sectionId: self.section)
        case .popularHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.AntiSpoiler_PopularHeader, sectionId: self.section)
        case let .popularTopic(_, topic):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: topic.title, label: strings.AntiSpoiler_PopularAdd, labelStyle: .coloredText(presentationData.theme.list.itemAccentColor), sectionId: self.section, style: .blocks, disclosureStyle: .none, action: {
                arguments.addPopularTopic(topic)
            })
        case .modeHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.AntiSpoiler_ModeHeader, sectionId: self.section)
        case let .modeAll(isSelected):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: strings.AntiSpoiler_ModeAll, style: .left, checked: isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateMode(.allMentions)
            })
        case let .modeSpoilers(isSelected, isLocked):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, icon: isLocked ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Stickers/Lock"), color: presentationData.theme.list.itemSecondaryTextColor) : nil, iconPlacement: .check, title: strings.AntiSpoiler_ModeSpoilers, titleIcon: PresentationResourcesItemList.premiumIcon(presentationData.theme), subtitle: isLocked ? strings.AntiSpoiler_ModeSpoilersPremium : nil, style: .left, checked: isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateMode(.spoilersOnly)
            })
        case .modeInfo:
            return ItemListTextItem(presentationData: presentationData, text: .markdown(strings.AntiSpoiler_ModeInfo), sectionId: self.section)
        case .exceptionsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.AntiSpoiler_ExceptionsHeader, sectionId: self.section)
        case .addException:
            return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.plusIconImage(presentationData.theme), title: strings.AntiSpoiler_AddException, sectionId: self.section, height: .generic, editing: false, action: {
                arguments.addException()
            })
        case let .exception(_, peer, isRevealed):
            return ItemListPeerItem(presentationData: presentationData, systemStyle: .glass, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: .firstLast, context: arguments.context, peer: peer, presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: isRevealed), enabled: true, selectable: false, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                arguments.updateRevealedPeerId(peerId, fromPeerId)
            }, removePeer: { peerId in
                arguments.removeException(peerId)
            })
        case .exceptionsInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.AntiSpoiler_ExceptionsInfo), sectionId: self.section)
        case .completedHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.AntiSpoiler_CompletedHeader, sectionId: self.section)
        }
    }
}

private func antiSpoilerSettingsEntries(settings: AntiSpoilerSettings, excludedPeers: [EnginePeer], revealedPeerId: EnginePeer.Id?, isPremium: Bool) -> [AntiSpoilerSettingsEntry] {
    var entries: [AntiSpoilerSettingsEntry] = []
    entries.append(.enabled(settings.isEnabled))
    if settings.isEnabled {
        entries.append(.hideMedia(settings.hideMedia))
    }
    entries.append(.enabledInfo)
    if !settings.isEnabled {
        return entries
    }
    
    entries.append(.topicsHeader)
    entries.append(.addTopic)
    for (index, topic) in settings.topics.filter({ !$0.isCompleted }).enumerated() {
        entries.append(.topic(index: index, topic: topic))
    }
    entries.append(.topicsInfo)
    
    let completedTopics = settings.topics.filter { $0.isCompleted }
    if !completedTopics.isEmpty {
        entries.append(.completedHeader)
        for (index, topic) in completedTopics.enumerated() {
            entries.append(.completedTopic(index: index, topic: topic))
        }
    }
    
    let popularTopics = AntiSpoilerTopic.popularTopics.filter { topic in
        return !settings.topics.contains(where: { $0.id == topic.id })
    }
    if !popularTopics.isEmpty {
        entries.append(.popularHeader)
        for (index, topic) in popularTopics.enumerated() {
            entries.append(.popularTopic(index: index, topic: topic))
        }
    }
    
    let mode: AntiSpoilerMode = isPremium ? settings.mode : .allMentions
    entries.append(.modeHeader)
    entries.append(.modeAll(isSelected: mode == .allMentions))
    entries.append(.modeSpoilers(isSelected: mode == .spoilersOnly, isLocked: !isPremium))
    entries.append(.modeInfo)
    
    entries.append(.exceptionsHeader)
    entries.append(.addException)
    for (index, peer) in excludedPeers.enumerated() {
        entries.append(.exception(index: index, peer: peer, isRevealed: peer.id == revealedPeerId))
    }
    entries.append(.exceptionsInfo)
    return entries
}

public func antiSpoilerSettingsController(context: AccountContext) -> ViewController {
    let accountManager = context.sharedContext.accountManager
    var pushControllerImpl: ((ViewController) -> Void)?
    let revealedPeerId = ValuePromise<EnginePeer.Id?>(nil, ignoreRepeated: true)
    
    let updateSettings: (@escaping (inout AntiSpoilerSettings) -> Void) -> Void = { f in
        let _ = updateAntiSpoilerSettingsInteractively(accountManager: accountManager, { settings in
            var settings = settings
            f(&settings)
            return settings
        }).startStandalone()
    }
    
    let arguments = AntiSpoilerSettingsControllerArguments(
        context: context,
        updateEnabled: { value in
            updateSettings { $0.isEnabled = value }
        },
        updateHideMedia: { value in
            updateSettings { $0.hideMedia = value }
        },
        updateMode: { mode in
            if mode == .spoilersOnly && !context.isPremium {
                pushControllerImpl?(context.sharedContext.makePremiumIntroController(context: context, source: .aiTools, forceDark: false, dismissed: nil))
                return
            }
            updateSettings { $0.mode = mode }
        },
        openTopic: { topic in
            pushControllerImpl?(antiSpoilerTopicController(context: context, topic: topic))
        },
        addPopularTopic: { topic in
            updateSettings { $0.topics.append(topic) }
        },
        addException: {
            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.excludeSecretChats], hasContactSelector: false, hasGlobalSearch: false, title: context.sharedContext.currentPresentationData.with({ $0 }).strings.AntiSpoiler_AddException))
            controller.peerSelected = { [weak controller] peer, _ in
                updateSettings { settings in
                    if !settings.excludedPeerIds.contains(peer.id) {
                        settings.excludedPeerIds.append(peer.id)
                    }
                }
                controller?.dismiss()
            }
            pushControllerImpl?(controller)
        },
        removeException: { peerId in
            updateSettings { $0.excludedPeerIds.removeAll(where: { $0 == peerId }) }
        },
        updateRevealedPeerId: { peerId, fromPeerId in
            revealedPeerId.set(peerId)
        }
    )
    
    let settingsAndPeers = antiSpoilerSettings(accountManager: accountManager)
    |> mapToSignal { settings -> Signal<(AntiSpoilerSettings, [EnginePeer]), NoError> in
        return context.engine.data.get(EngineDataMap(
            settings.excludedPeerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))
        ))
        |> map { peers in
            return (settings, settings.excludedPeerIds.compactMap { peers[$0].flatMap { $0 } })
        }
    }
    
    let isPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
    |> map { peer -> Bool in
        return peer?.isPremium ?? false
    }
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        settingsAndPeers,
        revealedPeerId.get(),
        isPremium
    )
    |> map { presentationData, settingsAndPeers, revealedPeerId, isPremium -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let (settings, excludedPeers) = settingsAndPeers
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.AntiSpoiler_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: antiSpoilerSettingsEntries(settings: settings, excludedPeers: excludedPeers, revealedPeerId: revealedPeerId, isPremium: isPremium), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
