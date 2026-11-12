import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramTheme
import TauSettings

private let setupWidth: CGFloat = 340
private let setupInset: CGFloat = 24

private final class TauChatLockSetupView: View {
    let titleView = TextView()
    let textView = TextView()
    let errorView = TextView()
    let field = NSSecureTextField()
    let repeatField = NSSecureTextField()
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
        field.frame = NSMakeRect(setupInset, textView.frame.maxY + 16, width, 30)
        repeatField.frame = NSMakeRect(setupInset, field.frame.maxY + 10, width, 30)
        errorView.setFrameOrigin(NSMakePoint(floor((frame.width - errorView.frame.width) / 2), repeatField.frame.maxY + 8))
        saveButton.frame = NSMakeRect(setupInset, frame.height - setupInset - 40, width, 40)
    }
}

final class TauChatLockSetupController: ModalViewController {
    private let verifyOnly: Bool
    private let completion: () -> Void
    private let titleLayout: TextViewLayout
    private let textLayout: TextViewLayout

    init(verifyOnly: Bool, completion: @escaping () -> Void) {
        self.verifyOnly = verifyOnly
        self.completion = completion
        //TODOLANG
        let title = verifyOnly ? "Enter Chat Lock Passcode" : "Chat Lock Passcode"
        //TODOLANG
        let text = verifyOnly ? "Enter your current passcode to continue." : "One passcode opens every locked chat. Taugram can't recover a forgotten passcode."
        self.titleLayout = TextViewLayout(.initialize(string: title, color: theme.colors.text, font: .medium(.header)))
        self.textLayout = TextViewLayout(.initialize(string: text, color: theme.colors.grayText, font: .normal(.text)))
        self.titleLayout.measure(width: setupWidth - setupInset * 2)
        self.textLayout.measure(width: setupWidth - setupInset * 2)
        let fields: CGFloat = verifyOnly ? 30 : 30 + 10 + 30
        let height = setupInset + titleLayout.layoutSize.height + 8 + textLayout.layoutSize.height + 16 + fields + 34 + 40 + setupInset
        super.init(frame: NSMakeRect(0, 0, setupWidth, height))
        bar = .init(height: 0)
    }

    override func viewClass() -> AnyClass {
        return TauChatLockSetupView.self
    }

    private var genericView: TauChatLockSetupView {
        return self.view as! TauChatLockSetupView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.repeatField.isHidden = verifyOnly
        if verifyOnly {
            //TODOLANG
            genericView.field.placeholderString = "Passcode"
            //TODOLANG
            genericView.saveButton.set(text: "Continue", for: .Normal)
        }
        genericView.titleView.update(titleLayout)
        genericView.textView.update(textLayout)
        genericView.saveButton.set(handler: { [weak self] _ in
            self?.save()
        }, for: .Click)
        readyOnce()
    }

    override func firstResponder() -> NSResponder? {
        return genericView.field
    }

    override func returnKeyAction() -> KeyHandlerResult {
        if !verifyOnly, window?.firstResponder == genericView.field.currentEditor() {
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

    private func save() {
        if verifyOnly {
            verify()
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
                    self.close()
                    self.completion()
                } else {
                    //TODOLANG
                    self.genericView.showError("Couldn't save the passcode to Keychain")
                }
            }
        }
    }
}

public func showTauChatLockSetup(for window: Window, completion: @escaping () -> Void = {}) {
    showModal(with: TauChatLockSetupController(verifyOnly: false, completion: completion), for: window)
}

func showTauChatLockVerify(for window: Window, completion: @escaping () -> Void) {
    showModal(with: TauChatLockSetupController(verifyOnly: true, completion: completion), for: window)
}

private var tauChatLockObservers: [NSObjectProtocol] = []

public func installTauChatLock(window: Window) {
    TauChatLock.shared.setupPasscode = { [weak window] completion in
        guard let window else {
            return
        }
        showTauChatLockSetup(for: window, completion: completion)
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
