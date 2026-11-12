import Foundation
import Cocoa
import TGUIKit
import TauSettings
import ColorPalette
import TelegramTheme
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

final class TauRolePillView: View {
    static let height: CGFloat = 22
    static let spacing: CGFloat = 8

    private let textView = TextView()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.cornerRadius = TauRolePillView.height / 2
        self.textView.userInteractionEnabled = false
        self.textView.isSelectable = false
        self.addSubview(self.textView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(role: TauContributorRole) {
        let filled = role == .creator
        let violet = theme.colors.isDark ? NSColor(0x8F86F0) : NSColor(0x534AB7)
        //TODOLANG
        let title = filled ? "Taugram creator" : "Taugram contributor"
        let layout = TextViewLayout(.initialize(string: title, color: filled ? .white : violet, font: .medium(.text)), maximumNumberOfLines: 1)
        layout.measure(width: .greatestFiniteMagnitude)
        self.textView.update(layout)
        self.layer?.backgroundColor = filled ? NSColor(0x534AB7).cgColor : NSColor.clear.cgColor
        self.layer?.borderWidth = filled ? 0 : 1
        self.layer?.borderColor = violet.cgColor
        self.setFrameSize(NSMakeSize(layout.layoutSize.width + 22, TauRolePillView.height))
        self.needsLayout = true
    }

    override func layout() {
        super.layout()
        self.textView.center()
    }
}
