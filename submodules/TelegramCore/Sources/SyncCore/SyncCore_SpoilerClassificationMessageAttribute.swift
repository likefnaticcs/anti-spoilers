import Foundation
import Postbox

/// Result of the server-side check that tells whether a message reveals the plot or only mentions the topic.
public final class SpoilerClassificationMessageAttribute: MessageAttribute {
    public let isSpoiler: Bool
    
    public init(isSpoiler: Bool) {
        self.isSpoiler = isSpoiler
    }
    
    required public init(decoder: PostboxDecoder) {
        self.isSpoiler = decoder.decodeInt32ForKey("s", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.isSpoiler ? 1 : 0, forKey: "s")
    }
}
