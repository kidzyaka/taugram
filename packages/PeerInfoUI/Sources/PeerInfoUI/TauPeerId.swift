import Foundation
import TelegramCore
import Postbox

struct TauPeerIdValue {
    let id: String
    let datacenterId: Int?

    init(_ encoded: String) {
        let parts = encoded.split(separator: "|", maxSplits: 1).map(String.init)
        self.id = parts.first ?? encoded
        self.datacenterId = parts.count > 1 ? Int(parts[1]) : nil
    }

    static func encode(_ peer: Peer) -> String {
        let raw = peer.id.id._internalGetInt64Value()
        let id: String
        switch peer.id.namespace {
        case Namespaces.Peer.CloudChannel:
            id = "-100\(raw)"
        case Namespaces.Peer.CloudGroup:
            id = "-\(raw)"
        default:
            id = "\(raw)"
        }
        let datacenterId = peer.profileImageRepresentations.lazy.compactMap { ($0.resource as? CloudPeerPhotoSizeMediaResource)?.datacenterId }.first
        if let datacenterId {
            return "\(id)|\(datacenterId)"
        }
        return id
    }

    var label: String {
        if let datacenterId {
            return "PEER ID · DC \(datacenterId)"
        }
        return "PEER ID"
    }
}
