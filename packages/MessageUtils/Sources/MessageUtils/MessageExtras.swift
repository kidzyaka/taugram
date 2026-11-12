import Foundation
import TelegramCore
import Postbox

public func messageForForwarding(_ message: Message) -> Message {
    return message.activeEphemeralReplacementMessage ?? message
}

public extension Message {
    func isCopyProtected(cachedData: CachedPeerData?, ignoringTaugram: Bool = false) -> Bool { // Taugram
        if !ignoringTaugram && TauCoreSettings.shared.bypassesContentProtection { // Taugram
            return false
        }
        if self.isCopyProtected(ignoringTaugram: ignoringTaugram) { // Taugram
            return true
        }
        if let _ = self.peers[self.id.peerId] as? TelegramUser, let cachedData = cachedData as? CachedUserData {
            return cachedData.flags.contains(.copyProtectionEnabled) || cachedData.flags.contains(.myCopyProtectionEnabled)
        }
        return false
    }
}
