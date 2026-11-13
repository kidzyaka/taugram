import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramTheme
import InputDataUI
import GeneralRows
import TauSettings

private func _id_menu_item(_ item: TauMessageMenuItem) -> InputDataIdentifier {
    return InputDataIdentifier("_id_menu_item_\(item.rawValue)")
}

private func menuEntries(_ hidden: [String]) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    var sectionId: Int32 = 0
    var index: Int32 = 0

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("SHOW IN MESSAGE MENU"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    let items = TauMessageMenuItem.allCases
    for item in items {
        let shown = !hidden.contains(item.rawValue)
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_menu_item(item), data: .init(name: item.title, color: theme.colors.text, type: .switchable(shown), viewType: bestGeneralViewType(items, for: item), action: {
            TauSettings.shared.update { current in
                var current = current
                if let index = current.hiddenMenuItems.firstIndex(of: item.rawValue) {
                    current.hiddenMenuItems.remove(at: index)
                } else {
                    current.hiddenMenuItems.append(item.rawValue)
                }
                return current
            }
        })))
        index += 1
    }

    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Hidden items only leave the right-click menu. Keyboard shortcuts and swipe actions still work."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    return entries
}

func TauMessageMenuController() -> InputDataController {
    let signal = TauSettings.shared.signal |> map { $0.hiddenMenuItems } |> distinctUntilChanged |> deliverOnPrepareQueue |> map { hidden in
        return InputDataSignalValue(entries: menuEntries(hidden))
    }
    //TODOLANG
    return InputDataController(dataSignal: signal, title: "Message Menu", hasDone: false, identifier: "taugram-message-menu")
}
