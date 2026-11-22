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
import ConfettiEffect

private final class AntiSpoilerTopicControllerArguments {
    let updateTitle: (String) -> Void
    let updateKeywordInput: (String) -> Void
    let addKeywords: (String) -> Void
    let addSuggestion: (String) -> Void
    let removeKeyword: (String) -> Void
    let toggleCompleted: () -> Void
    let delete: () -> Void
    
    init(
        updateTitle: @escaping (String) -> Void,
        updateKeywordInput: @escaping (String) -> Void,
        addKeywords: @escaping (String) -> Void,
        addSuggestion: @escaping (String) -> Void,
        removeKeyword: @escaping (String) -> Void,
        toggleCompleted: @escaping () -> Void,
        delete: @escaping () -> Void
    ) {
        self.updateTitle = updateTitle
        self.updateKeywordInput = updateKeywordInput
        self.addKeywords = addKeywords
        self.addSuggestion = addSuggestion
        self.removeKeyword = removeKeyword
        self.toggleCompleted = toggleCompleted
        self.delete = delete
    }
}

private enum AntiSpoilerTopicSection: Int32 {
    case title
    case keywords
    case suggestions
    case completed
    case delete
}

private enum AntiSpoilerTopicEntry: ItemListNodeEntry {
    case titleHeader
    case title(String)
    case keywordsHeader
    case keywords(keywords: [String], input: String)
    case keywordsInfo
    case suggestionsHeader
    case suggestions([String])
    case completed(Bool)
    case completedInfo
    case delete
    
    var section: ItemListSectionId {
        switch self {
        case .titleHeader, .title:
            return AntiSpoilerTopicSection.title.rawValue
        case .keywordsHeader, .keywords, .keywordsInfo:
            return AntiSpoilerTopicSection.keywords.rawValue
        case .suggestionsHeader, .suggestions:
            return AntiSpoilerTopicSection.suggestions.rawValue
        case .completed, .completedInfo:
            return AntiSpoilerTopicSection.completed.rawValue
        case .delete:
            return AntiSpoilerTopicSection.delete.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .titleHeader:
            return 0
        case .title:
            return 1
        case .keywordsHeader:
            return 2
        case .keywords:
            return 3
        case .keywordsInfo:
            return 4
        case .suggestionsHeader:
            return 5
        case .suggestions:
            return 6
        case .completed:
            return 7
        case .completedInfo:
            return 8
        case .delete:
            return 9
        }
    }
    
    static func <(lhs: AntiSpoilerTopicEntry, rhs: AntiSpoilerTopicEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AntiSpoilerTopicControllerArguments
        let strings = presentationData.strings
        switch self {
        case .titleHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.AntiSpoiler_TopicNameHeader, sectionId: self.section)
        case let .title(value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: value, placeholder: strings.AntiSpoiler_TopicNamePlaceholder, clearType: .always, maxLength: 64, sectionId: self.section, textUpdated: { value in
                arguments.updateTitle(value)
            }, action: {})
        case .keywordsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.AntiSpoiler_KeywordsHeader, sectionId: self.section)
        case let .keywords(keywords, input):
            return AntiSpoilerKeywordsItem(presentationData: presentationData, keywords: keywords, text: input, placeholder: strings.AntiSpoiler_KeywordsPlaceholder, sectionId: self.section, textUpdated: { value in
                arguments.updateKeywordInput(value)
            }, add: { value in
                arguments.addKeywords(value)
            }, remove: { keyword in
                arguments.removeKeyword(keyword)
            })
        case .keywordsInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.AntiSpoiler_KeywordsInfo), sectionId: self.section)
        case .suggestionsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.AntiSpoiler_SuggestionsHeader, sectionId: self.section)
        case let .suggestions(suggestions):
            return AntiSpoilerSuggestionsItem(presentationData: presentationData, suggestions: suggestions, sectionId: self.section, action: { suggestion in
                arguments.addSuggestion(suggestion)
            })
        case let .completed(value):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: value ? strings.AntiSpoiler_HideAgain : strings.AntiSpoiler_CaughtUp, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.toggleCompleted()
            })
        case .completedInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.AntiSpoiler_CaughtUpInfo), sectionId: self.section)
        case .delete:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: strings.AntiSpoiler_DeleteTopic, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.delete()
            })
        }
    }
}

private struct AntiSpoilerTopicControllerState: Equatable {
    var title: String
    var keywords: [String]
    var keywordInput: String
    
    mutating func add(keywords: [String]) {
        for keyword in keywords where !self.keywords.contains(where: { $0.lowercased() == keyword.lowercased() }) {
            self.keywords.append(keyword)
        }
    }
}

private func antiSpoilerKeywords(_ text: String) -> [String] {
    return text.components(separatedBy: CharacterSet(charactersIn: ",\n")).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
}

/// `isSuggested` is set for a topic that is prefilled from a message and not yet added.
public func antiSpoilerTopicController(context: AccountContext, topic: AntiSpoilerTopic?, isSuggested: Bool = false, messageSuggestions: [String] = [], completion: ((AntiSpoilerTopic) -> Void)? = nil) -> ViewController {
    let accountManager = context.sharedContext.accountManager
    let initialState = AntiSpoilerTopicControllerState(title: topic?.title ?? "", keywords: topic?.keywords ?? [], keywordInput: "")
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((inout AntiSpoilerTopicControllerState) -> Void) -> Void = { f in
        statePromise.set(stateValue.modify { state in
            var state = state
            f(&state)
            return state
        })
    }
    
    var dismissImpl: (() -> Void)?
    var presentConfettiImpl: (() -> Void)?
    var presentImpl: ((ViewController) -> Void)?
    
    let arguments = AntiSpoilerTopicControllerArguments(
        updateTitle: { value in
            updateState { $0.title = value }
        },
        updateKeywordInput: { value in
            updateState { $0.keywordInput = value }
        },
        addKeywords: { value in
            updateState { state in
                state.add(keywords: antiSpoilerKeywords(value))
                state.keywordInput = ""
            }
        },
        addSuggestion: { keyword in
            updateState { $0.add(keywords: [keyword]) }
        },
        removeKeyword: { keyword in
            updateState { state in
                state.keywords.removeAll(where: { $0 == keyword })
            }
        },
        toggleCompleted: {
            guard let topic else {
                return
            }
            let _ = updateAntiSpoilerSettingsInteractively(accountManager: accountManager, { settings in
                var settings = settings
                if let index = settings.topics.firstIndex(where: { $0.id == topic.id }) {
                    settings.topics[index].isCompleted = !topic.isCompleted
                }
                return settings
            }).startStandalone()
            if !topic.isCompleted {
                presentConfettiImpl?()
            }
            dismissImpl?()
        },
        delete: {
            guard let topic else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let strings = presentationData.strings
            presentImpl?(textAlertController(context: context, title: nil, text: strings.AntiSpoiler_DeleteTopicConfirmation, actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                    let _ = updateAntiSpoilerSettingsInteractively(accountManager: accountManager, { settings in
                        var settings = settings
                        settings.topics.removeAll(where: { $0.id == topic.id })
                        return settings
                    }).startStandalone()
                    dismissImpl?()
                })
            ]))
        }
    )
    
    let saveTopic: () -> Void = {
        var state = stateValue.with { $0 }
        state.add(keywords: antiSpoilerKeywords(state.keywordInput))
        let title = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            return
        }
        let updatedTopic = AntiSpoilerTopic(id: topic?.id ?? Int64.random(in: 1000 ... Int64.max), title: title, keywords: state.keywords, isCompleted: topic?.isCompleted ?? false)
        let _ = updateAntiSpoilerSettingsInteractively(accountManager: accountManager, { settings in
            var settings = settings
            if let index = settings.topics.firstIndex(where: { $0.id == updatedTopic.id }) {
                settings.topics[index] = updatedTopic
            } else {
                settings.topics.append(updatedTopic)
            }
            return settings
        }).startStandalone()
        completion?(updatedTopic)
    }
    let save: () -> Void = {
        saveTopic()
        dismissImpl?()
    }
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = presentationData.strings
        let canSave = !state.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: canSave, action: {
            save()
        })
        
        var entries: [AntiSpoilerTopicEntry] = [
            .titleHeader,
            .title(state.title),
            .keywordsHeader,
            .keywords(keywords: state.keywords, input: state.keywordInput),
            .keywordsInfo
        ]
        let usedKeywords = Set((state.keywords + [state.title]).map { $0.lowercased() })
        var suggestions: [String] = []
        for suggestion in AntiSpoilerTopic.suggestedKeywords(title: state.title) + messageSuggestions {
            if !usedKeywords.contains(suggestion.lowercased()) && !suggestions.contains(suggestion) {
                suggestions.append(suggestion)
            }
        }
        if !suggestions.isEmpty {
            entries.append(.suggestionsHeader)
            entries.append(.suggestions(Array(suggestions.prefix(10))))
        }
        if let topic, !isSuggested {
            entries.append(.completed(topic.isCompleted))
            if !topic.isCompleted {
                entries.append(.completedInfo)
            }
            entries.append(.delete)
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(topic == nil || isSuggested ? strings.AntiSpoiler_NewTopic : strings.AntiSpoiler_EditTopic), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    if isSuggested {
        controller.navigationPresentation = .modal
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    presentConfettiImpl = { [weak controller] in
        guard let view = controller?.navigationController?.view else {
            return
        }
        view.addSubview(ConfettiView(frame: view.bounds))
    }
    // Nothing is lost if the screen is closed without Done
    controller.attemptNavigation = { _ in
        let state = stateValue.with { $0 }
        if state == initialState || state.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if topic != nil && !isSuggested {
            saveTopic()
            return true
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentImpl?(textAlertController(context: context, title: presentationData.strings.ChannelReactions_UnsavedChangesAlertTitle, text: presentationData.strings.AntiSpoiler_UnsavedChangesText, actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.ChannelReactions_UnsavedChangesAlertDiscard, action: {
                dismissImpl?()
            }),
            TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Done, action: {
                save()
            })
        ]))
        return false
    }
    presentImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
