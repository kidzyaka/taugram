import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramTheme
import TauSettings

private func tauGhostIcon(color: NSColor, filled: Bool) -> CGImage? {
    return generateImage(NSMakeSize(24, 24), rotatedContext: { size, ctx in
        ctx.clear(CGRect(origin: .zero, size: size))
        let width: CGFloat = 16
        let left = (size.width - width) / 2
        let right = left + width
        let radius = width / 2
        let top: CGFloat = 3
        let bottom: CGFloat = 20.5
        let wave = width / 3
        let body = CGMutablePath()
        body.move(to: CGPoint(x: left, y: bottom))
        body.addLine(to: CGPoint(x: left, y: top + radius))
        body.addArc(center: CGPoint(x: left + radius, y: top + radius), radius: radius, startAngle: .pi, endAngle: 0, clockwise: false)
        body.addLine(to: CGPoint(x: right, y: bottom))
        for i in 0 ..< 3 {
            let x = right - CGFloat(i) * wave
            body.addQuadCurve(to: CGPoint(x: x - wave, y: bottom), control: CGPoint(x: x - wave / 2, y: bottom + (i % 2 == 0 ? -3 : 3)))
        }
        body.closeSubpath()

        ctx.addPath(body)
        if filled {
            ctx.setFillColor(color.cgColor)
            ctx.fillPath()
            ctx.setBlendMode(.clear)
        } else {
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(1.66)
            ctx.setLineJoin(.round)
            ctx.strokePath()
            ctx.setFillColor(color.cgColor)
        }
        let eyeY: CGFloat = 9
        ctx.fillEllipse(in: CGRect(x: size.width / 2 - 4.4, y: eyeY, width: 2.6, height: 3.2))
        ctx.fillEllipse(in: CGRect(x: size.width / 2 + 1.8, y: eyeY, width: 2.6, height: 3.2))
        ctx.setBlendMode(.normal)
    })
}

final class TauGhostTitleButton: ImageButton {
    private let disposable = MetaDisposable()
    private var allowed = false
    private var isOn = false
    var shouldShow = false {
        didSet {
            if oldValue != self.shouldShow {
                self.apply()
            }
        }
    }
    var onVisibilityChange: (() -> Void)?

    required init(frame frameRect: NSRect) {
        super.init(frame: NSMakeRect(0, 0, 30, 30))
        self.layer?.cornerRadius = .cornerRadius
        self.animates = false
        self.autohighlight = false
        self.scaleOnClick = true
        self.set(handler: { _ in
            TauSettings.shared.toggleGhostMode()
        }, for: .Click)
        self.disposable.set((TauSettings.shared.signal |> map { ($0.dangerousFeaturesAllowed, $0.ghost.isFullyOn) } |> distinctUntilChanged(isEqual: { $0 == $1 }) |> deliverOnMainQueue).start(next: { [weak self] allowed, isOn in
            self?.allowed = allowed
            self?.isOn = isOn
            self?.apply()
        }))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable.dispose()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if (self.layer?.opacity ?? 1) < 0.5 {
            return nil
        }
        return super.hitTest(point)
    }

    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.apply()
    }

    private func apply() {
        let hidden = !(self.allowed && self.shouldShow)
        let changed = self.isHidden != hidden
        self.isHidden = hidden
        if let image = tauGhostIcon(color: theme.colors.accent, filled: self.isOn) {
            self.set(image: image, for: .Normal)
            self.set(image: image, for: .Hover)
        }
        //TODOLANG
        self.toolTip = self.isOn ? "Ghost Mode: on" : "Ghost Mode: off"
        if changed {
            self.onVisibilityChange?()
        }
    }
}
