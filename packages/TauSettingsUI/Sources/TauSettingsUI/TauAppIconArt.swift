import Cocoa

private func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    return CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

private func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    return CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations)!
}

func tauGlyphPath() -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 318, y: 420))
    path.addCurve(to: CGPoint(x: 404, y: 340), control1: CGPoint(x: 318, y: 368), control2: CGPoint(x: 352, y: 340))
    path.addLine(to: CGPoint(x: 712, y: 340))
    path.move(to: CGPoint(x: 530, y: 340))
    path.addLine(to: CGPoint(x: 530, y: 612))
    path.addCurve(to: CGPoint(x: 604, y: 690), control1: CGPoint(x: 530, y: 664), control2: CGPoint(x: 556, y: 690))
    path.addCurve(to: CGPoint(x: 668, y: 668), control1: CGPoint(x: 632, y: 690), control2: CGPoint(x: 652, y: 682))
    return path
}

func strokeTauPath(_ ctx: CGContext, _ path: CGPath, color: CGColor, width: CGFloat) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.restoreGState()
}

private func softBlob(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color: CGColor, scaleY: CGFloat = 1) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.scaleBy(x: 1, y: scaleY)
    ctx.drawRadialGradient(gradient([color, color.copy(alpha: 0)!], [0, 1]), startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: radius, options: [])
    ctx.restoreGState()
}

private func tile(_ inset: CGFloat, _ cornerRadius: CGFloat) -> CGPath {
    let rect = CGRect(x: inset, y: inset, width: 1024 - inset * 2, height: 1024 - inset * 2)
    return CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
}

func drawTauCetiIcon(in ctx: CGContext, inset: CGFloat, cornerRadius: CGFloat) {
    ctx.saveGState()
    ctx.addPath(tile(inset, cornerRadius))
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(44, 26, 96), rgb(16, 11, 44), rgb(5, 4, 16)], [0, 0.55, 1]), start: CGPoint(x: 512, y: 0), end: CGPoint(x: 512, y: 1024), options: [])
    softBlob(ctx, center: CGPoint(x: 260, y: 860), radius: 460, color: rgb(130, 70, 230, 0.3), scaleY: 0.55)

    var seed: UInt64 = 0x7a0c371
    func random() -> CGFloat {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((seed >> 33) % 10000) / 10000
    }
    for _ in 0 ..< 70 {
        let point = CGPoint(x: inset + random() * (1024 - inset * 2), y: inset + random() * (1024 - inset * 2))
        let radius = 1.6 + random() * random() * 5
        ctx.setFillColor(rgb(255, 255, 255, 0.3 + random() * 0.6))
        ctx.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }

    let star = CGPoint(x: 760, y: 262)
    let orbit = CGSize(width: 420, height: 120)
    let orbitTransform = CGAffineTransform(translationX: star.x, y: star.y).rotated(by: 0.38)
    softBlob(ctx, center: star, radius: 380, color: rgb(255, 160, 60, 0.38))
    softBlob(ctx, center: star, radius: 170, color: rgb(255, 205, 120, 0.7))

    var orbitPathTransform = orbitTransform
    ctx.addPath(CGPath(ellipseIn: CGRect(x: -orbit.width, y: -orbit.height, width: orbit.width * 2, height: orbit.height * 2), transform: &orbitPathTransform))
    ctx.setStrokeColor(rgb(255, 214, 150, 0.5))
    ctx.setLineWidth(5)
    ctx.strokePath()

    ctx.drawRadialGradient(gradient([rgb(255, 255, 255), rgb(255, 238, 190), rgb(255, 180, 80)], [0, 0.5, 1]), startCenter: star, startRadius: 0, endCenter: star, endRadius: 52, options: [])
    softBlob(ctx, center: star, radius: 60, color: rgb(255, 252, 235, 0.85))

    let planetAngle: CGFloat = 2.45
    let planet = CGPoint(x: orbit.width * cos(planetAngle), y: orbit.height * sin(planetAngle)).applying(orbitTransform)
    ctx.drawRadialGradient(gradient([rgb(170, 220, 255), rgb(70, 120, 230), rgb(24, 32, 96)], [0, 0.55, 1]), startCenter: CGPoint(x: planet.x + 9, y: planet.y - 9), startRadius: 0, endCenter: planet, endRadius: 30, options: [])

    for (width, alpha) in [(CGFloat(150), CGFloat(0.06)), (124, 0.1), (104, 0.16)] {
        strokeTauPath(ctx, tauGlyphPath(), color: rgb(190, 160, 255, alpha), width: width)
    }
    strokeTauPath(ctx, tauGlyphPath(), color: rgb(255, 255, 255), width: 84)
    ctx.restoreGState()
}

func drawOGIcon(in ctx: CGContext, inset: CGFloat) {
    let fit = (1124 - inset * 2) / 1024
    ctx.saveGState()
    ctx.translateBy(x: 512, y: 512)
    ctx.scaleBy(x: fit, y: fit)
    ctx.translateBy(x: -512, y: -512)

    let center = CGPoint(x: 512, y: 494)
    let radius: CGFloat = 400
    let k = radius / 328
    let orb = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

    softBlob(ctx, center: CGPoint(x: center.x, y: center.y + radius + 12), radius: 360, color: rgb(0, 0, 0, 0.45), scaleY: 0.07)

    ctx.saveGState()
    ctx.addEllipse(in: orb)
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(36, 8, 104), rgb(104, 46, 222), rgb(196, 128, 255)], [0, 0.5, 1]), start: CGPoint(x: 0, y: orb.minY), end: CGPoint(x: 0, y: orb.maxY), options: [])
    softBlob(ctx, center: CGPoint(x: center.x, y: center.y + radius * 0.78), radius: radius * 0.95, color: rgb(255, 190, 255, 0.8), scaleY: 0.6)
    ctx.drawRadialGradient(gradient([rgb(20, 0, 70, 0), rgb(20, 0, 70, 0.5)], [0, 1]), startCenter: center, startRadius: radius * 0.72, endCenter: center, endRadius: radius, options: [])

    var glyphTransform = CGAffineTransform(translationX: center.x, y: center.y + 14 * k).scaledBy(x: 0.74 * k, y: 0.74 * k).translatedBy(x: -515, y: -515)
    let glyph = tauGlyphPath().copy(using: &glyphTransform)!
    var shadowTransform = CGAffineTransform(translationX: 0, y: 20 * k)
    let shadow = glyph.copy(using: &shadowTransform)!
    for (width, alpha) in [(CGFloat(110), CGFloat(0.12)), (96, 0.18), (84, 0.25)] {
        strokeTauPath(ctx, shadow, color: rgb(20, 0, 70, alpha), width: width * k)
    }
    ctx.saveGState()
    ctx.addPath(glyph.copy(strokingWithWidth: 78 * k, lineCap: .round, lineJoin: .round, miterLimit: 10))
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(255, 255, 255), rgb(232, 222, 255), rgb(190, 170, 250)], [0, 0.6, 1]), start: CGPoint(x: 0, y: center.y - 210 * k), end: CGPoint(x: 0, y: center.y + 270 * k), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    var innerShadeTransform = CGAffineTransform(translationX: 0, y: 6 * k)
    strokeTauPath(ctx, glyph.copy(using: &innerShadeTransform)!, color: rgb(140, 110, 220, 0.45), width: 74 * k)
    ctx.restoreGState()
    ctx.restoreGState()
    strokeTauPath(ctx, CGPath(ellipseIn: orb.insetBy(dx: 2 * k, dy: 2 * k), transform: nil), color: rgb(30, 4, 80, 0.85), width: 6 * k)

    let gloss = CGRect(x: center.x - radius * 0.72, y: center.y - radius * 0.95, width: radius * 1.44, height: radius * 0.8)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: gloss, cornerWidth: gloss.width * 0.5, cornerHeight: gloss.height * 0.5, transform: nil))
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(255, 255, 255, 0.92), rgb(255, 255, 255, 0.1)], [0, 1]), start: CGPoint(x: 0, y: gloss.minY), end: CGPoint(x: 0, y: gloss.maxY), options: [])
    ctx.restoreGState()

    let rim = CGMutablePath()
    rim.addArc(center: center, radius: radius - 18 * k, startAngle: 0.45, endAngle: .pi - 0.45, clockwise: false)
    strokeTauPath(ctx, rim, color: rgb(255, 230, 255, 0.28), width: 10 * k)
    ctx.restoreGState()
}

private func paperPlanePath() -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 316, y: 503))
    path.addLine(to: CGPoint(x: 646, y: 366))
    path.addCurve(to: CGPoint(x: 677, y: 392), control1: CGPoint(x: 662, y: 360), control2: CGPoint(x: 680, y: 370))
    path.addLine(to: CGPoint(x: 636, y: 658))
    path.addCurve(to: CGPoint(x: 591, y: 676), control1: CGPoint(x: 632, y: 684), control2: CGPoint(x: 610, y: 690))
    path.addLine(to: CGPoint(x: 471, y: 598))
    path.addCurve(to: CGPoint(x: 466, y: 562), control1: CGPoint(x: 456, y: 588), control2: CGPoint(x: 452, y: 575))
    path.addLine(to: CGPoint(x: 576, y: 457))
    path.addCurve(to: CGPoint(x: 572, y: 445), control1: CGPoint(x: 584, y: 450), control2: CGPoint(x: 580, y: 441))
    path.addLine(to: CGPoint(x: 426, y: 541))
    path.addCurve(to: CGPoint(x: 376, y: 552), control1: CGPoint(x: 410, y: 551), control2: CGPoint(x: 396, y: 557))
    path.addLine(to: CGPoint(x: 312, y: 534))
    path.addCurve(to: CGPoint(x: 316, y: 503), control1: CGPoint(x: 290, y: 528), control2: CGPoint(x: 293, y: 512))
    path.closeSubpath()
    return path
}

func drawPaperPlaneIcon(in ctx: CGContext, inset: CGFloat, cornerRadius: CGFloat) {
    ctx.saveGState()
    ctx.addPath(tile(inset, cornerRadius))
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(253, 253, 253), rgb(232, 232, 236)], [0, 1]), start: .zero, end: CGPoint(x: 0, y: 1024), options: [])
    ctx.restoreGState()

    let circle = CGRect(x: 158, y: 158, width: 708, height: 708)
    ctx.saveGState()
    ctx.addEllipse(in: circle)
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(168, 128, 255), rgb(108, 62, 222)], [0, 1]), start: CGPoint(x: 0, y: circle.minY), end: CGPoint(x: 0, y: circle.maxY), options: [])
    var shadowOffset = CGAffineTransform(translationX: 0, y: 14)
    ctx.addPath(paperPlanePath().copy(using: &shadowOffset)!)
    ctx.setFillColor(rgb(60, 20, 150, 0.22))
    ctx.fillPath()
    ctx.addPath(paperPlanePath())
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(255, 255, 255), rgb(236, 226, 255)], [0, 1]), start: CGPoint(x: 520, y: 470), end: CGPoint(x: 640, y: 690), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

private func linePath(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    path.addLines(between: points)
    return path
}

private func offsetPath(_ path: CGPath, _ dx: CGFloat, _ dy: CGFloat) -> CGPath {
    var transform = CGAffineTransform(translationX: dx, y: dy)
    return path.copy(using: &transform)!
}

private func scaledTauGlyphPath(_ scale: CGFloat, center: CGPoint) -> CGPath {
    var transform = CGAffineTransform(translationX: center.x, y: center.y).scaledBy(x: scale, y: scale).translatedBy(x: -515, y: -515)
    return tauGlyphPath().copy(using: &transform)!
}

private func strokeDashedPath(_ ctx: CGContext, _ path: CGPath, color: CGColor, width: CGFloat, dash: [CGFloat]) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.setLineDash(phase: 0, lengths: dash)
    ctx.strokePath()
    ctx.restoreGState()
}

private func beginTile(_ ctx: CGContext, inset: CGFloat, cornerRadius: CGFloat, colors: [CGColor], locations: [CGFloat]) {
    ctx.saveGState()
    ctx.addPath(tile(inset, cornerRadius))
    ctx.clip()
    ctx.drawLinearGradient(gradient(colors, locations), start: CGPoint(x: 0, y: inset), end: CGPoint(x: 0, y: 1024 - inset), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func drawSynthwaveIcon(in ctx: CGContext, inset: CGFloat, cornerRadius: CGFloat) {
    let horizon: CGFloat = 650
    beginTile(ctx, inset: inset, cornerRadius: cornerRadius, colors: [rgb(18, 6, 56), rgb(84, 18, 120), rgb(255, 84, 150)], locations: [0, 0.55, 0.66])

    var seed: UInt64 = 0x51b
    func random() -> CGFloat {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((seed >> 33) % 10000) / 10000
    }
    for _ in 0 ..< 36 {
        let point = CGPoint(x: inset + random() * (1024 - inset * 2), y: inset + random() * 360)
        let radius = 1.5 + random() * 3
        ctx.setFillColor(rgb(255, 255, 255, 0.4 + random() * 0.5))
        ctx.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }

    softBlob(ctx, center: CGPoint(x: 512, y: horizon - 120), radius: 380, color: rgb(255, 90, 170, 0.45))
    let sun = CGRect(x: 512 - 236, y: horizon - 380, width: 472, height: 472)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.addEllipse(in: sun)
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(255, 238, 110), rgb(255, 150, 90), rgb(255, 60, 150)], [0, 0.5, 1]), start: CGPoint(x: 0, y: sun.minY), end: CGPoint(x: 0, y: horizon), options: [])
    ctx.setBlendMode(.destinationOut)
    var stripeY: CGFloat = horizon - 170
    var stripeHeight: CGFloat = 7
    while stripeY < horizon {
        ctx.fill(CGRect(x: 0, y: stripeY, width: 1024, height: stripeHeight))
        stripeY += stripeHeight + 22
        stripeHeight += 5
    }
    ctx.endTransparencyLayer()

    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: horizon, width: 1024, height: 1024 - horizon))
    ctx.drawLinearGradient(gradient([rgb(40, 6, 70), rgb(16, 4, 34)], [0, 1]), start: CGPoint(x: 0, y: horizon), end: CGPoint(x: 0, y: 1024 - inset), options: [])
    let grid = rgb(255, 70, 210)
    for k in 1 ... 9 {
        let t = CGFloat(k) / 9
        let y = horizon + (1024 - inset - horizon) * pow(t, 1.9)
        strokeTauPath(ctx, linePath([CGPoint(x: 0, y: y), CGPoint(x: 1024, y: y)]), color: grid, width: 3 + 4 * t)
    }
    for i in -8 ... 8 {
        strokeTauPath(ctx, linePath([CGPoint(x: 512 + CGFloat(i) * 22, y: horizon), CGPoint(x: 512 + CGFloat(i) * 150, y: 1024 - inset + 40)]), color: grid, width: 5)
    }
    ctx.restoreGState()
    strokeTauPath(ctx, linePath([CGPoint(x: 0, y: horizon), CGPoint(x: 1024, y: horizon)]), color: rgb(255, 200, 240), width: 5)
    softBlob(ctx, center: CGPoint(x: 512, y: horizon), radius: 420, color: rgb(255, 120, 220, 0.4), scaleY: 0.12)

    let glyph = scaledTauGlyphPath(0.6, center: CGPoint(x: 512, y: 430))
    strokeTauPath(ctx, offsetPath(glyph, 0, 10), color: rgb(30, 0, 50, 0.55), width: 66)
    strokeTauPath(ctx, glyph, color: rgb(40, 10, 90), width: 62)
    ctx.saveGState()
    ctx.addPath(glyph.copy(strokingWithWidth: 50, lineCap: .round, lineJoin: .round, miterLimit: 10))
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(240, 250, 255), rgb(120, 180, 255), rgb(40, 30, 110), rgb(255, 150, 220), rgb(255, 230, 250)], [0, 0.48, 0.5, 0.75, 1]), start: CGPoint(x: 0, y: 330), end: CGPoint(x: 0, y: 540), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
    ctx.restoreGState()
}

func drawPixelIcon(in ctx: CGContext, inset: CGFloat, cornerRadius: CGFloat) {
    beginTile(ctx, inset: inset, cornerRadius: cornerRadius, colors: [rgb(132, 92, 246), rgb(80, 42, 196)], locations: [0, 1])
    let cell: CGFloat = 56
    let count = 18
    let origin = 512 - cell * CGFloat(count) / 2
    for i in 0 ... count {
        let v = origin + CGFloat(i) * cell
        strokeTauPath(ctx, linePath([CGPoint(x: v, y: 0), CGPoint(x: v, y: 1024)]), color: rgb(255, 255, 255, 0.07), width: 2)
        strokeTauPath(ctx, linePath([CGPoint(x: 0, y: v), CGPoint(x: 1024, y: v)]), color: rgb(255, 255, 255, 0.07), width: 2)
    }
    let shape = tauGlyphPath().copy(strokingWithWidth: 96, lineCap: .round, lineJoin: .round, miterLimit: 10)
    let pixels = CGMutablePath()
    for row in 0 ..< count {
        for col in 0 ..< count {
            let rect = CGRect(x: origin + CGFloat(col) * cell, y: origin + CGFloat(row) * cell, width: cell, height: cell)
            if shape.contains(CGPoint(x: rect.midX, y: rect.midY)) {
                pixels.addRect(rect.insetBy(dx: -0.5, dy: -0.5))
            }
        }
    }
    ctx.addPath(offsetPath(pixels, cell * 0.5, cell * 0.5))
    ctx.setFillColor(rgb(40, 14, 120))
    ctx.fillPath()
    ctx.addPath(pixels)
    ctx.setFillColor(rgb(255, 255, 255))
    ctx.fillPath()
    let unit = cell * 0.5
    ctx.setFillColor(rgb(255, 236, 140, 0.95))
    for point in [CGPoint(x: 248, y: 248), CGPoint(x: 776, y: 760)] {
        ctx.fill(CGRect(x: point.x - unit / 2, y: point.y - unit * 1.5, width: unit, height: unit * 3))
        ctx.fill(CGRect(x: point.x - unit * 1.5, y: point.y - unit / 2, width: unit * 3, height: unit))
    }
    ctx.restoreGState()
}

func drawLiquidGlassIcon(in ctx: CGContext, inset: CGFloat, cornerRadius: CGFloat) {
    beginTile(ctx, inset: inset, cornerRadius: cornerRadius, colors: [rgb(238, 234, 252), rgb(214, 208, 240)], locations: [0, 1])
    softBlob(ctx, center: CGPoint(x: 330, y: 320), radius: 470, color: rgb(140, 90, 255, 0.95))
    softBlob(ctx, center: CGPoint(x: 780, y: 440), radius: 400, color: rgb(255, 110, 200, 0.85))
    softBlob(ctx, center: CGPoint(x: 520, y: 840), radius: 460, color: rgb(80, 170, 255, 0.85))

    let glyph = tauGlyphPath()
    let width: CGFloat = 100
    for (dy, alpha) in [(CGFloat(30), CGFloat(0.08)), (22, 0.1), (14, 0.12)] {
        strokeTauPath(ctx, offsetPath(glyph, 0, dy), color: rgb(40, 20, 110, alpha), width: width + dy)
    }
    let body = glyph.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    ctx.setFillColor(rgb(255, 255, 255, 0.34))
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    ctx.drawLinearGradient(gradient([rgb(255, 255, 255, 0.45), rgb(255, 255, 255, 0.05)], [0, 1]), start: CGPoint(x: 0, y: 290), end: CGPoint(x: 0, y: 740), options: [])
    ctx.restoreGState()
    for (dy, color) in [(CGFloat(7), rgb(255, 255, 255, 0.95)), (-6, rgb(255, 255, 255, 0.55))] {
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.addPath(body)
        ctx.setFillColor(color)
        ctx.fillPath()
        ctx.setBlendMode(.destinationOut)
        ctx.addPath(offsetPath(glyph, 0, dy).copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10))
        ctx.fillPath()
        ctx.endTransparencyLayer()
    }

    strokeTauPath(ctx, tile(inset, cornerRadius), color: rgb(255, 255, 255, 0.7), width: 14)
    ctx.restoreGState()
}

func drawBlueprintIcon(in ctx: CGContext, inset: CGFloat, cornerRadius: CGFloat) {
    beginTile(ctx, inset: inset, cornerRadius: cornerRadius, colors: [rgb(30, 92, 190), rgb(16, 56, 140)], locations: [0, 1])
    for i in 0 ... 32 {
        let v = CGFloat(i) * 32
        let major = i % 4 == 0
        let color = rgb(220, 236, 255, major ? 0.22 : 0.09)
        strokeTauPath(ctx, linePath([CGPoint(x: v, y: 0), CGPoint(x: v, y: 1024)]), color: color, width: major ? 2.5 : 1.5)
        strokeTauPath(ctx, linePath([CGPoint(x: 0, y: v), CGPoint(x: 1024, y: v)]), color: color, width: major ? 2.5 : 1.5)
    }
    let ink = rgb(240, 248, 255)
    let faintInk = rgb(240, 248, 255, 0.8)
    let glyph = tauGlyphPath()
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    strokeTauPath(ctx, glyph, color: rgb(240, 248, 255, 0.95), width: 90)
    ctx.setBlendMode(.destinationOut)
    strokeTauPath(ctx, glyph, color: rgb(0, 0, 0, 0.88), width: 80)
    ctx.endTransparencyLayer()
    strokeDashedPath(ctx, glyph, color: rgb(240, 248, 255, 0.6), width: 3, dash: [16, 10])

    strokeDashedPath(ctx, CGPath(ellipseIn: CGRect(x: 318, y: 340, width: 172, height: 160), transform: nil), color: rgb(240, 248, 255, 0.4), width: 2.5, dash: [8, 8])
    strokeDashedPath(ctx, CGPath(ellipseIn: CGRect(x: 530, y: 534, width: 148, height: 156), transform: nil), color: rgb(240, 248, 255, 0.4), width: 2.5, dash: [8, 8])
    for point in [CGPoint(x: 318, y: 420), CGPoint(x: 712, y: 340), CGPoint(x: 668, y: 668), CGPoint(x: 530, y: 340)] {
        strokeTauPath(ctx, linePath([CGPoint(x: point.x - 16, y: point.y), CGPoint(x: point.x + 16, y: point.y)]), color: ink, width: 3)
        strokeTauPath(ctx, linePath([CGPoint(x: point.x, y: point.y - 16), CGPoint(x: point.x, y: point.y + 16)]), color: ink, width: 3)
    }

    let dimensionY: CGFloat = 236
    strokeTauPath(ctx, linePath([CGPoint(x: 276, y: 330), CGPoint(x: 276, y: dimensionY - 18)]), color: faintInk, width: 2.5)
    strokeTauPath(ctx, linePath([CGPoint(x: 757, y: 300), CGPoint(x: 757, y: dimensionY - 18)]), color: faintInk, width: 2.5)
    strokeTauPath(ctx, linePath([CGPoint(x: 276, y: dimensionY), CGPoint(x: 757, y: dimensionY)]), color: ink, width: 3)
    for (x, direction) in [(CGFloat(276), CGFloat(1)), (757, -1)] {
        let arrow = CGMutablePath()
        arrow.move(to: CGPoint(x: x, y: dimensionY))
        arrow.addLine(to: CGPoint(x: x + 26 * direction, y: dimensionY - 9))
        arrow.addLine(to: CGPoint(x: x + 26 * direction, y: dimensionY + 9))
        arrow.closeSubpath()
        ctx.addPath(arrow)
        ctx.setFillColor(ink)
        ctx.fillPath()
    }
    let label = CGRect(x: 476, y: dimensionY - 18, width: 80, height: 36)
    ctx.setFillColor(rgb(26, 80, 172))
    ctx.fill(label)
    for i in 0 ..< 3 {
        let x = label.minX + 12 + CGFloat(i) * 22
        strokeTauPath(ctx, linePath([CGPoint(x: x, y: label.minY + 8), CGPoint(x: x + 12, y: label.maxY - 8)]), color: ink, width: 3)
    }

    let titleBlock = CGRect(x: 600, y: 776, width: 236, height: 92)
    strokeTauPath(ctx, CGPath(rect: titleBlock, transform: nil), color: rgb(240, 248, 255, 0.85), width: 3)
    strokeTauPath(ctx, linePath([CGPoint(x: titleBlock.minX, y: titleBlock.midY), CGPoint(x: titleBlock.maxX, y: titleBlock.midY)]), color: rgb(240, 248, 255, 0.85), width: 2.5)
    strokeTauPath(ctx, linePath([CGPoint(x: titleBlock.minX + 90, y: titleBlock.minY), CGPoint(x: titleBlock.minX + 90, y: titleBlock.maxY)]), color: rgb(240, 248, 255, 0.85), width: 2.5)
    ctx.restoreGState()
}

func drawTerminalIcon(in ctx: CGContext, inset: CGFloat, cornerRadius: CGFloat) {
    beginTile(ctx, inset: inset, cornerRadius: cornerRadius, colors: [rgb(18, 24, 22), rgb(4, 6, 6)], locations: [0, 1])
    let phosphor = rgb(90, 255, 150)
    softBlob(ctx, center: CGPoint(x: 512, y: 512), radius: 440, color: rgb(40, 200, 110, 0.16))

    let chevron = linePath([CGPoint(x: 236, y: 440), CGPoint(x: 316, y: 512), CGPoint(x: 236, y: 584)])
    let glyph = scaledTauGlyphPath(0.56, center: CGPoint(x: 528, y: 520))
    let cursor = CGRect(x: 690, y: 600, width: 96, height: 30)
    for (width, alpha) in [(CGFloat(56), CGFloat(0.1)), (40, 0.2)] {
        let glow = phosphor.copy(alpha: alpha)!
        strokeTauPath(ctx, chevron, color: glow, width: width + 4)
        strokeTauPath(ctx, glyph, color: glow, width: width + 10)
        ctx.setFillColor(glow)
        ctx.fill(cursor.insetBy(dx: -width / 3, dy: -width / 3))
    }
    strokeTauPath(ctx, chevron, color: phosphor, width: 34)
    strokeTauPath(ctx, glyph, color: phosphor, width: 46)
    ctx.setFillColor(phosphor)
    ctx.fill(cursor)

    ctx.setFillColor(rgb(0, 0, 0, 0.28))
    for y in stride(from: CGFloat(0), to: 1024, by: 10) {
        ctx.fill(CGRect(x: 0, y: y, width: 1024, height: 4))
    }
    ctx.drawRadialGradient(gradient([rgb(0, 0, 0, 0), rgb(0, 0, 0, 0.6)], [0, 1]), startCenter: CGPoint(x: 512, y: 512), startRadius: 260, endCenter: CGPoint(x: 512, y: 512), endRadius: 600, options: [.drawsAfterEndLocation])
    let glare = CGRect(x: inset + 40, y: inset + 30, width: 1024 - inset * 2 - 80, height: 200)
    ctx.addEllipse(in: glare)
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(255, 255, 255, 0.12), rgb(255, 255, 255, 0)], [0, 1]), start: CGPoint(x: 0, y: glare.minY), end: CGPoint(x: 0, y: glare.maxY), options: [])
    ctx.restoreGState()
}
