import Cocoa
import TGUIKit

public func generateTauSettingsIcon() -> CGImage {
    return generateImage(NSMakeSize(24, 24), contextGenerator: { size, ctx in
        let bounds = CGRect(origin: .zero, size: size)
        ctx.clear(bounds)
        let path = CGPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerWidth: 6, cornerHeight: 6, transform: nil)
        ctx.addPath(path)
        ctx.clip()
        let colors = [NSColor(srgbRed: 0.561, green: 0.400, blue: 0.941, alpha: 1).cgColor, NSColor(srgbRed: 0.369, green: 0.208, blue: 0.804, alpha: 1).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
        }
        ctx.resetClip()
        let scale = size.width / 1024
        ctx.scaleBy(x: scale, y: scale)
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(96)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.move(to: CGPoint(x: 300, y: 430))
        ctx.addCurve(to: CGPoint(x: 400, y: 330), control1: CGPoint(x: 300, y: 365), control2: CGPoint(x: 340, y: 330))
        ctx.addLine(to: CGPoint(x: 730, y: 330))
        ctx.move(to: CGPoint(x: 530, y: 330))
        ctx.addLine(to: CGPoint(x: 530, y: 620))
        ctx.addCurve(to: CGPoint(x: 610, y: 705), control1: CGPoint(x: 530, y: 675), control2: CGPoint(x: 558, y: 705))
        ctx.addCurve(to: CGPoint(x: 685, y: 680), control1: CGPoint(x: 640, y: 705), control2: CGPoint(x: 665, y: 697))
        ctx.strokePath()
    }, scale: System.backingScale)!
}
