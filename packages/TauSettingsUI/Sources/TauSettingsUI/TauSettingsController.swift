import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import TelegramContext
import TelegramTheme
import TelegramUtils
import InputDataUI
import TauSettings

private final class Arguments {
    let toggleDangerousFeatures: () -> Void
    let reviewConsent: () -> Void
    init(toggleDangerousFeatures: @escaping () -> Void, reviewConsent: @escaping () -> Void) {
        self.toggleDangerousFeatures = toggleDangerousFeatures
        self.reviewConsent = reviewConsent
    }
}

private struct State: Equatable {
    var values: TauSettingsValues
    var coreDangerousFeaturesAllowed: Bool
}

private let _id_dangerous_enabled = InputDataIdentifier("_id_dangerous_enabled")
private let _id_dangerous_review = InputDataIdentifier("_id_dangerous_review")
private let _id_debug_core = InputDataIdentifier("_id_debug_core")

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

    let arguments = Arguments(toggleDangerousFeatures: {
        TauSettings.shared.update { current in
            var current = current
            current.dangerousFeaturesEnabled = !current.dangerousFeaturesEnabled
            return current
        }
    }, reviewConsent: {
        showTauConsent(for: window)
    })

    let signal = TauSettings.shared.signal |> map { values in
        return State(values: values, coreDangerousFeaturesAllowed: TauCoreSettings.shared.dangerousFeaturesAllowed)
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
