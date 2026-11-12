import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramContext
import TelegramTheme
import InputDataUI
import GeneralRows
import TauSettings
import AlertsUI

private let _id_clear = InputDataIdentifier("_id_clear")

private func logEntries(_ log: [TauMCPLogEntry], clear: @escaping () -> Void) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    var sectionId: Int32 = 0
    var index: Int32 = 0

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    //TODOLANG
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_clear, data: .init(name: "Clear Log", color: theme.colors.redUI, type: .none, viewType: .singleItem, action: clear)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium

    if log.isEmpty {
        //TODOLANG
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("No agent requests yet."), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
    }
    for entry in log {
        let mark = entry.ok ? "✓" : "✕"
        let text = "\(mark) \(formatter.string(from: entry.date)) — \(entry.method)\n\(entry.detail)"
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(text), data: .init(color: entry.ok ? theme.colors.text : theme.colors.redUI, viewType: .textTopItem)))
        index += 1
    }

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    return entries
}

func TauMCPLogController() -> InputDataController {
    let signal = TauMCPServer.shared.log |> deliverOnPrepareQueue |> map { log in
        return InputDataSignalValue(entries: logEntries(log, clear: {
            TauMCPServer.shared.clearLog()
        }))
    }
    //TODOLANG
    return InputDataController(dataSignal: signal, title: "Agent Activity", hasDone: false, identifier: "taugram-mcp-log")
}

func toggleTauMCP(window: Window) {
    let enabled = TauSettings.shared.current.mcpEnabled
    let apply: (Bool) -> Void = { value in
        TauSettings.shared.update { current in
            var current = current
            current.mcpEnabled = value
            return current
        }
    }
    if enabled {
        apply(false)
        return
    }
    //TODOLANG
    let info = "AI agents such as Claude Code or Cursor will be able to read your chats through a server on this Mac (127.0.0.1 only, with a secret token).\n\nMessages from other people can contain instructions aimed at the agent. Only connect agents you trust, keep sending off or confirm every message, and revoke the token if it leaks.\n\nLocked and secret chats are never shared."
    //TODOLANG
    verifyAlert(for: window, header: "Allow Agent Access?", information: info, ok: "Allow", successHandler: { _ in
        apply(true)
    })
}

func copyTauMCPConfig() {
    let config = TauMCPServer.shared.configJSON(port: TauSettings.shared.current.mcpPort)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(config, forType: .string)
}
