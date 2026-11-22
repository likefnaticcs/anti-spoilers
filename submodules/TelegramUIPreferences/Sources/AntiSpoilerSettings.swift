import Foundation
import TelegramCore
import SwiftSignalKit

public struct AntiSpoilerTopic: Codable, Equatable {
    public let id: Int64
    public var title: String
    public var keywords: [String]
    public var isCompleted: Bool
    
    public init(id: Int64, title: String, keywords: [String], isCompleted: Bool) {
        self.id = id
        self.title = title
        self.keywords = keywords
        self.isCompleted = isCompleted
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.id = try container.decode(Int64.self, forKey: "id")
        self.title = try container.decode(String.self, forKey: "title")
        self.keywords = try container.decode([String].self, forKey: "keywords")
        self.isCompleted = (try container.decode(Int32.self, forKey: "isCompleted")) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.id, forKey: "id")
        try container.encode(self.title, forKey: "title")
        try container.encode(self.keywords, forKey: "keywords")
        try container.encode((self.isCompleted ? 1 : 0) as Int32, forKey: "isCompleted")
    }
    
    /// Ready-made topics. The release version receives them from the server.
    public static let popularTopics: [AntiSpoilerTopic] = [
        AntiSpoilerTopic(id: 1, title: "GTA 6", keywords: ["GTA VI", "Grand Theft Auto 6", "Grand Theft Auto VI"], isCompleted: false),
        AntiSpoilerTopic(id: 2, title: "Dune: Part Three", keywords: ["Dune 3", "Dune Messiah"], isCompleted: false),
        AntiSpoilerTopic(id: 3, title: "Avengers: Doomsday", keywords: ["Avengers 5"], isCompleted: false)
    ]
    
    private static let popularKeywords: [Int64: [String]] = [
        1: ["GTA VI", "Grand Theft Auto VI", "Vice City", "Leonida", "Lucia", "Jason Duval", "Rockstar"],
        2: ["Dune 3", "Dune Messiah", "Paul Atreides", "Chani", "Arrakis", "Irulan"],
        3: ["Avengers 5", "Doctor Doom", "Victor von Doom", "Fantastic Four"]
    ]
    
    /// Keywords that can be added to a topic with this title.
    public static func suggestedKeywords(title: String) -> [String] {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.count < 2 {
            return []
        }
        
        var result: [String] = []
        let compactTitle = antiSpoilerTokens(title).joined()
        for topic in self.popularTopics {
            let names = ([topic.title] + topic.keywords).map { antiSpoilerTokens($0).joined() }
            if !compactTitle.isEmpty && names.contains(where: { $0.hasPrefix(compactTitle) }) {
                result.append(contentsOf: [topic.title] + (self.popularKeywords[topic.id] ?? []))
            }
        }
        
        // "Title 6" is also written as "Title VI", "Title: Subtitle" as "Title"
        let romanNumbers: [String: String] = ["2": "II", "3": "III", "4": "IV", "5": "V", "6": "VI", "7": "VII", "8": "VIII", "9": "IX", "10": "X"]
        let words = title.components(separatedBy: " ")
        if words.count > 1, let last = words.last {
            if let roman = romanNumbers[last] {
                result.append((words.dropLast() + [roman]).joined(separator: " "))
            } else if let arabic = romanNumbers.first(where: { $0.value == last })?.key {
                result.append((words.dropLast() + [arabic]).joined(separator: " "))
            }
        }
        if let range = title.range(of: ":") {
            let name = title[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
            if name.count > 2 {
                result.append(name)
            }
        }
        
        var uniqueResult: [String] = []
        for keyword in result where keyword != title && !uniqueResult.contains(keyword) {
            uniqueResult.append(keyword)
        }
        return uniqueResult
    }
    
    public func matches(texts: [String]) -> Bool {
        return self.matches(tokenizedTexts: texts.map(antiSpoilerTokens))
    }
    
    fileprivate func matches(tokenizedTexts: [[String]]) -> Bool {
        for phrase in [self.title] + self.keywords {
            let compactPhrase = antiSpoilerTokens(phrase).joined()
            if compactPhrase.isEmpty {
                continue
            }
            if tokenizedTexts.contains(where: { antiSpoilerContains(tokens: $0, compactPhrase: compactPhrase) }) {
                return true
            }
        }
        return false
    }
}

public enum AntiSpoilerMode: Int32 {
    case allMentions = 0
    case spoilersOnly = 1
}

public struct AntiSpoilerSettings: Codable, Equatable {
    public var isEnabled: Bool
    public var hideMedia: Bool
    public var mode: AntiSpoilerMode
    public var topics: [AntiSpoilerTopic]
    public var excludedPeerIds: [EnginePeer.Id]
    
    public static var defaultSettings: AntiSpoilerSettings {
        return AntiSpoilerSettings(isEnabled: true, hideMedia: true, mode: .allMentions, topics: [], excludedPeerIds: [])
    }
    
    public init(isEnabled: Bool, hideMedia: Bool, mode: AntiSpoilerMode, topics: [AntiSpoilerTopic], excludedPeerIds: [EnginePeer.Id]) {
        self.isEnabled = isEnabled
        self.hideMedia = hideMedia
        self.mode = mode
        self.topics = topics
        self.excludedPeerIds = excludedPeerIds
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.isEnabled = (try container.decode(Int32.self, forKey: "isEnabled")) != 0
        self.hideMedia = (try container.decode(Int32.self, forKey: "hideMedia")) != 0
        self.mode = AntiSpoilerMode(rawValue: try container.decode(Int32.self, forKey: "mode")) ?? .allMentions
        self.topics = try container.decode([AntiSpoilerTopic].self, forKey: "topics")
        self.excludedPeerIds = (try container.decode([Int64].self, forKey: "excludedPeerIds")).map { EnginePeer.Id($0) }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode((self.isEnabled ? 1 : 0) as Int32, forKey: "isEnabled")
        try container.encode((self.hideMedia ? 1 : 0) as Int32, forKey: "hideMedia")
        try container.encode(self.mode.rawValue, forKey: "mode")
        try container.encode(self.topics, forKey: "topics")
        try container.encode(self.excludedPeerIds.map { $0.toInt64() }, forKey: "excludedPeerIds")
    }
    
    public var isActive: Bool {
        return self.isEnabled && self.topics.contains(where: { !$0.isCompleted })
    }
    
    /// Returns the first active topic mentioned in `texts`.
    public func matchingTopic(texts: [String]) -> AntiSpoilerTopic? {
        if !self.isActive {
            return nil
        }
        let tokenizedTexts = texts.map(antiSpoilerTokens).filter { !$0.isEmpty }
        if tokenizedTexts.isEmpty {
            return nil
        }
        return self.topics.first(where: { !$0.isCompleted && $0.matches(tokenizedTexts: tokenizedTexts) })
    }
}

private func antiSpoilerTokens(_ text: String) -> [String] {
    return text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil).lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
}

// Consecutive whole words are joined before comparing, so "GTA 6", "GTA-6" and "#gta6" are equal,
// while "GTA 60" and "Megagta 6" do not match
private func antiSpoilerContains(tokens: [String], compactPhrase: String) -> Bool {
    for startIndex in 0 ..< tokens.count {
        var candidate = ""
        for index in startIndex ..< tokens.count {
            candidate += tokens[index]
            if candidate == compactPhrase {
                return true
            }
            if !compactPhrase.hasPrefix(candidate) {
                break
            }
        }
    }
    return false
}

public func antiSpoilerSettings(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<AntiSpoilerSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.antiSpoilerSettings])
    |> map { sharedData -> AntiSpoilerSettings in
        return sharedData.entries[ApplicationSpecificSharedDataKeys.antiSpoilerSettings]?.get(AntiSpoilerSettings.self) ?? AntiSpoilerSettings.defaultSettings
    }
    |> distinctUntilChanged
}

public func updateAntiSpoilerSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (AntiSpoilerSettings) -> AntiSpoilerSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.antiSpoilerSettings, { entry in
            return SharedPreferencesEntry(f(entry?.get(AntiSpoilerSettings.self) ?? AntiSpoilerSettings.defaultSettings))
        })
    }
}
