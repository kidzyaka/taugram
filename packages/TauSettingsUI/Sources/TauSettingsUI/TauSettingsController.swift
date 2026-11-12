import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import TelegramContext
import TelegramTheme
import TelegramUtils
import InputDataUI
import InAppSettings
import GeneralRows
import TauSettings

private final class Arguments {
    let toggleDangerousFeatures: () -> Void
    let reviewConsent: () -> Void
    let selectAppIcon: (TauAppIcon) -> Void
    let toggleMessageSeconds: () -> Void
    let toggleHideStories: () -> Void
    let togglePeerId: () -> Void
    let toggleOLED: () -> Void
    let toggleGhost: (WritableKeyPath<TauGhostSettings, Bool>?) -> Void
    let toggleValue: (WritableKeyPath<TauSettingsValues, Bool>) -> Void
    let chatLock: (TauChatLockAction) -> Void
    init(toggleDangerousFeatures: @escaping () -> Void, reviewConsent: @escaping () -> Void, selectAppIcon: @escaping (TauAppIcon) -> Void, toggleMessageSeconds: @escaping () -> Void, toggleHideStories: @escaping () -> Void, togglePeerId: @escaping () -> Void, toggleOLED: @escaping () -> Void, toggleGhost: @escaping (WritableKeyPath<TauGhostSettings, Bool>?) -> Void, toggleValue: @escaping (WritableKeyPath<TauSettingsValues, Bool>) -> Void, chatLock: @escaping (TauChatLockAction) -> Void) {
        self.toggleDangerousFeatures = toggleDangerousFeatures
        self.reviewConsent = reviewConsent
        self.selectAppIcon = selectAppIcon
        self.toggleMessageSeconds = toggleMessageSeconds
        self.toggleHideStories = toggleHideStories
        self.togglePeerId = togglePeerId
        self.toggleOLED = toggleOLED
        self.toggleGhost = toggleGhost
        self.toggleValue = toggleValue
        self.chatLock = chatLock
    }
}

enum TauChatLockAction {
    case set
    case change
    case remove
    case toggleBiometrics
}

private struct State: Equatable {
    var values: TauSettingsValues
    var chatLockHasPasscode: Bool
    var coreDangerousFeaturesAllowed: Bool
    var canViewPeerId: Bool
}

private let tauAppIconThumbs: [TauAppIcon: CGImage] = {
    var result: [TauAppIcon: CGImage] = [:]
    for icon in TauAppIcon.allCases {
        result[icon] = generateTauAppIconThumb(icon)
    }
    return result
}()

private let _id_dangerous_enabled = InputDataIdentifier("_id_dangerous_enabled")
private let _id_dangerous_review = InputDataIdentifier("_id_dangerous_review")
private let _id_debug_core = InputDataIdentifier("_id_debug_core")
private let _id_message_seconds = InputDataIdentifier("_id_message_seconds")
private let _id_hide_stories = InputDataIdentifier("_id_hide_stories")
private let _id_peer_id = InputDataIdentifier("_id_peer_id")
private let _id_oled = InputDataIdentifier("_id_oled")
private let _id_chat_lock_set = InputDataIdentifier("_id_chat_lock_set")
private let _id_chat_lock_change = InputDataIdentifier("_id_chat_lock_change")
private let _id_chat_lock_biometrics = InputDataIdentifier("_id_chat_lock_biometrics")
private let _id_chat_lock_remove = InputDataIdentifier("_id_chat_lock_remove")
private let _id_ghost_all = InputDataIdentifier("_id_ghost_all")
private let _id_keep_deleted = InputDataIdentifier("_id_keep_deleted")
private let _id_keep_edits = InputDataIdentifier("_id_keep_edits")
private let _id_bypass_protection = InputDataIdentifier("_id_bypass_protection")
private let _id_view_once = InputDataIdentifier("_id_view_once")
private let _id_show_self_destructing = InputDataIdentifier("_id_show_self_destructing")
private let _id_view_once_secret = InputDataIdentifier("_id_view_once_secret")
private func _id_ghost(_ key: String) -> InputDataIdentifier {
    return InputDataIdentifier("_id_ghost_\(key)")
}

private let ghostOptions: [(key: String, title: String, keyPath: WritableKeyPath<TauGhostSettings, Bool>)] = [
    //TODOLANG
    ("read", "Don't Send Read Receipts", \.hideReadReceipts),
    //TODOLANG
    ("online", "Don't Show Online", \.hideOnlineStatus),
    //TODOLANG
    ("typing", "Don't Send Typing", \.hideTyping),
    //TODOLANG
    ("stories", "Don't Mark Stories Seen", \.hideStoryViews),
    //TODOLANG
    ("consume", "Don't Mark Voice and Mentions Seen", \.hideContentConsumption),
    //TODOLANG
    ("views", "Don't Count Channel Views", \.hideChannelViews),
]

func tauGhostModeIsOn(_ ghost: TauGhostSettings) -> Bool {
    return ghostOptions.allSatisfy { ghost[keyPath: $0.keyPath] }
}
private func _id_app_icon(_ icon: TauAppIcon) -> InputDataIdentifier {
    return InputDataIdentifier("_id_app_icon_\(icon.rawValue)")
}

private var appVersion: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? ""
    let build = info?["CFBundleVersion"] as? String ?? ""
    return "\(version) (\(build))"
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []

    var sectionId: Int32 = 0
    var index: Int32 = 0

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Taugram \(appVersion) is an unofficial client based on Telegram for macOS."), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("APPEARANCE"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    //TODOLANG
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_oled, data: .init(name: "OLED Mode", color: theme.colors.text, type: .switchable(state.values.oledMode), viewType: .singleItem, action: arguments.toggleOLED)))
    index += 1

    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Pure black theme without blur or translucency. Theme and color settings stay locked while it is on; turning it off brings your previous theme back."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("APP ICON"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    let selectedIcon = state.values.appIcon.flatMap(TauAppIcon.init(rawValue:)) ?? .classic
    for icon in TauAppIcon.allCases {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_app_icon(icon), data: .init(name: icon.title, color: theme.colors.text, icon: tauAppIconThumbs[icon], type: .selectable(icon == selectedIcon), viewType: bestGeneralViewType(TauAppIcon.allCases, for: icon), action: {
            arguments.selectAppIcon(icon)
        })))
        index += 1
    }

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("CHATS"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    //TODOLANG
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_message_seconds, data: .init(name: "Seconds in Message Time", color: theme.colors.text, type: .switchable(state.values.showMessageSeconds), viewType: .firstItem, action: arguments.toggleMessageSeconds)))
    index += 1

    //TODOLANG
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_hide_stories, data: .init(name: "Hide Stories in Chat List", color: theme.colors.text, type: .switchable(state.values.hideStoriesInChatList), viewType: .lastItem, action: arguments.toggleHideStories)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("PROFILE"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    //TODOLANG
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_peer_id, data: .init(name: "Show ID and Data Center", color: theme.colors.text, type: .switchable(state.canViewPeerId), viewType: .singleItem, action: arguments.togglePeerId)))
    index += 1

    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Profiles show the ID in Bot API format and the data center of the profile photo. Click the ID to copy it."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("CHAT LOCK"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    if state.chatLockHasPasscode {
        //TODOLANG
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_chat_lock_change, data: .init(name: "Change Passcode", color: theme.colors.text, type: .next, viewType: .firstItem, action: {
            arguments.chatLock(.change)
        })))
        index += 1
        //TODOLANG
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_chat_lock_biometrics, data: .init(name: "Unlock with Touch ID", color: theme.colors.text, type: .switchable(state.values.chatLockBiometrics), viewType: .innerItem, action: {
            arguments.chatLock(.toggleBiometrics)
        })))
        index += 1
        //TODOLANG
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_chat_lock_remove, data: .init(name: "Remove Passcode", color: theme.colors.redUI, type: .none, viewType: .lastItem, action: {
            arguments.chatLock(.remove)
        })))
        index += 1
        //TODOLANG
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Locked chats: \(state.values.lockedChats.count). Lock a chat from its menu in the chat list. A locked chat asks for the passcode each time it opens, and its previews and notifications stay hidden. This protects the interface only: the chat database is encrypted on disk only with the app passcode."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    } else {
        //TODOLANG
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_chat_lock_set, data: .init(name: "Set Passcode", color: theme.colors.accent, type: .none, viewType: .singleItem, action: {
            arguments.chatLock(.set)
        })))
        index += 1
        //TODOLANG
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Hide chats behind a passcode. After you set one, choose Lock Chat in a chat's menu in the chat list."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    }

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("DANGEROUS FEATURES"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    if state.values.hasValidDangerousConsent {
        //TODOLANG
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_dangerous_enabled, data: .init(name: "Dangerous Features", color: theme.colors.text, type: .switchable(state.values.dangerousFeaturesEnabled), viewType: .firstItem, action: arguments.toggleDangerousFeatures)))
        index += 1
        //TODOLANG
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_dangerous_review, data: .init(name: "Review Decision", color: theme.colors.accent, type: .none, viewType: .lastItem, action: arguments.reviewConsent)))
        index += 1
        //TODOLANG
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Turning this off stops every dangerous feature at once. Each feature still has its own switch."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1

        if state.values.dangerousFeaturesEnabled {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1

            //TODOLANG
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain("GHOST MODE"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1

            //TODOLANG
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_ghost_all, data: .init(name: "Ghost Mode", color: theme.colors.text, type: .switchable(tauGhostModeIsOn(state.values.ghost)), viewType: .firstItem, action: {
                arguments.toggleGhost(nil)
            })))
            index += 1

            for (i, option) in ghostOptions.enumerated() {
                entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_ghost(option.key), data: .init(name: option.title, color: theme.colors.text, type: .switchable(state.values.ghost[keyPath: option.keyPath]), viewType: i == ghostOptions.count - 1 ? .lastItem : .innerItem, action: {
                    arguments.toggleGhost(option.keyPath)
                })))
                index += 1
            }

            //TODOLANG
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Sending a message still shows you online for a moment; Taugram sets you offline again within 30 seconds. Reacting to or replying to a story marks it seen. Toggle Ghost Mode quickly with ⌥⌘G."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
            index += 1

            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1

            //TODOLANG
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain("MESSAGE HISTORY"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1

            //TODOLANG
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_keep_deleted, data: .init(name: "Keep Deleted Messages", color: theme.colors.text, type: .switchable(state.values.keepDeletedMessages), viewType: .firstItem, action: {
                arguments.toggleValue(\.keepDeletedMessages)
            })))
            index += 1

            //TODOLANG
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_keep_edits, data: .init(name: "Keep Edit History", color: theme.colors.text, type: .switchable(state.values.keepEditHistory), viewType: .lastItem, action: {
                arguments.toggleValue(\.keepEditHistory)
            })))
            index += 1

            //TODOLANG
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Messages that others delete stay in the chat with a \"deleted\" mark. Earlier versions of edited messages are kept on this Mac; right-click a message to see them. Only what this Mac receives while running is saved."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
            index += 1

            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1

            //TODOLANG
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain("PROTECTED CONTENT"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1

            //TODOLANG
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_bypass_protection, data: .init(name: "Allow Copying and Saving", color: theme.colors.text, type: .switchable(state.values.bypassContentProtection), viewType: .firstItem, action: {
                arguments.toggleValue(\.bypassContentProtection)
            })))
            index += 1

            //TODOLANG
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_show_self_destructing, data: .init(name: "Show Self-Destructing Photos and Videos", color: theme.colors.text, type: .switchable(state.values.showSelfDestructingOnMac), viewType: .innerItem, action: {
                arguments.toggleValue(\.showSelfDestructingOnMac)
            })))
            index += 1

            //TODOLANG
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_view_once, data: .init(name: "Open Self-Destructing Media Unseen", color: theme.colors.text, type: .switchable(state.values.viewOnceWithoutMarking), viewType: state.values.viewOnceWithoutMarking ? .innerItem : .lastItem, action: {
                arguments.toggleValue(\.viewOnceWithoutMarking)
            })))
            index += 1

            if state.values.viewOnceWithoutMarking {
                //TODOLANG
                entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_view_once_secret, data: .init(name: "Also in Secret Chats", color: theme.colors.redUI, type: .switchable(state.values.viewOnceInSecretChats), viewType: .lastItem, action: {
                    arguments.toggleValue(\.viewOnceInSecretChats)
                })))
                index += 1
            }

            //TODOLANG
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Copy text, select, save and drag media from chats that forbid it. Forwarding such messages sends a copy: files are downloaded and uploaded again, without a \"forwarded from\" header. Telegram for Mac only says \"view it on your mobile\" for self-destructing photos and videos; Taugram can show and open them here. With \"Unseen\" on, self-destructing photos, videos and voice messages open without starting their timer, so the sender is not told and they stay in the chat. Secret chats are the most private place in Telegram; keep them out unless you must."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
            index += 1
        }
    } else {
        //TODOLANG
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_dangerous_review, data: .init(name: "Review Decision", color: theme.colors.accent, type: .none, viewType: .singleItem, action: arguments.reviewConsent)))
        index += 1
        //TODOLANG
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Off. Ghost mode, saved deleted messages and the other features that break the Telegram Terms of Service stay hidden."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    }

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("DEBUG"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    //TODOLANG
    let coreState = state.coreDangerousFeaturesAllowed ? "allowed" : "blocked"
    //TODOLANG
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_debug_core, data: .init(name: "Core: Dangerous Features", color: theme.colors.text, type: .context(coreState), viewType: .singleItem)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    return entries
}

public func TauSettingsController(context: any AccountContextProtocol) -> InputDataController {
    let actionsDisposable = DisposableSet()

    var getController: (() -> ViewController?)? = nil

    var window: Window {
        return bestWindow(context, getController?())
    }

    let canViewPeerId = ValuePromise(FastSettings.canViewPeerId, ignoreRepeated: true)

    let arguments = Arguments(toggleDangerousFeatures: {
        TauSettings.shared.update { current in
            var current = current
            current.dangerousFeaturesEnabled = !current.dangerousFeaturesEnabled
            return current
        }
    }, reviewConsent: {
        showTauConsent(for: window)
    }, selectAppIcon: { icon in
        TauSettings.shared.update { current in
            var current = current
            current.appIcon = icon == .classic ? nil : icon.rawValue
            return current
        }
        TauAppIconManager.applyStored()
    }, toggleMessageSeconds: {
        TauSettings.shared.update { current in
            var current = current
            current.showMessageSeconds = !current.showMessageSeconds
            return current
        }
    }, toggleHideStories: {
        TauSettings.shared.update { current in
            var current = current
            current.hideStoriesInChatList = !current.hideStoriesInChatList
            return current
        }
    }, togglePeerId: {
        FastSettings.canViewPeerId = !FastSettings.canViewPeerId
        canViewPeerId.set(FastSettings.canViewPeerId)
    }, toggleOLED: {
        setTauOLEDMode(!TauSettings.shared.current.oledMode, context: context)
    }, toggleGhost: { keyPath in
        if let keyPath {
            TauSettings.shared.update { current in
                var current = current
                current.ghost[keyPath: keyPath] = !current.ghost[keyPath: keyPath]
                return current
            }
        } else {
            toggleTauGhostMode()
        }
    }, toggleValue: { keyPath in
        TauSettings.shared.update { current in
            var current = current
            current[keyPath: keyPath] = !current[keyPath: keyPath]
            return current
        }
    }, chatLock: { action in
        switch action {
        case .set:
            showTauChatLockSetup(for: window)
        case .change:
            showTauChatLockVerify(for: window, completion: {
                showTauChatLockSetup(for: window)
            })
        case .remove:
            showTauChatLockVerify(for: window, completion: {
                TauChatLock.shared.removePasscode()
            })
        case .toggleBiometrics:
            showTauChatLockVerify(for: window, completion: {
                TauSettings.shared.update { current in
                    var current = current
                    current.chatLockBiometrics = !current.chatLockBiometrics
                    return current
                }
            })
        }
    })

    let chatLockChanges = Signal<Void, NoError>.single(Void()) |> then(TauChatLock.shared.changes)
    let signal = combineLatest(TauSettings.shared.signal, canViewPeerId.get(), chatLockChanges) |> map { values, canViewPeerId, _ in
        return State(values: values, chatLockHasPasscode: TauChatLock.shared.hasPasscode, coreDangerousFeaturesAllowed: TauCoreSettings.shared.dangerousFeaturesAllowed, canViewPeerId: canViewPeerId)
    } |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }

    let controller = InputDataController(dataSignal: signal, title: "Taugram", hasDone: false, identifier: "taugram")

    getController = { [weak controller] in
        return controller
    }

    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
}
