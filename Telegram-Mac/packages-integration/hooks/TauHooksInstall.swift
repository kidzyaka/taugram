import Cocoa
import TGUIKit
import SettingsUI
import TauSettingsUI
import ThemeSettings

private let tauSettingsIcon = generateTauSettingsIcon()

func installTaugramSettingsHooks(_ hooks: inout SettingsNavigationHooks) {
    themeSettingsUpdateGuard = { current, updated in
        return tauOLEDThemeGuard(current: current, updated: updated)
    }
    DispatchQueue.main.async {
        TauAppIconManager.applyStored()
        installTauGhostMenuItem()
    }
    hooks.taugram = SettingsTaugramEntry(icon: {
        return tauSettingsIcon
    }, makeController: { context in
        return TauSettingsController(context: context)
    })
}

func presentTaugramConsentIfNeeded(window: Window) {
    DispatchQueue.main.async {
        installTauChatLock(window: window)
        showTauConsentIfNeeded(for: window)
    }
}
