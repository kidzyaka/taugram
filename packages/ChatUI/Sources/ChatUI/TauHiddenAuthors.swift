import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramContext
import TauSettings

func tauHiddenAuthors(context: any AccountContextProtocol, peerId: PeerId?) -> Signal<Set<PeerId>, NoError> {
    guard let peerId, peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.CloudChannel else {
        return .single(Set())
    }
    let enabled = TauSettings.shared.signal |> map { $0.hideBlockedInGroups } |> distinctUntilChanged
    return enabled |> mapToSignal { enabled -> Signal<Set<PeerId>, NoError> in
        guard enabled else {
            return .single(Set())
        }
        let blocked = context.blockedPeersContext
        return blocked.state |> map { state -> Set<PeerId> in
            if state.canLoadMore {
                Queue.mainQueue().justDispatch {
                    blocked.loadMore()
                }
            }
            return Set(state.peers.map { $0.peerId })
        }
    } |> distinctUntilChanged |> runOn(.mainQueue())
}

func tauFilterHiddenAuthors(_ entries: [MessageHistoryEntry], hidden: Set<PeerId>) -> [MessageHistoryEntry] {
    guard !hidden.isEmpty else {
        return entries
    }
    return entries.filter { entry in
        let message = entry.message
        if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
            return true
        }
        if message.media.first is TelegramMediaAction {
            return true
        }
        guard let authorId = message.author?.id else {
            return true
        }
        return !hidden.contains(authorId)
    }
}
