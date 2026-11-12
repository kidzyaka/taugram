import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramTheme
import TauSettings

private let consentWidth: CGFloat = 400
private let consentInset: CGFloat = 24
private let buttonHeight: CGFloat = 40
private let enableDelay = 10

private final class TauConsentView: View {
    let titleView = TextView()
    let textView = TextView()
    let disableButton = TextButton()
    let enableButton = TextButton()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = theme.colors.background
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        addSubview(titleView)
        addSubview(textView)
        addSubview(disableButton)
        addSubview(enableButton)

        for button in [disableButton, enableButton] {
            button.set(font: .medium(.text), for: .Normal)
            button.set(color: .white, for: .Normal)
            button.layer?.cornerRadius = 10
            button.autohighlight = false
            button.autoSizeToFit = false
            button.scaleOnClick = true
        }
        disableButton.set(background: theme.colors.accent, for: .Normal)
        enableButton.set(background: theme.colors.redUI, for: .Normal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(title: TextViewLayout, text: TextViewLayout) {
        titleView.update(title)
        textView.update(text)
        needsLayout = true
    }

    func setEnableTitle(_ title: String, enabled: Bool) {
        enableButton.set(text: title, for: .Normal)
        enableButton.isEnabled = enabled
        enableButton.alphaValue = enabled ? 1 : 0.5
    }

    override func layout() {
        super.layout()
        titleView.setFrameOrigin(NSMakePoint(consentInset, consentInset))
        textView.setFrameOrigin(NSMakePoint(consentInset, titleView.frame.maxY + 12))
        let buttonWidth = (frame.width - consentInset * 2 - 12) / 2
        let buttonY = frame.height - consentInset - buttonHeight
        disableButton.frame = NSMakeRect(consentInset, buttonY, buttonWidth, buttonHeight)
        enableButton.frame = NSMakeRect(disableButton.frame.maxX + 12, buttonY, buttonWidth, buttonHeight)
    }
}

public final class TauConsentController: ModalViewController {
    private let completion: (TauDangerousConsent.Decision) -> Void
    private let titleLayout: TextViewLayout
    private let textLayout: TextViewLayout
    private var remaining = enableDelay
    private var timer: SwiftSignalKit.Timer?
    private var decided = false

    public init(completion: @escaping (TauDangerousConsent.Decision) -> Void = { _ in }) {
        self.completion = completion
        //TODOLANG
        let title = "Dangerous Features"
        //TODOLANG
        let text = "Taugram can hide your read receipts, online status and typing, keep messages that others delete, save view-once media and copy content from chats that forbid forwarding.\n\nThese features break the Telegram Terms of Service. Telegram may restrict or ban an account that uses them. Turn them on only if you accept that risk.\n\nYou can change your mind later in Settings → Taugram."
        self.titleLayout = TextViewLayout(.initialize(string: title, color: theme.colors.text, font: .medium(.header)))
        self.textLayout = TextViewLayout(.initialize(string: text, color: theme.colors.text, font: .normal(.text)))
        self.titleLayout.measure(width: consentWidth - consentInset * 2)
        self.textLayout.measure(width: consentWidth - consentInset * 2)
        let height = consentInset + titleLayout.layoutSize.height + 12 + textLayout.layoutSize.height + 24 + buttonHeight + consentInset
        super.init(frame: NSMakeRect(0, 0, consentWidth, height))
        bar = .init(height: 0)
    }

    deinit {
        timer?.invalidate()
    }

    public override func viewClass() -> AnyClass {
        return TauConsentView.self
    }

    private var genericView: TauConsentView {
        return self.view as! TauConsentView
    }

    public override var closable: Bool {
        return false
    }

    public override func escapeKeyAction() -> KeyHandlerResult {
        return .invoked
    }

    public override func returnKeyAction() -> KeyHandlerResult {
        decide(.disabled)
        return .invoked
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        genericView.update(title: titleLayout, text: textLayout)
        //TODOLANG
        genericView.disableButton.set(text: "Disable", for: .Normal)
        genericView.disableButton.set(handler: { [weak self] _ in
            self?.decide(.disabled)
        }, for: .Click)
        genericView.enableButton.set(handler: { [weak self] _ in
            guard let self, self.remaining == 0 else {
                return
            }
            self.decide(.enabled)
        }, for: .Click)
        updateEnableButton()
        let timer = SwiftSignalKit.Timer(timeout: 1, repeat: true, completion: { [weak self] in
            self?.tick()
        }, queue: .mainQueue())
        self.timer = timer
        timer.start()
        readyOnce()
    }

    private func tick() {
        remaining = max(0, remaining - 1)
        if remaining == 0 {
            timer?.invalidate()
            timer = nil
        }
        updateEnableButton()
    }

    private func updateEnableButton() {
        //TODOLANG
        let title = remaining > 0 ? "Enable (\(remaining))" : "Enable"
        genericView.setEnableTitle(title, enabled: remaining == 0)
    }

    private func decide(_ decision: TauDangerousConsent.Decision) {
        guard !decided else {
            return
        }
        decided = true
        timer?.invalidate()
        timer = nil
        TauSettings.shared.recordDangerousConsent(decision)
        close()
        completion(decision)
    }
}

public func showTauConsent(for window: Window, completion: @escaping (TauDangerousConsent.Decision) -> Void = { _ in }) {
    if findModal(TauConsentController.self) != nil {
        return
    }
    showModal(with: TauConsentController(completion: completion), for: window)
}

public func showTauConsentIfNeeded(for window: Window) {
    if TauSettings.shared.current.needsDangerousConsent {
        showTauConsent(for: window)
    }
}
