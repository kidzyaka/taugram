import Cocoa
import SwiftSignalKit
import TauSettings

public func toggleTauGhostMode() {
    TauSettings.shared.toggleGhostMode()
}

private final class TauGhostMenuTarget: NSObject {
    @objc func toggle(_ sender: Any?) {
        toggleTauGhostMode()
    }
}

private let ghostMenuTarget = TauGhostMenuTarget()
private let ghostMenuDisposable = MetaDisposable()

public func installTauGhostMenuItem() {
    guard let menu = NSApp.mainMenu?.item(at: 0)?.submenu else {
        return
    }
    //TODOLANG
    let item = NSMenuItem(title: "Ghost Mode", action: #selector(TauGhostMenuTarget.toggle(_:)), keyEquivalent: "g")
    item.keyEquivalentModifierMask = [.command, .option]
    item.target = ghostMenuTarget
    menu.insertItem(item, at: min(2, menu.numberOfItems))
    ghostMenuDisposable.set((TauSettings.shared.signal |> deliverOnMainQueue).start(next: { values in
        item.isHidden = !values.dangerousFeaturesAllowed
        item.state = tauGhostModeIsOn(values.ghost) ? .on : .off
    }))
}
