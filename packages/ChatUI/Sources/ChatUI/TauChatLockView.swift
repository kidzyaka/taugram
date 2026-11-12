import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import LocalAuthentication
import TelegramTheme
import TauSettings

final class TauChatLockView: View {
    private let peerId: PeerId
    private let iconView = ImageView()
    private let titleView = TextView()
    private let errorView = TextView()
    private let field = NSSecureTextField()
    private let unlockButton = TextButton()
    private let biometryButton = TextButton()
    private var verifying = false
    var onUnlock: (() -> Void)?

    init(frame frameRect: NSRect, peerId: PeerId) {
        self.peerId = peerId
        super.init(frame: frameRect)
        backgroundColor = theme.colors.background
        autoresizingMask = [.width, .height]

        if #available(macOS 11.0, *), let image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 40, weight: .regular)
            iconView.image = (image.withSymbolConfiguration(config) ?? image).precomposed(theme.colors.grayIcon)
            iconView.sizeToFit()
        }
        addSubview(iconView)

        //TODOLANG
        let title = TextViewLayout(.initialize(string: "This chat is locked", color: theme.colors.text, font: .medium(.header)), alignment: .center)
        title.measure(width: 300)
        titleView.update(title)
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        addSubview(titleView)

        errorView.userInteractionEnabled = false
        errorView.isSelectable = false
        addSubview(errorView)

        //TODOLANG
        field.placeholderString = "Passcode"
        field.alignment = .center
        field.font = .normal(.title)
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel
        field.target = self
        field.action = #selector(submitAction)
        addSubview(field)

        unlockButton.set(font: .medium(.text), for: .Normal)
        unlockButton.set(color: .white, for: .Normal)
        unlockButton.set(background: theme.colors.accent, for: .Normal)
        unlockButton.layer?.cornerRadius = 10
        unlockButton.autohighlight = false
        unlockButton.autoSizeToFit = false
        unlockButton.scaleOnClick = true
        //TODOLANG
        unlockButton.set(text: "Unlock", for: .Normal)
        unlockButton.set(handler: { [weak self] _ in
            self?.submit()
        }, for: .Click)
        addSubview(unlockButton)

        biometryButton.set(font: .normal(.text), for: .Normal)
        biometryButton.set(color: theme.colors.accent, for: .Normal)
        //TODOLANG
        biometryButton.set(text: "Use Touch ID", for: .Normal)
        biometryButton.set(handler: { [weak self] _ in
            self?.authenticateWithBiometrics()
        }, for: .Click)
        biometryButton.isHidden = !TauChatLock.shared.usesTouchId(peerId)
        addSubview(biometryButton)
    }

    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var passcodeResponder: NSResponder {
        return field
    }

    override func layout() {
        super.layout()
        let fieldWidth: CGFloat = 220
        var y = floor(frame.height / 2) - 120
        iconView.setFrameOrigin(NSMakePoint(floor((frame.width - iconView.frame.width) / 2), y))
        y = iconView.frame.maxY + 16
        titleView.setFrameOrigin(NSMakePoint(floor((frame.width - titleView.frame.width) / 2), y))
        y = titleView.frame.maxY + 20
        field.frame = NSMakeRect(floor((frame.width - fieldWidth) / 2), y, fieldWidth, 30)
        y = field.frame.maxY + 8
        errorView.setFrameOrigin(NSMakePoint(floor((frame.width - errorView.frame.width) / 2), y))
        y += 22
        unlockButton.frame = NSMakeRect(floor((frame.width - fieldWidth) / 2), y, fieldWidth, 36)
        y = unlockButton.frame.maxY + 12
        biometryButton.sizeToFit()
        biometryButton.setFrameOrigin(NSMakePoint(floor((frame.width - biometryButton.frame.width) / 2), y))
    }

    override var isFlipped: Bool {
        return true
    }

    func focus() {
        window?.makeFirstResponder(field)
        if TauChatLock.shared.usesTouchId(peerId) {
            authenticateWithBiometrics()
        }
    }

    private func showError(_ text: String) {
        let layout = TextViewLayout(.initialize(string: text, color: theme.colors.redUI, font: .normal(.text)), alignment: .center)
        layout.measure(width: 300)
        errorView.update(layout)
        needsLayout = true
        field.shake(beep: true)
    }

    @objc private func submitAction() {
        submit()
    }

    func submit() {
        guard !verifying else {
            return
        }
        let code = field.stringValue
        guard !code.isEmpty else {
            return
        }
        verifying = true
        unlockButton.isEnabled = false
        Queue.concurrentDefaultQueue().async {
            let result = TauChatLock.shared.verify(code)
            Queue.mainQueue().async { [weak self] in
                guard let self else {
                    return
                }
                self.verifying = false
                self.unlockButton.isEnabled = true
                switch result {
                case .success:
                    self.completeUnlock()
                case .invalid:
                    self.field.stringValue = ""
                    //TODOLANG
                    self.showError("Wrong passcode")
                case let .cooldown(seconds):
                    self.field.stringValue = ""
                    //TODOLANG
                    self.showError("Too many attempts. Try again in \(seconds) s")
                }
            }
        }
    }

    private func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return
        }
        //TODOLANG
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "unlock this chat") { [weak self] success, _ in
            Queue.mainQueue().async {
                if success {
                    self?.completeUnlock()
                }
            }
        }
    }

    private func completeUnlock() {
        TauChatLock.shared.markUnlocked(peerId)
        onUnlock?()
    }
}

func installTauChatLock(on view: NSView, peerId: PeerId?, onUnlock: @escaping () -> Void) -> TauChatLockView? {
    guard let peerId, TauChatLock.shared.needsUnlock(peerId) else {
        return nil
    }
    let lockView = TauChatLockView(frame: view.bounds, peerId: peerId)
    lockView.onUnlock = { [weak lockView] in
        lockView?.removeFromSuperview()
        onUnlock()
    }
    view.addSubview(lockView)
    return lockView
}
