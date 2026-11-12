import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramTheme
import TauSettings
import Postbox
import LocalAuthentication

private let setupWidth: CGFloat = 340
private let setupInset: CGFloat = 24

private func tauTouchIdAvailable() -> Bool {
    var error: NSError?
    return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
}

private final class TauChatLockSetupView: View {
    let titleView = TextView()
    let textView = TextView()
    let errorView = TextView()
    let field = NSSecureTextField()
    let repeatField = NSSecureTextField()
    //TODOLANG
    let touchIdCheckbox = NSButton(checkboxWithTitle: "Unlock this chat with Touch ID", target: nil, action: nil)
    let saveButton = TextButton()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = theme.colors.background
        for view in [titleView, textView, errorView] {
            view.userInteractionEnabled = false
            view.isSelectable = false
            addSubview(view)
        }
        //TODOLANG
        field.placeholderString = "New passcode"
        //TODOLANG
        repeatField.placeholderString = "Repeat passcode"
        for field in [field, repeatField] {
            field.alignment = .center
            field.font = .normal(.title)
            field.focusRingType = .none
            field.bezelStyle = .roundedBezel
            addSubview(field)
        }
        touchIdCheckbox.font = .normal(.text)
        if #available(macOS 10.14, *) {
            touchIdCheckbox.contentTintColor = theme.colors.accent
        }
        touchIdCheckbox.attributedTitle = .initialize(string: touchIdCheckbox.title, color: theme.colors.text, font: .normal(.text))
        addSubview(touchIdCheckbox)
        saveButton.set(font: .medium(.text), for: .Normal)
        saveButton.set(color: .white, for: .Normal)
        saveButton.set(background: theme.colors.accent, for: .Normal)
        saveButton.layer?.cornerRadius = 10
        saveButton.autohighlight = false
        saveButton.autoSizeToFit = false
        saveButton.scaleOnClick = true
        //TODOLANG
        saveButton.set(text: "Save", for: .Normal)
        addSubview(saveButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        return true
    }

    func showError(_ text: String) {
        let layout = TextViewLayout(.initialize(string: text, color: theme.colors.redUI, font: .normal(.text)), alignment: .center)
        layout.measure(width: setupWidth - setupInset * 2)
        errorView.update(layout)
        needsLayout = true
        field.shake(beep: true)
    }

    override func layout() {
        super.layout()
        let width = frame.width - setupInset * 2
        titleView.setFrameOrigin(NSMakePoint(setupInset, setupInset))
        textView.setFrameOrigin(NSMakePoint(setupInset, titleView.frame.maxY + 8))
        var y = textView.frame.maxY + 16
        if !field.isHidden {
            field.frame = NSMakeRect(setupInset, y, width, 30)
            y = field.frame.maxY + 10
        }
        if !repeatField.isHidden {
            repeatField.frame = NSMakeRect(setupInset, y, width, 30)
            y = repeatField.frame.maxY + 10
        }
        if !touchIdCheckbox.isHidden {
            touchIdCheckbox.sizeToFit()
            touchIdCheckbox.setFrameOrigin(NSMakePoint(setupInset, y + 2))
            y = touchIdCheckbox.frame.maxY + 10
        }
        errorView.setFrameOrigin(NSMakePoint(floor((frame.width - errorView.frame.width) / 2), y))
        saveButton.frame = NSMakeRect(setupInset, frame.height - setupInset - 40, width, 40)
    }
}

enum TauChatLockSetupMode {
    case setup
    case verify
    case lockChat(PeerId)
}

final class TauChatLockSetupController: ModalViewController {
    private let mode: TauChatLockSetupMode
    private let needsNewPasscode: Bool
    private let showsTouchId: Bool
    private let completion: () -> Void
    private let titleLayout: TextViewLayout
    private let textLayout: TextViewLayout

    init(mode: TauChatLockSetupMode, completion: @escaping () -> Void) {
        self.mode = mode
        self.completion = completion
        let title: String
        let text: String
        switch mode {
        case .setup:
            self.needsNewPasscode = true
            self.showsTouchId = false
            //TODOLANG
            title = "Chat Lock Passcode"
            //TODOLANG
            text = "One passcode opens every locked chat. Taugram can't recover a forgotten passcode."
        case .verify:
            self.needsNewPasscode = false
            self.showsTouchId = false
            //TODOLANG
            title = "Enter Chat Lock Passcode"
            //TODOLANG
            text = "Enter your current passcode to continue."
        case .lockChat:
            self.needsNewPasscode = !TauChatLock.shared.hasPasscode
            self.showsTouchId = tauTouchIdAvailable()
            //TODOLANG
            title = "Lock Chat"
            //TODOLANG
            text = self.needsNewPasscode ? "Set a passcode first. One passcode opens every locked chat; Taugram can't recover a forgotten one." : "The chat will ask for your chat lock passcode each time it opens."
        }
        self.titleLayout = TextViewLayout(.initialize(string: title, color: theme.colors.text, font: .medium(.header)))
        self.textLayout = TextViewLayout(.initialize(string: text, color: theme.colors.grayText, font: .normal(.text)))
        self.titleLayout.measure(width: setupWidth - setupInset * 2)
        self.textLayout.measure(width: setupWidth - setupInset * 2)
        var fields: CGFloat = 0
        switch mode {
        case .verify:
            fields = 30 + 10
        default:
            if self.needsNewPasscode {
                fields = 30 + 10 + 30 + 10
            }
        }
        if self.showsTouchId {
            fields += 22 + 10
        }
        let height = setupInset + titleLayout.layoutSize.height + 8 + textLayout.layoutSize.height + 16 + fields + 24 + 40 + setupInset
        super.init(frame: NSMakeRect(0, 0, setupWidth, height))
        bar = .init(height: 0)
    }

    override func viewClass() -> AnyClass {
        return TauChatLockSetupView.self
    }

    private var genericView: TauChatLockSetupView {
        return self.view as! TauChatLockSetupView
    }

    private var isVerify: Bool {
        if case .verify = mode {
            return true
        }
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.field.isHidden = !needsNewPasscode && !isVerify
        genericView.repeatField.isHidden = !needsNewPasscode
        genericView.touchIdCheckbox.isHidden = !showsTouchId
        switch mode {
        case .verify:
            //TODOLANG
            genericView.field.placeholderString = "Passcode"
            //TODOLANG
            genericView.saveButton.set(text: "Continue", for: .Normal)
        case .lockChat:
            //TODOLANG
            genericView.saveButton.set(text: "Lock", for: .Normal)
        case .setup:
            break
        }
        genericView.titleView.update(titleLayout)
        genericView.textView.update(textLayout)
        genericView.saveButton.set(handler: { [weak self] _ in
            self?.save()
        }, for: .Click)
        readyOnce()
    }

    override func firstResponder() -> NSResponder? {
        if genericView.field.isHidden {
            return genericView.saveButton
        }
        return genericView.field
    }

    override func returnKeyAction() -> KeyHandlerResult {
        if needsNewPasscode, window?.firstResponder == genericView.field.currentEditor() {
            window?.makeFirstResponder(genericView.repeatField)
        } else {
            save()
        }
        return .invoked
    }

    private func verify() {
        let code = genericView.field.stringValue
        guard !code.isEmpty else {
            return
        }
        genericView.saveButton.isEnabled = false
        Queue.concurrentDefaultQueue().async {
            let result = TauChatLock.shared.verify(code)
            Queue.mainQueue().async { [weak self] in
                guard let self else {
                    return
                }
                self.genericView.saveButton.isEnabled = true
                switch result {
                case .success:
                    self.close()
                    self.completion()
                case .invalid:
                    self.genericView.field.stringValue = ""
                    //TODOLANG
                    self.genericView.showError("Wrong passcode")
                case let .cooldown(seconds):
                    self.genericView.field.stringValue = ""
                    //TODOLANG
                    self.genericView.showError("Too many attempts. Try again in \(seconds) s")
                }
            }
        }
    }

    private func finish() {
        if case let .lockChat(peerId) = mode {
            TauChatLock.shared.setLocked(peerId, locked: true, touchId: showsTouchId && genericView.touchIdCheckbox.state == .on)
        }
        close()
        completion()
    }

    private func save() {
        if isVerify {
            verify()
            return
        }
        guard needsNewPasscode else {
            finish()
            return
        }
        let code = genericView.field.stringValue
        guard code.count >= 4 else {
            //TODOLANG
            genericView.showError("Use at least 4 characters")
            return
        }
        guard code == genericView.repeatField.stringValue else {
            genericView.repeatField.stringValue = ""
            //TODOLANG
            genericView.showError("Passcodes don't match")
            return
        }
        genericView.saveButton.isEnabled = false
        Queue.concurrentDefaultQueue().async {
            let saved = TauChatLock.shared.setPasscode(code)
            Queue.mainQueue().async { [weak self] in
                guard let self else {
                    return
                }
                self.genericView.saveButton.isEnabled = true
                if saved {
                    self.finish()
                } else {
                    //TODOLANG
                    self.genericView.showError("Couldn't save the passcode to Keychain")
                }
            }
        }
    }
}

public func showTauChatLockSetup(for window: Window, completion: @escaping () -> Void = {}) {
    showModal(with: TauChatLockSetupController(mode: .setup, completion: completion), for: window)
}

func showTauChatLockVerify(for window: Window, completion: @escaping () -> Void) {
    showModal(with: TauChatLockSetupController(mode: .verify, completion: completion), for: window)
}

private var tauChatLockObservers: [NSObjectProtocol] = []

public func installTauChatLock(window: Window) {
    TauChatLock.shared.presentLockChat = { [weak window] peerId in
        guard let window else {
            return
        }
        showModal(with: TauChatLockSetupController(mode: .lockChat(peerId), completion: {}), for: window)
    }
    guard tauChatLockObservers.isEmpty else {
        return
    }
    let relock: (Notification) -> Void = { _ in
        TauChatLock.shared.relockAll()
    }
    let workspace = NSWorkspace.shared.notificationCenter
    tauChatLockObservers.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main, using: relock))
    tauChatLockObservers.append(workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main, using: relock))
    tauChatLockObservers.append(workspace.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main, using: relock))
    tauChatLockObservers.append(DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main, using: relock))
}
