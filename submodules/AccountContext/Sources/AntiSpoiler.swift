import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences

private func antiSpoilerTexts(message: Message) -> [String] {
    var texts: [String] = [message.text]
    for attribute in message.attributes {
        if let attribute = attribute as? TranslationMessageAttribute {
            texts.append(attribute.text)
        }
    }
    for media in message.media {
        if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
            texts.append(content.title ?? "")
            texts.append(content.text ?? "")
        } else if let file = media as? TelegramMediaFile {
            texts.append(file.fileName ?? "")
        }
    }
    return texts
}

/// Returns the anti-spoiler topic that `messages` (a single message or an album) should be hidden by. Outgoing messages are never hidden.
public func antiSpoilerTopic(messages: [Message], settings: AntiSpoilerSettings, accountPeerId: PeerId, isPremium: Bool) -> AntiSpoilerTopic? {
    if !settings.isActive {
        return nil
    }
    guard let message = messages.first, message.effectivelyIncoming(accountPeerId), message.adAttribute == nil else {
        return nil
    }
    if settings.excludedPeerIds.contains(message.id.peerId) {
        return nil
    }
    var includeSpoilersOnly = true
    if isPremium {
        // Messages that are not checked yet stay hidden
        let classifications = messages.compactMap { message in
            return message.attributes.first(where: { $0 is SpoilerClassificationMessageAttribute }) as? SpoilerClassificationMessageAttribute
        }
        if !classifications.isEmpty && !classifications.contains(where: { $0.isSpoiler }) {
            includeSpoilersOnly = false
        }
    }
    return settings.matchingTopic(texts: messages.flatMap(antiSpoilerTexts), includeSpoilersOnly: includeSpoilersOnly)
}

/// Suggests a topic for "Hide as Spoiler". The title is empty if nothing suitable is found in the message.
public func antiSpoilerSuggestedTopic(message: Message) -> AntiSpoilerTopic {
    let texts = antiSpoilerTexts(message: message)
    if let topic = AntiSpoilerTopic.popularTopics.first(where: { $0.matches(texts: texts) }) {
        return topic
    }
    
    let title = antiSpoilerSuggestedKeywords(message: message).first ?? ""
    return AntiSpoilerTopic(id: Int64.random(in: 1000 ... Int64.max), title: title, keywords: [], isCompleted: false)
}

/// Hashtags, quoted titles and sequences of capitalized words of a message.
public func antiSpoilerSuggestedKeywords(message: Message) -> [String] {
    let patterns: [String] = [
        "#([\\p{L}\\p{N}_]+)",
        "[\"“«]([^\"”»]{2,40})[\"”»]",
        "(\\p{Lu}[\\p{L}\\p{N}]*(?: +(?:\\p{Lu}[\\p{L}\\p{N}]*|\\p{N}+))+)"
    ]
    let text = message.text as NSString
    var result: [String] = []
    for pattern in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            continue
        }
        for match in regex.matches(in: message.text, range: NSRange(location: 0, length: text.length)) {
            let keyword = text.substring(with: match.range(at: 1))
            if !result.contains(keyword) {
                result.append(keyword)
            }
        }
    }
    return result
}

public extension AccountContext {
    func isHiddenByAntiSpoiler(message: Message) -> Bool {
        return antiSpoilerTopic(messages: [message], settings: self.sharedContext.currentAntiSpoilerSettings.with { $0 }, accountPeerId: self.account.peerId, isPremium: self.isPremium) != nil
    }
    
    func isMediaHiddenByAntiSpoiler(message: Message) -> Bool {
        return self.sharedContext.currentAntiSpoilerSettings.with({ $0.hideMedia }) && self.isHiddenByAntiSpoiler(message: message)
    }
}
