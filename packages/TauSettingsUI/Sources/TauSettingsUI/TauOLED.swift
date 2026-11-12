import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramContext
import ColorPalette
import ThemeSettings
import TelegramTheme
import TauSettings

let tauOLEDPaletteName = "Taugram OLED"

private let oledOverrides: [String: String] = [
    "background": "#000000",
    "chatBackground": "#000000",
    "listBackground": "#000000",
    "grayUI": "#0e0e10",
    "grayHighlight": "#0e0e10",
    "grayForeground": "#16161a",
    "grayBackground": "#1f1f24",
    "border": "#26262b",
    "text": "#f2f2f2",
    "grayText": "#a0a0a8",
    "darkGrayText": "#a0a0a8",
    "listGrayText": "#a0a0a8",
    "grayIcon": "#a0a0a8",
    "badgeMuted": "#a0a0a8",
    "selectText": "#a0a0a8",
    "selectMessage": "#16161a",
    "selectMessageBubble": "#16161a",
    "bubbleBackground_incoming": "#16161a",
    "bubbleBorder_incoming": "#26262b",
    "bubbleBackgroundHighlight_incoming": "#26262b",
    "textBubble_incoming": "#f2f2f2",
    "grayTextBubble_incoming": "#a0a0a8",
    "grayIconBubble_incoming": "#a0a0a8",
    "chatReplyTextEnabled": "#f2f2f2",
    "chatReplyTextDisabled": "#a0a0a8",
    "chatDateActive": "#0e0e10",
    "chatDateText": "#a0a0a8",
    "revealAction_neutral1_background": "#26262b",
    "revealAction_inactive_background": "#26262b",
]

let tauOLEDPalette: ColorPalette = {
    var lines: [String] = []
    for line in darkPalette.toString.components(separatedBy: "\n") {
        let parts = line.components(separatedBy: " = ")
        if parts.count == 2, !line.hasPrefix("//") {
            let key = parts[0]
            if key == "name" {
                lines.append("name = \(tauOLEDPaletteName)")
                continue
            }
            if key == "copyright" {
                lines.append("copyright = Taugram")
                continue
            }
            if key == "wallpaper" {
                lines.append("wallpaper = none")
                continue
            }
            if let value = oledOverrides[key] {
                lines.append("\(key) = \(value)")
                continue
            }
        }
        lines.append(line)
    }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("taugram-oled.palette")
    guard (try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)) != nil, let palette = importPalette(url.path) else {
        return darkPalette
    }
    return palette
}()

private func isOLEDPalette(_ palette: ColorPalette) -> Bool {
    return palette.name == tauOLEDPaletteName
}

public func tauOLEDThemeGuard(current: ThemePaletteSettings, updated: ThemePaletteSettings) -> ThemePaletteSettings {
    guard TauSettings.shared.current.oledMode, isOLEDPalette(current.palette) else {
        return updated
    }
    let wallpaper = current.wallpaper
    return updated.withUpdatedPalette(current.palette).withUpdatedCloudTheme(nil).updateWallpaper { _ in
        return wallpaper
    }
}

private func oledThemeSettings(_ settings: ThemePaletteSettings) -> ThemePaletteSettings {
    return settings.withUpdatedPalette(tauOLEDPalette).withUpdatedCloudTheme(nil).updateWallpaper { current in
        return current.withUpdatedWallpaper(.none)
    }
}

public func setTauOLEDMode(_ enabled: Bool, context: any AccountContextProtocol) {
    let accountManager = context.sharedContext.accountManager
    if enabled {
        let snapshot = Atomic<Data?>(value: nil)
        TauSettings.shared.update { current in
            var current = current
            current.oledMode = true
            return current
        }
        _ = (updateThemeInteractivetly(accountManager: accountManager, f: { settings in
            if !isOLEDPalette(settings.palette) {
                _ = snapshot.swap(try? AdaptedPostboxEncoder().encode(settings))
            }
            return oledThemeSettings(settings)
        }) |> deliverOnMainQueue).start(completed: {
            if let data = snapshot.with({ $0 }) {
                TauSettings.shared.update { current in
                    var current = current
                    current.oledThemeSnapshot = data
                    return current
                }
            }
        })
    } else {
        let snapshot = TauSettings.shared.current.oledThemeSnapshot
        TauSettings.shared.update { current in
            var current = current
            current.oledMode = false
            current.oledThemeSnapshot = nil
            return current
        }
        _ = updateThemeInteractivetly(accountManager: accountManager, f: { settings in
            if let snapshot, let previous = try? AdaptedPostboxDecoder().decode(ThemePaletteSettings.self, from: snapshot) {
                return previous
            }
            return settings.withUpdatedPalette(darkPalette).installDefaultWallpaper()
        }).start()
    }
}
