import Cocoa
import TGUIKit
import SettingsUI
import TauSettingsUI

private let tauSettingsIcon = generateTauSettingsIcon()

func installTaugramSettingsHooks(_ hooks: inout SettingsNavigationHooks) {
    DispatchQueue.main.async {
        TauAppIconManager.applyStored()
    }
    hooks.taugram = SettingsTaugramEntry(icon: {
        return tauSettingsIcon
    }, makeController: { context in
        return TauSettingsController(context: context)
    })
}

func presentTaugramConsentIfNeeded(window: Window) {
    DispatchQueue.main.async {
        showTauConsentIfNeeded(for: window)
    }
}
