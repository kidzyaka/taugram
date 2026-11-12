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

func tauChatLockMenuItem(context: any AccountContextProtocol, peerId: PeerId) -> ContextMenuItem? {
    if peerId == context.peerId {
        return nil
    }
    let lock = TauChatLock.shared
    if lock.isLockedChat(peerId) {
        //TODOLANG
        return ContextMenuItem("Remove Chat Lock", handler: {
            if lock.needsUnlock(peerId) {
                //TODOLANG
                alert(for: context.window, info: "Open the chat and unlock it with your passcode first.")
            } else {
                lock.setLocked(peerId, locked: false)
            }
        }, itemImage: MenuAnimation.menu_unlock.value)
    } else {
        //TODOLANG
        return ContextMenuItem("Lock Chat", handler: {
            if lock.hasPasscode {
                lock.setLocked(peerId, locked: true)
            } else {
                lock.setupPasscode?({
                    lock.setLocked(peerId, locked: true)
                })
            }
        }, itemImage: MenuAnimation.menu_lock.value)
    }
}
