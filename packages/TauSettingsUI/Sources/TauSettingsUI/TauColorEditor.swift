import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramContext
import TelegramTheme
import ThemeSettings
import ColorPalette
import InputDataUI
import GeneralRows
import TauSettings
import TelegramUtils

let tauCustomPaletteName = "Taugram Custom"

private func tauHex(_ color: NSColor) -> String {
    let color = color.usingColorSpace(.deviceRGB) ?? color
    let r = Int(round(color.redComponent * 255))
    let g = Int(round(color.greenComponent * 255))
    let b = Int(round(color.blueComponent * 255))
    let hex = String(format: "#%02x%02x%02x", r, g, b)
    if color.alphaComponent < 0.999 {
        return hex + ":" + String(format: "%.2f", color.alphaComponent)
    }
    return hex
}

private func tauColor(_ value: String) -> NSColor? {
    let parts = value.components(separatedBy: ":")
    guard let hex = UInt32(String(parts[0].trimmingCharacters(in: .whitespaces).suffix(6)), radix: 16) else {
        return nil
    }
    var alpha: CGFloat = 1
    if parts.count == 2, let value = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
        alpha = CGFloat(max(0, min(1, value)))
    }
    return NSColor(deviceRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

func tauPaletteText(_ palette: ColorPalette) -> String {
    return palette.toString
}

public struct TauSettingsUIHooks {
    public var makeChatPreviewItems: (NSSize, any AccountContextProtocol, TelegramPresentationTheme) -> [TableRowItem] = { _, _, _ in [] }

    public init() {
    }

    public private(set) static var shared = TauSettingsUIHooks()

    public static func install(_ hooks: TauSettingsUIHooks) {
        shared = hooks
    }
}

private let gradientKeyPrefix = "gradient#"

private final class TauChatPreviewRowItem: GeneralRowItem {
    let items: [TableRowItem]
    let previewHeight: CGFloat

    init(_ initialSize: NSSize, stableId: AnyHashable, context: any AccountContextProtocol) {
        let items = TauSettingsUIHooks.shared.makeChatPreviewItems(initialSize, context, theme)
        var height: CGFloat = 16
        for item in items {
            _ = item.makeSize(initialSize.width - 40, oldWidth: 0)
            height += item.height
        }
        self.items = items
        self.previewHeight = height
        super.init(initialSize, height: height, stableId: stableId, viewType: .singleItem)
    }

    override func viewClass() -> AnyClass {
        return TauChatPreviewRowView.self
    }
}

private final class TauChatPreviewRowView: GeneralContainableRowView {
    private let tableView = TableView(frame: .zero, isFlipped: false)

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        tableView.getBackgroundColor = {
            return .clear
        }
        addSubview(tableView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        guard let item = item as? TauChatPreviewRowItem else {
            return
        }
        containerView.backgroundColor = theme.colors.chatBackground
        tableView.removeAll()
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 8, stableId: arc4random(), backgroundColor: .clear))
        for chatItem in item.items {
            _ = tableView.addItem(item: chatItem)
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        tableView.frame = containerView.bounds
    }
}

private struct PaletteKey: Equatable {
    let key: String
    let value: String
}

private func paletteKeys(_ text: String) -> [PaletteKey] {
    var result: [PaletteKey] = []
    let skip: Set<String> = ["isDark", "tinted", "name", "parent", "copyright", "wallpaper", "bubbleBackground_outgoing"]
    for line in text.components(separatedBy: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("//") {
            continue
        }
        let parts = trimmed.components(separatedBy: " = ")
        guard parts.count == 2, !skip.contains(parts[0]) else {
            continue
        }
        result.append(PaletteKey(key: parts[0], value: parts[1]))
    }
    return result
}

private func gradientValues(_ text: String) -> [String] {
    for line in text.components(separatedBy: "\n") {
        let parts = line.components(separatedBy: " = ")
        if parts.count == 2, parts[0] == "bubbleBackground_outgoing" {
            return parts[1].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
    }
    return []
}

private func paletteText(_ text: String, replacingGradient values: [String]) -> String {
    return paletteText(text, replacing: "bubbleBackground_outgoing", with: values.joined(separator: ","))
}

private func paletteText(_ text: String, replacing key: String, with value: String) -> String {
    var found = false
    var lines: [String] = []
    for line in text.components(separatedBy: "\n") {
        let parts = line.components(separatedBy: " = ")
        if parts.count == 2, parts[0] == key {
            lines.append("\(key) = \(value)")
            found = true
        } else if parts.count == 2, parts[0] == "name" {
            lines.append("name = \(tauCustomPaletteName)")
        } else {
            lines.append(line)
        }
    }
    if !found {
        lines.append("\(key) = \(value)")
    }
    return lines.joined(separator: "\n")
}

private func importPaletteText(_ text: String) -> ColorPalette? {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("taugram-editor-\(arc4random()).palette")
    guard (try? text.write(to: url, atomically: true, encoding: .utf8)) != nil else {
        return nil
    }
    defer {
        try? FileManager.default.removeItem(at: url)
    }
    return importPalette(url.path)
}

private func applyPalette(_ palette: ColorPalette, context: any AccountContextProtocol) {
    _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
        return settings.withUpdatedPalette(palette).withUpdatedCloudTheme(nil)
    }).start()
}

private enum PaletteGroup: Int, CaseIterable {
    case general
    case incoming
    case outgoing
    case chat
    case other

    //TODOLANG
    var title: String {
        switch self {
        case .general: return "GENERAL"
        case .incoming: return "INCOMING MESSAGES"
        case .outgoing: return "OUTGOING MESSAGES"
        case .chat: return "CHAT"
        case .other: return "OTHER"
        }
    }

    static func of(_ key: String) -> PaletteGroup {
        if key.hasSuffix("_incoming") {
            return .incoming
        }
        if key.hasSuffix("_outgoing") {
            return .outgoing
        }
        if key.hasPrefix("chat") || key.hasPrefix("bubble") || key.hasPrefix("selectMessage") {
            return .chat
        }
        let general: Set<String> = ["basicAccent", "background", "text", "grayText", "link", "accent", "redUI", "greenUI", "border", "grayBackground", "grayForeground", "listBackground", "listGrayText", "grayIcon", "accentIcon", "accentSelect", "selectText"]
        if general.contains(key) {
            return .general
        }
        return .other
    }
}

private final class ColorPanelTarget: NSObject {
    var onChange: ((NSColor) -> Void)?

    @objc func colorChanged(_ sender: NSColorPanel) {
        onChange?(sender.color)
    }
}

private final class Arguments {
    let edit: (PaletteKey) -> Void
    let addGradientPoint: () -> Void
    let removeGradientPoint: () -> Void
    let export: () -> Void
    let importFile: () -> Void
    let reset: () -> Void
    init(edit: @escaping (PaletteKey) -> Void, addGradientPoint: @escaping () -> Void, removeGradientPoint: @escaping () -> Void, export: @escaping () -> Void, importFile: @escaping () -> Void, reset: @escaping () -> Void) {
        self.edit = edit
        self.addGradientPoint = addGradientPoint
        self.removeGradientPoint = removeGradientPoint
        self.export = export
        self.importFile = importFile
        self.reset = reset
    }
}

private struct State: Equatable {
    var keys: [PaletteKey]
    var gradient: [String]
    var text: String
    var paletteName: String
    var parentName: String
    var editing: String?
    var oledMode: Bool
    var bubbleRadius: Int
}

private func swatch(_ color: NSColor) -> CGImage? {
    return generateImage(NSMakeSize(24, 24), rotatedContext: { size, ctx in
        ctx.clear(CGRect(origin: .zero, size: size))
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
        let path = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
        ctx.addPath(path)
        ctx.setStrokeColor(NSColor.gray.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()
    })
}

private func _id_key(_ key: String) -> InputDataIdentifier {
    return InputDataIdentifier("_id_color_\(key)")
}
private let _id_export = InputDataIdentifier("_id_export")
private let _id_import = InputDataIdentifier("_id_import")
private let _id_reset = InputDataIdentifier("_id_reset")
private let _id_preview = InputDataIdentifier("_id_preview")
private let _id_bubble_radius = InputDataIdentifier("_id_bubble_radius")
private let _id_gradient_add = InputDataIdentifier("_id_gradient_add")
private let _id_gradient_remove = InputDataIdentifier("_id_gradient_remove")

private func entries(_ state: State, context: any AccountContextProtocol, arguments: Arguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    var sectionId: Int32 = 0
    var index: Int32 = 0

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_preview, equatable: InputDataEquatable(state.text + "\(state.bubbleRadius)"), comparable: nil, item: { initialSize, stableId in
        return TauChatPreviewRowItem(initialSize, stableId: stableId, context: context)
    }))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    let radiusItems: [ContextMenuItem] = [0, 4, 8, 12, 16, 20, 24].map { value in
        //TODOLANG
        let title = value == 16 ? "\(value) (Default)" : "\(value)"
        return ContextMenuItem(title, handler: {
            TauSettings.shared.update { current in
                var current = current
                current.bubbleRadius = value
                return current
            }
        }, state: value == state.bubbleRadius ? .on : nil)
    }
    //TODOLANG
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_bubble_radius, data: .init(name: "Bubble Corners", color: theme.colors.text, type: .contextSelector("\(state.bubbleRadius)", radiusItems), viewType: .singleItem)))
    index += 1
    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Corner radius of message bubbles, in points."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    if state.oledMode {
        //TODOLANG
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("OLED mode is on and keeps the theme locked. Turn it off in Settings → Taugram to edit colors."), data: .init(color: theme.colors.redUI, viewType: .textTopItem)))
        index += 1
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }

    //TODOLANG
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_export, data: .init(name: "Export Palette…", color: theme.colors.accent, type: .none, viewType: .firstItem, action: arguments.export)))
    index += 1
    //TODOLANG
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_import, data: .init(name: "Import Palette…", color: theme.colors.accent, type: .none, viewType: .innerItem, action: arguments.importFile)))
    index += 1
    //TODOLANG
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_reset, data: .init(name: "Reset to \(state.parentName)", color: theme.colors.redUI, type: .none, viewType: .lastItem, action: arguments.reset)))
    index += 1
    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Current palette: \(state.paletteName). Click a color to change it; the whole app updates as you pick. Telegram may still raise the contrast of text that is almost the color of its background."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1

    if !state.gradient.isEmpty {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        //TODOLANG
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("OUTGOING BUBBLE GRADIENT"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        for (i, value) in state.gradient.enumerated() {
            let key = PaletteKey(key: "\(gradientKeyPrefix)\(i)", value: value)
            let isEditing = state.editing == key.key
            //TODOLANG
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_key(key.key), data: .init(name: "Point \(i + 1)", color: isEditing ? theme.colors.accent : theme.colors.text, icon: swatch(tauColor(value) ?? .clear), type: .context(value), viewType: i == 0 ? .firstItem : .innerItem, action: {
                arguments.edit(key)
            })))
            index += 1
        }
        if state.gradient.count < 4 {
            //TODOLANG
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_gradient_add, data: .init(name: "Add Point", color: theme.colors.accent, type: .none, viewType: state.gradient.count > 1 ? .innerItem : .lastItem, action: arguments.addGradientPoint)))
            index += 1
        }
        if state.gradient.count > 1 {
            //TODOLANG
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_gradient_remove, data: .init(name: "Remove Last Point", color: theme.colors.redUI, type: .none, viewType: .lastItem, action: arguments.removeGradientPoint)))
            index += 1
        }
        //TODOLANG
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Outgoing bubbles blend from the first point to the last. One point gives a solid color."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    }

    for group in PaletteGroup.allCases {
        let keys = state.keys.filter { PaletteGroup.of($0.key) == group }
        if keys.isEmpty {
            continue
        }
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(group.title), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        for (i, key) in keys.enumerated() {
            let viewType: GeneralViewType
            if keys.count == 1 {
                viewType = .singleItem
            } else if i == 0 {
                viewType = .firstItem
            } else if i == keys.count - 1 {
                viewType = .lastItem
            } else {
                viewType = .innerItem
            }
            let color = tauColor(key.value) ?? .clear
            let isEditing = state.editing == key.key
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_key(key.key), data: .init(name: key.key, color: isEditing ? theme.colors.accent : theme.colors.text, icon: swatch(color), type: .context(key.value), viewType: viewType, action: {
                arguments.edit(key)
            })))
            index += 1
        }
    }

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    return entries
}

public func TauColorEditorController(context: any AccountContextProtocol) -> InputDataController {
    let actionsDisposable = DisposableSet()
    let applyDisposable = MetaDisposable()
    actionsDisposable.add(applyDisposable)

    var getController: (() -> ViewController?)? = nil
    var window: Window {
        return bestWindow(context, getController?())
    }

    let editing = ValuePromise<String?>(nil, ignoreRepeated: true)
    let editingValue = Atomic<String?>(value: nil)
    let panelTarget = ColorPanelTarget()

    let apply: (ColorPalette) -> Void = { palette in
        applyPalette(palette, context: context)
    }

    let applyKey: (String, NSColor) -> Void = { key, color in
        let current = tauPaletteText(theme.colors)
        let text: String
        if key.hasPrefix(gradientKeyPrefix), let i = Int(key.dropFirst(gradientKeyPrefix.count)) {
            var values = gradientValues(current)
            guard i < values.count else {
                return
            }
            values[i] = tauHex(color)
            text = paletteText(current, replacingGradient: values)
        } else {
            text = paletteText(current, replacing: key, with: tauHex(color))
        }
        applyDisposable.set((Signal<Void, NoError>.single(Void()) |> delay(0.12, queue: .mainQueue())).start(completed: {
            if let palette = importPaletteText(text) {
                apply(palette)
            }
        }))
    }

    let arguments = Arguments(edit: { key in
        guard let color = tauColor(key.value) else {
            return
        }
        _ = editingValue.swap(key.key)
        editing.set(key.key)
        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        panel.isContinuous = true
        panelTarget.onChange = { color in
            if let key = editingValue.with({ $0 }) {
                applyKey(key, color)
            }
        }
        panel.setTarget(nil)
        panel.setAction(nil)
        panel.color = color
        panel.setTarget(panelTarget)
        panel.setAction(#selector(ColorPanelTarget.colorChanged(_:)))
        //TODOLANG
        panel.title = key.key
        panel.makeKeyAndOrderFront(nil)
    }, addGradientPoint: {
        let current = tauPaletteText(theme.colors)
        var values = gradientValues(current)
        guard let last = values.last, values.count < 4 else {
            return
        }
        values.append(last)
        if let palette = importPaletteText(paletteText(current, replacingGradient: values)) {
            apply(palette)
        }
    }, removeGradientPoint: {
        let current = tauPaletteText(theme.colors)
        var values = gradientValues(current)
        guard values.count > 1 else {
            return
        }
        values.removeLast()
        if let palette = importPaletteText(paletteText(current, replacingGradient: values)) {
            apply(palette)
        }
    }, export: {
        let text = tauPaletteText(theme.colors)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(theme.colors.name).palette"
        panel.allowedFileTypes = ["palette"]
        panel.beginSheetModal(for: window, completionHandler: { response in
            if response == .OK, let url = panel.url {
                try? text.write(to: url, atomically: true, encoding: .utf8)
            }
        })
    }, importFile: {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["palette"]
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window, completionHandler: { response in
            if response == .OK, let url = panel.url, let palette = importPalette(url.path) {
                apply(palette)
            }
        })
    }, reset: {
        apply(theme.colors.parent.palette)
    })

    let paletteSignal = appearanceSignal |> map { _ in tauPaletteText(theme.colors) } |> distinctUntilChanged
    let settings = TauSettings.shared.signal |> map { ($0.oledMode, $0.bubbleRadius) } |> distinctUntilChanged(isEqual: { $0 == $1 })
    let signal = combineLatest(paletteSignal, editing.get(), settings) |> map { text, editing, settings in
        return State(keys: paletteKeys(text), gradient: gradientValues(text), text: text, paletteName: theme.colors.name, parentName: theme.colors.parent.palette.name, editing: editing, oledMode: settings.0, bubbleRadius: settings.1)
    } |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, context: context, arguments: arguments))
    }

    //TODOLANG
    let controller = InputDataController(dataSignal: signal, title: "Theme Editor", hasDone: false, identifier: "taugram-colors")

    getController = { [weak controller] in
        return controller
    }

    controller.onDeinit = {
        actionsDisposable.dispose()
        panelTarget.onChange = nil
        if NSColorPanel.shared.isVisible {
            NSColorPanel.shared.setTarget(nil)
            NSColorPanel.shared.setAction(nil)
            NSColorPanel.shared.orderOut(nil)
        }
    }

    return controller
}
