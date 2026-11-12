import Foundation
import AppKit
import QuartzCore
import Postbox
import TGUIKit
import TelegramCore

public enum TauContributorRole: Equatable {
    case creator
    case contributor

    //TODOLANG
    public var title: String {
        switch self {
        case .creator:
            return "Taugram creator"
        case .contributor:
            return "Taugram contributor"
        }
    }
}

public enum TauContributors {
    private static let roles: [Int64: TauContributorRole] = [
        1029461991: .creator,
    ]

    public static func role(_ peerId: PeerId?) -> TauContributorRole? {
        guard let peerId, peerId.namespace == Namespaces.Peer.CloudUser else {
            return nil
        }
        return roles[peerId.toInt64()]
    }

    private static func hex(_ value: UInt32) -> NSColor {
        return NSColor(srgbRed: CGFloat((value >> 16) & 0xff) / 255, green: CGFloat((value >> 8) & 0xff) / 255, blue: CGFloat(value & 0xff) / 255, alpha: 1)
    }

    public static func colors(_ role: TauContributorRole, dark: Bool) -> [NSColor] {
        switch (role, dark) {
        case (.creator, false):
            return [hex(0xBA7517), hex(0xD4537E), hex(0x534AB7)]
        case (.creator, true):
            return [hex(0xFAC775), hex(0xED93B1), hex(0xAFA9EC)]
        case (.contributor, false):
            return [hex(0x534AB7), hex(0x7F77DD)]
        case (.contributor, true):
            return [hex(0xAFA9EC), hex(0xCECBF6)]
        }
    }

    public static func iconColor(_ role: TauContributorRole) -> NSColor {
        switch role {
        case .creator:
            return hex(0xBA7517)
        case .contributor:
            return hex(0x534AB7)
        }
    }
}

private func tauWhiteLayout(_ layout: TextViewLayout) -> TextViewLayout {
    let attributed = layout.attributedString.mutableCopy() as! NSMutableAttributedString
    attributed.addAttribute(.foregroundColor, value: NSColor.white, range: NSMakeRange(0, attributed.length))
    let white = TextViewLayout(attributed, maximumNumberOfLines: 1, truncationType: .end)
    white.measure(width: layout.layoutSize.width + 1)
    return white
}

public final class TauNameGradientLayer: SimpleLayer {
    private let gradient = CAGradientLayer()
    private let textMask = TextViewLayer()
    private var shine: CAGradientLayer?
    private var layoutSize: NSSize = .zero

    public override init() {
        super.init()
        self.gradient.startPoint = CGPoint(x: 0, y: 0.5)
        self.gradient.endPoint = CGPoint(x: 1, y: 0.5)
        self.gradient.mask = self.textMask
        self.addSublayer(self.gradient)
    }

    public override init(layer: Any) {
        super.init(layer: layer)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeMask(_ layout: TextViewLayout, scale: CGFloat) -> TextViewLayer {
        let mask = TextViewLayer()
        mask.contentsScale = scale
        mask.update(tauWhiteLayout(layout))
        let bounds = CGRect(origin: .zero, size: self.layoutSize)
        mask.frame = bounds
        mask.bounds = bounds.insetBy(dx: -2, dy: -3)
        return mask
    }

    public func update(layout: TextViewLayout, role: TauContributorRole, dark: Bool, origin: NSPoint, scale: CGFloat) {
        self.layoutSize = layout.layoutSize
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.frame = CGRect(origin: origin, size: layout.layoutSize)
        let bounds = CGRect(origin: .zero, size: layout.layoutSize)
        self.gradient.frame = bounds
        self.gradient.colors = TauContributors.colors(role, dark: dark).map { $0.cgColor }
        self.textMask.contentsScale = scale
        self.textMask.update(tauWhiteLayout(layout))
        self.textMask.frame = bounds
        self.textMask.bounds = bounds.insetBy(dx: -2, dy: -3)
        self.textMask.setNeedsDisplay()
        CATransaction.commit()
    }

    public func shimmer(layout: TextViewLayout, scale: CGFloat) {
        self.shine?.removeFromSuperlayer()
        let band = CAGradientLayer()
        band.frame = CGRect(origin: .zero, size: self.layoutSize)
        band.startPoint = CGPoint(x: 0, y: 0.5)
        band.endPoint = CGPoint(x: 1, y: 0.5)
        band.colors = [NSColor.white.withAlphaComponent(0).cgColor, NSColor.white.withAlphaComponent(0.9).cgColor, NSColor.white.withAlphaComponent(0).cgColor]
        band.locations = [-0.3, -0.15, 0]
        band.mask = self.makeMask(layout, scale: scale)
        self.addSublayer(band)
        self.shine = band
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-0.3, -0.15, 0]
        animation.toValue = [1, 1.15, 1.3]
        animation.duration = 1.1
        animation.beginTime = CACurrentMediaTime() + 0.25
        animation.fillMode = .backwards
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self, weak band] in
            band?.removeFromSuperlayer()
            if self?.shine === band {
                self?.shine = nil
            }
        }
        band.add(animation, forKey: "shimmer")
        CATransaction.commit()
    }
}

public func tauRoleIcon(_ role: TauContributorRole, size: CGFloat = 16) -> CGImage? {
    return generateImage(NSMakeSize(size, size), rotatedContext: { size, ctx in
        ctx.clear(CGRect(origin: .zero, size: size))
        let rect = CGRect(origin: .zero, size: size)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: size.width * 0.3, cornerHeight: size.height * 0.3, transform: nil))
        ctx.setFillColor(TauContributors.iconColor(role).cgColor)
        ctx.fillPath()
        let font = NSFont.systemFont(ofSize: size.height * 0.72, weight: .semibold)
        let text = NSAttributedString(string: "τ", attributes: [.font: font, .foregroundColor: NSColor.white])
        let line = CTLineCreateWithAttributedString(text)
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        ctx.textPosition = CGPoint(x: (size.width - bounds.width) / 2 - bounds.minX, y: (size.height - bounds.height) / 2 - bounds.minY)
        CTLineDraw(line, ctx)
    })
}
