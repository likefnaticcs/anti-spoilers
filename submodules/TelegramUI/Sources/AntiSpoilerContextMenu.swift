import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI
import UndoUI
import SettingsUI
import ChatControllerInteraction
import ConfettiEffect

/// "Hide as Spoiler" for a visible message, "I'm Caught Up" for a hidden one.
func antiSpoilerContextMenuAction(context: AccountContext, messages: [Message], controllerInteraction: ChatControllerInteraction) -> ContextMenuActionItem? {
    guard let message = messages.first(where: { !$0.text.isEmpty }), message.effectivelyIncoming(context.account.peerId), message.adAttribute == nil else {
        return nil
    }
    let settings = context.sharedContext.currentAntiSpoilerSettings.with { $0 }
    if !settings.isEnabled {
        return nil
    }
    let strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
    
    let icon: (PresentationTheme) -> UIImage? = { theme in
        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Eye"), color: theme.actionSheet.primaryTextColor)
    }
    
    let presentToast: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controllerInteraction.presentControllerInCurrent(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: strings.AntiSpoiler_ToastSettings), elevatedLayout: false, action: { action in
            if case .undo = action {
                controllerInteraction.navigationController()?.pushViewController(antiSpoilerSettingsController(context: context))
            }
            return true
        }), nil)
    }
    
    if let topic = antiSpoilerTopic(messages: messages, settings: settings, accountPeerId: context.account.peerId, isPremium: context.isPremium) {
        return ContextMenuActionItem(text: strings.AntiSpoiler_CaughtUp, icon: icon, action: { _, f in
            f(.default)
            
            let _ = updateAntiSpoilerSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                var settings = settings
                if let index = settings.topics.firstIndex(where: { $0.id == topic.id }) {
                    settings.topics[index].isCompleted = true
                }
                return settings
            }).startStandalone()
            presentToast(strings.AntiSpoiler_CaughtUpToast(topic.title).string)
            if let view = controllerInteraction.navigationController()?.view {
                view.addSubview(ConfettiView(frame: view.bounds))
            }
        })
    } else {
        return ContextMenuActionItem(text: strings.AntiSpoiler_HideSimilar, icon: icon, action: { _, f in
            f(.default)
            
            // A topic that was completed earlier is suggested with its own keywords
            let suggestedTopic = antiSpoilerSuggestedTopic(message: message)
            var topic = settings.topics.first(where: { $0.id == suggestedTopic.id }) ?? suggestedTopic
            topic.isCompleted = false
            
            controllerInteraction.navigationController()?.pushViewController(antiSpoilerTopicController(context: context, topic: topic, isSuggested: true, messageSuggestions: antiSpoilerSuggestedKeywords(message: message), completion: { topic in
                presentToast(strings.AntiSpoiler_TopicAddedToast(topic.title).string)
            }))
        })
    }
}
