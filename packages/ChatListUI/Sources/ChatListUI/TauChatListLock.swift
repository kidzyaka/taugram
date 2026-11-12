import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import TelegramContext
import TelegramTheme
import LocalAnimations
import AlertsUI
import TauSettings

func tauLockedChatText() -> NSAttributedString {
    let attr = NSMutableAttributedString()
    //TODOLANG
    _ = attr.append(string: "🔒 Chat is locked", color: theme.colors.grayText, font: .normal(.text))
    attr.setSelected(color: theme.colors.underSelectedColor, range: attr.range)
    return attr
}

func tauChatLockMenuItems(context: any AccountContextProtocol, peerId: PeerId) -> [ContextMenuItem] {
    if peerId == context.peerId {
        return []
    }
    let lock = TauChatLock.shared
    guard lock.isLockedChat(peerId) else {
        //TODOLANG
        return [ContextMenuItem("Lock Chat", handler: {
            lock.presentLockChat?(peerId)
        }, itemImage: MenuAnimation.menu_lock.value)]
    }
    let requireUnlocked: (@escaping () -> Void) -> Void = { action in
        if lock.needsUnlock(peerId) {
            //TODOLANG
            alert(for: context.window, info: "Open the chat and unlock it with your passcode first.")
        } else {
            action()
        }
    }
    let usesTouchId = lock.usesTouchId(peerId)
    //TODOLANG
    let touchIdItem = ContextMenuItem("Unlock with Touch ID", handler: {
        requireUnlocked {
            lock.setTouchId(peerId, enabled: !usesTouchId)
        }
    }, state: usesTouchId ? .on : .off)
    //TODOLANG
    let removeItem = ContextMenuItem("Remove Chat Lock", handler: {
        requireUnlocked {
            lock.setLocked(peerId, locked: false)
        }
    }, itemImage: MenuAnimation.menu_unlock.value)
    return [touchIdItem, removeItem]
}
