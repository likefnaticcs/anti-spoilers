import Foundation
import UIKit
import Display
import AppBundle
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences

/// Local account with fictional chats. It needs no API keys and never connects to the network.
/// `--demo` starts with clean data, a build without API keys keeps the data between launches.
enum DemoMode {
    static var isBuiltWithoutApiKeys = false
    
    static var isEnabled: Bool {
        return self.shouldReset || self.isBuiltWithoutApiKeys
    }
    
    static var shouldReset: Bool {
        return CommandLine.arguments.contains("--demo")
    }
    
    private static var isPremium: Bool {
        return CommandLine.arguments.contains("--demo-premium")
    }
    
    static func setup(accountManager: AccountManager<TelegramAccountManagerTypes>) {
        demoAccountSetup = { postbox, transaction in
            return DemoMode.setupAccount(postbox: postbox, transaction: transaction)
        }
        // The account is created again after a log out
        let _ = (accountManager.accountRecords()
        |> map { view -> Bool in
            return view.currentRecord == nil
        }
        |> distinctUntilChanged
        |> filter { $0 }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return accountManager.transaction { transaction -> Void in
                if transaction.getCurrent() != nil {
                    return
                }
                let id = transaction.createRecord([
                    .environment(AccountEnvironmentAttribute(environment: .production)),
                    .sortOrder(AccountSortOrderAttribute(order: 0))
                ])
                transaction.setCurrentId(id)
                transaction.removeAuth()
                
                transaction.updateSharedData(ApplicationSpecificSharedDataKeys.antiSpoilerSettings, { entry in
                    if let entry {
                        return entry
                    }
                    var settings = AntiSpoilerSettings.defaultSettings
                    settings.topics.append(AntiSpoilerTopic(id: 900, title: "I Play Rocky", keywords: ["Rocky", "Stallone"], isCompleted: false))
                    return SharedPreferencesEntry(settings)
                })
            }
        }).startStandalone()
    }
    
    static let notificationMessages = ValuePipe<[([Message], PeerGroupId, Bool, MessageHistoryThreadData?)]>()
    
    /// A new post arrives a few seconds after every launch.
    static func scheduleIncomingMessage(postbox: Postbox) {
        let peerId = channelId(2001)
        let messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 100)
        let _ = postbox.transaction({ transaction -> Void in
            if transaction.messageExists(id: messageId) {
                transaction.deleteMessages([messageId], forEachMedia: nil)
            }
        }).startStandalone()
        
        Queue.mainQueue().after(6.0, {
            let _ = (postbox.transaction { transaction -> Message? in
                let message = StoreMessage(id: messageId, customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: Int32(Date().timeIntervalSince1970), flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: peerId, text: "We finished #GTA6 and need to talk about that final twist. Nobody expected the last scene at the airport.", attributes: [SpoilerClassificationMessageAttribute(isSpoiler: true), ViewCountMessageAttribute(count: 128)], media: [])
                let _ = transaction.addMessages([message], location: .UpperHistoryBlock)
                return transaction.getMessage(messageId)
            }
            |> deliverOnMainQueue).startStandalone(next: { message in
                if let message {
                    self.notificationMessages.putNext([([message], .root, true, nil)])
                }
            })
        })
    }
    
    private struct DemoMessage {
        let author: PeerId?
        let text: String
        let minutesAgo: Int32
        var isSpoiler: Bool?
        var photoColors: [UIColor]?
        var photoName: String?
        var isRead: Bool = true
    }
    
    private static func userId(_ id: Int64) -> PeerId {
        return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))
    }
    
    private static func channelId(_ id: Int64) -> PeerId {
        return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id))
    }
    
    private static func user(_ id: PeerId, firstName: String, lastName: String?, username: String? = nil, isPremium: Bool = false) -> TelegramUser {
        return TelegramUser(id: id, accessHash: .personal(1), firstName: firstName, lastName: lastName, username: username, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: isPremium ? [.isPremium] : [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
    }
    
    private static func channel(_ id: PeerId, title: String, isGroup: Bool) -> TelegramChannel {
        return TelegramChannel(id: id, accessHash: .personal(1), title: title, username: nil, photo: [], creationDate: 1, version: 0, participationStatus: .member, info: isGroup ? .group(TelegramChannelGroupInfo(flags: [])) : .broadcast(TelegramChannelBroadcastInfo(flags: [])), flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, emojiStatus: nil, approximateBoostLevel: nil, subscriptionUntilDate: nil, verificationIconFileId: nil, sendPaidMessageStars: nil, linkedMonoforumId: nil)
    }
    
    private static func setupAccount(postbox: Postbox, transaction: Transaction) -> AuthorizedAccountState {
        let accountPeerId = userId(1001)
        let alex = userId(1002)
        let mia = userId(1003)
        let leo = userId(1004)
        let gamesChannel = channelId(2001)
        let moviesChannel = channelId(2002)
        let designChannel = channelId(2003)
        let group = channelId(2004)
        
        let peers: [Peer] = [
            user(accountPeerId, firstName: "Sam", lastName: "Taylor", username: "samtaylor", isPremium: isPremium),
            user(alex, firstName: "Alex", lastName: "Rivera"),
            user(mia, firstName: "Mia", lastName: "Chen"),
            user(leo, firstName: "Leo", lastName: "Novak"),
            channel(gamesChannel, title: "Pixel Daily", isGroup: false),
            channel(moviesChannel, title: "Frame by Frame", isGroup: false),
            channel(designChannel, title: "Grid & Type", isGroup: false),
            channel(group, title: "Friday Night Squad", isGroup: true)
        ]
        transaction.updatePeersInternal(peers, update: { _, updated in
            return updated
        })
        
        let chats: [(PeerId, [DemoMessage])] = [
            (gamesChannel, [
                DemoMessage(author: nil, text: "Indie week is here: twelve small games worth your evening. Full list in the comments.", minutesAgo: 1500),
                DemoMessage(author: nil, text: "GTA 6 is out now. Stores opened at midnight, and servers are holding up well so far.", minutesAgo: 420, isSpoiler: false),
                DemoMessage(author: nil, text: "The GTA 6 ending explained: who betrays the crew in the last mission, and why the final choice changes everything.", minutesAgo: 190, isSpoiler: true, photoColors: [UIColor(rgb: 0xff5f6d), UIColor(rgb: 0x7b2ff7)], photoName: "Demo/GameArt"),
                DemoMessage(author: nil, text: "How to get the best frame rate on a base console: five settings to change first.", minutesAgo: 75)
            ]),
            (group, [
                DemoMessage(author: leo, text: "Pizza at 7?", minutesAgo: 260),
                DemoMessage(author: accountPeerId, text: "I'm in. Please no spoilers, I start on Saturday", minutesAgo: 255),
                DemoMessage(author: mia, text: "Promise 🤞", minutesAgo: 250),
                DemoMessage(author: leo, text: "Okay but GTA VI chapter 4, when the whole plan falls apart on the bridge...", minutesAgo: 30, isSpoiler: true),
                DemoMessage(author: mia, text: "LEO!", minutesAgo: 29, isRead: false)
            ]),
            (alex, [
                DemoMessage(author: accountPeerId, text: "Are we still on for Saturday?", minutesAgo: 600),
                DemoMessage(author: alex, text: "Yes! I downloaded GTA 6 overnight, so we can start right away", minutesAgo: 590, isSpoiler: false),
                DemoMessage(author: accountPeerId, text: "Perfect, I'll bring snacks", minutesAgo: 585)
            ]),
            (moviesChannel, [
                DemoMessage(author: nil, text: "Dune: Part Three review. The desert has never looked better, and the sound alone is worth the ticket.", minutesAgo: 900, isSpoiler: false),
                DemoMessage(author: nil, text: "Dune: Part Three, the last ten minutes: what really happens to the throne.", minutesAgo: 340, isSpoiler: true),
                DemoMessage(author: nil, text: "Ten films from the last decade shot entirely on location.", minutesAgo: 140, photoColors: [UIColor(rgb: 0xf7971e), UIColor(rgb: 0x3a1c71)]),
                DemoMessage(author: nil, text: "I Play Rocky: what the last scene means and how the story ends.", minutesAgo: 45, isSpoiler: true)
            ]),
            (designChannel, [
                DemoMessage(author: nil, text: "A short guide to optical alignment, with before and after examples.", minutesAgo: 1100),
                DemoMessage(author: nil, text: "Why good empty states are quiet.", minutesAgo: 480)
            ]),
            (mia, [
                DemoMessage(author: mia, text: "Sent you the photos from the lake", minutesAgo: 2100),
                DemoMessage(author: accountPeerId, text: "They're beautiful, thank you!", minutesAgo: 2080)
            ])
        ]
        
        let timestamp = Int32(Date().timeIntervalSince1970)
        var nextMediaId: Int64 = 1
        for (peerId, messages) in chats {
            transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
            transaction.updateCurrentPeerNotificationSettings([peerId: TelegramPeerNotificationSettings.defaultSettings])
            
            var storeMessages: [StoreMessage] = []
            var maxReadId: Int32 = 0
            var unreadCount: Int32 = 0
            for i in 0 ..< messages.count {
                let message = messages[i]
                let isIncoming = message.author != accountPeerId
                let id = Int32(i + 1)
                if message.isRead {
                    maxReadId = id
                } else if isIncoming {
                    unreadCount += 1
                }
                
                var attributes: [MessageAttribute] = []
                if let isSpoiler = message.isSpoiler {
                    attributes.append(SpoilerClassificationMessageAttribute(isSpoiler: isSpoiler))
                }
                if peerId == gamesChannel || peerId == moviesChannel || peerId == designChannel {
                    attributes.append(ViewCountMessageAttribute(count: 14200 - Int(id) * 1730))
                }
                
                var media: [Media] = []
                var tags: MessageTags = []
                if let photoColors = message.photoColors, let image = message.photoName.flatMap({ UIImage(bundleImageName: $0) }) ?? DemoMode.image(colors: photoColors), let data = image.jpegData(compressionQuality: 0.9) {
                    let resource = LocalFileMediaResource(fileId: nextMediaId, size: Int64(data.count))
                    postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                    let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)), resource: resource, progressiveSizes: [], immediateThumbnailData: nil)
                    media.append(TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: nextMediaId), representations: [representation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: []))
                    tags = [.photoOrVideo, .photo]
                    nextMediaId += 1
                }
                
                storeMessages.append(StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: timestamp - message.minutesAgo * 60, flags: isIncoming ? [.Incoming] : [], tags: tags, globalTags: [], localTags: [], forwardInfo: nil, authorId: message.author ?? peerId, text: message.text, attributes: attributes, media: media))
            }
            let _ = transaction.addMessages(storeMessages, location: .UpperHistoryBlock)
            
            // The whole history is local
            let range: ClosedRange<MessageId.Id> = 1 ... (Int32.max - 1)
            transaction.removeHole(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: range)
            for tag in MessageTags.all {
                transaction.removeHole(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .tag(tag), range: range)
            }
            
            let maxId = Int32(messages.count)
            transaction.resetIncomingReadStates([peerId: [Namespaces.Message.Cloud: .idBased(maxIncomingReadId: maxReadId, maxOutgoingReadId: maxId, maxKnownId: maxId, count: unreadCount, markedUnread: false)]])
        }
        
        // Private chats wait for the business intro until the full user info is loaded
        transaction.updatePeerCachedData(peerIds: [accountPeerId, alex, mia, leo], update: { _, _ in
            return CachedUserData().withUpdatedBusinessIntro(nil)
        })
        
        // Chats wait for the contacts until the access is granted
        transaction.updatePreferencesEntry(key: PreferencesKeys.contactsSettings, { _ in
            return PreferencesEntry(ContactsSettings(synchronizeContacts: false))
        })
        
        for groupId in [PeerGroupId.root, Namespaces.PeerGroup.archive] {
            for hole in transaction.allChatListHoles(groupId: groupId) {
                transaction.replaceChatListHole(groupId: groupId, index: hole.index, hole: nil)
            }
        }
        
        return AuthorizedAccountState(isTestingEnvironment: false, masterDatacenterId: 2, peerId: accountPeerId, state: AuthorizedAccountState.State(pts: 1, qts: 0, date: timestamp, seq: 0), invalidatedChannels: [])
    }
    
    private static func image(colors: [UIColor]) -> UIImage? {
        return generateImage(CGSize(width: 1200.0, height: 800.0), contextGenerator: { size, context in
            var locations: [CGFloat] = [0.0, 1.0]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: &locations)!
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: size.height), options: [])
            
            context.setFillColor(UIColor(white: 1.0, alpha: 0.85).cgColor)
            context.fillEllipse(in: CGRect(x: size.width * 0.62, y: size.height * 0.48, width: 220.0, height: 220.0))
            
            context.setFillColor(UIColor(white: 0.0, alpha: 0.45).cgColor)
            let heights: [CGFloat] = [180.0, 290.0, 230.0, 360.0, 200.0, 310.0, 260.0, 170.0]
            let width = size.width / CGFloat(heights.count)
            for i in 0 ..< heights.count {
                context.fill(CGRect(x: CGFloat(i) * width, y: 0.0, width: width - 14.0, height: heights[i]))
            }
        }, opaque: true, scale: 1.0)
    }
}
