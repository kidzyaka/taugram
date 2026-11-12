import Cocoa
import TGUIKit
import TauSettings

public enum TauAppIcon: String, CaseIterable {
    case classic
    case violet
    case ocean
    case midnight
    case paper

    var title: String {
        switch self {
        case .classic:
            //TODOLANG
            return "Classic"
        case .violet:
            //TODOLANG
            return "Violet"
        case .ocean:
            //TODOLANG
            return "Ocean"
        case .midnight:
            //TODOLANG
            return "Midnight"
        case .paper:
            //TODOLANG
            return "Paper"
        }
    }

    fileprivate var background: (NSColor, NSColor) {
        switch self {
        case .classic, .violet:
            return (NSColor(srgbRed: 0.561, green: 0.400, blue: 0.941, alpha: 1), NSColor(srgbRed: 0.369, green: 0.208, blue: 0.804, alpha: 1))
        case .ocean:
            return (NSColor(srgbRed: 0.247, green: 0.663, blue: 0.961, alpha: 1), NSColor(srgbRed: 0.118, green: 0.435, blue: 0.851, alpha: 1))
        case .midnight:
            return (NSColor(srgbRed: 0.102, green: 0.102, blue: 0.133, alpha: 1), NSColor(srgbRed: 0.020, green: 0.020, blue: 0.031, alpha: 1))
        case .paper:
            return (NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1), NSColor(srgbRed: 0.925, green: 0.925, blue: 0.949, alpha: 1))
        }
    }

    fileprivate var glyph: NSColor {
        switch self {
        case .classic, .violet, .ocean:
            return .white
        case .midnight, .paper:
            return NSColor(srgbRed: 0.561, green: 0.400, blue: 0.941, alpha: 1)
        }
    }
}

private func drawTauGlyph(in ctx: CGContext, color: NSColor, lineWidth: CGFloat) {
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(lineWidth)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: 318, y: 420))
    ctx.addCurve(to: CGPoint(x: 404, y: 340), control1: CGPoint(x: 318, y: 368), control2: CGPoint(x: 352, y: 340))
    ctx.addLine(to: CGPoint(x: 712, y: 340))
    ctx.move(to: CGPoint(x: 530, y: 340))
    ctx.addLine(to: CGPoint(x: 530, y: 612))
    ctx.addCurve(to: CGPoint(x: 604, y: 690), control1: CGPoint(x: 530, y: 664), control2: CGPoint(x: 556, y: 690))
    ctx.addCurve(to: CGPoint(x: 668, y: 668), control1: CGPoint(x: 632, y: 690), control2: CGPoint(x: 652, y: 682))
    ctx.strokePath()
}

private func drawTauIcon(_ icon: TauAppIcon, in ctx: CGContext, size: CGFloat, topDown: Bool, inset: CGFloat, cornerRadius: CGFloat) {
    let scale = size / 1024
    ctx.saveGState()
    if !topDown {
        ctx.translateBy(x: 0, y: size)
        ctx.scaleBy(x: 1, y: -1)
    }
    ctx.scaleBy(x: scale, y: scale)
    let rect = CGRect(x: inset, y: inset, width: 1024 - inset * 2, height: 1024 - inset * 2)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
    ctx.clip()
    let colors = [icon.background.0.cgColor, icon.background.1.cgColor] as CFArray
    if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: rect.minY), end: CGPoint(x: 0, y: rect.maxY), options: [])
    }
    ctx.resetClip()
    drawTauGlyph(in: ctx, color: icon.glyph, lineWidth: 84)
    ctx.restoreGState()
}

func generateTauAppIconThumb(_ icon: TauAppIcon) -> CGImage {
    return generateImage(NSMakeSize(24, 24), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: .zero, size: size))
        drawTauIcon(icon, in: ctx, size: size.width, topDown: true, inset: 24, cornerRadius: 240)
    }, scale: System.backingScale)!
}

public final class TauAppIconManager {
    private static let queue = DispatchQueue(label: "taugram.app-icon", qos: .utility)
    private static let appliedKey = "taugram.appliedAppIcon"

    private static var iconsFolder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Taugram/Icons", isDirectory: true)
    }

    private static func imageURL(_ icon: TauAppIcon) -> URL? {
        let url = iconsFolder.appendingPathComponent("\(icon.rawValue).png")
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }
        context.cgContext.clear(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        drawTauIcon(icon, in: context.cgContext, size: 1024, topDown: false, inset: 100, cornerRadius: 185)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        try? FileManager.default.createDirectory(at: iconsFolder, withIntermediateDirectories: true)
        guard (try? data.write(to: url)) != nil else {
            return nil
        }
        return url
    }

    public static func apply(_ id: String?) {
        assert(Thread.isMainThread)
        let icon = id.flatMap(TauAppIcon.init(rawValue:)) ?? .classic
        let image: NSImage?
        if icon == .classic {
            image = nil
        } else if let url = imageURL(icon), let loaded = NSImage(contentsOf: url) {
            image = loaded
        } else {
            return
        }
        NSApplication.shared.applicationIconImage = image
        let defaults = UserDefaults.standard
        let applied = icon.rawValue
        guard defaults.string(forKey: appliedKey) != applied else {
            return
        }
        defaults.set(applied, forKey: appliedKey)
        let bundlePath = Bundle.main.bundlePath
        let persistent = image?.copy() as? NSImage
        queue.async {
            NSWorkspace.shared.setIcon(persistent, forFile: bundlePath, options: [])
        }
    }

    public static func applyStored() {
        apply(TauSettings.shared.current.appIcon)
    }
}
