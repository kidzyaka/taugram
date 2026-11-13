import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramTheme
import InputDataUI
import GeneralRows
import TauSettings
import TauSpeech

private struct ModelsState: Equatable {
    var selected: TauSpeechModel
    var states: [TauSpeechModel: TauSpeechModelState]
}

private func _id_model(_ model: TauSpeechModel) -> InputDataIdentifier {
    return InputDataIdentifier("_id_speech_model_\(model.rawValue)")
}

private func select(_ model: TauSpeechModel) {
    TauSettings.shared.update { current in
        var current = current
        current.transcriptionModel = model.rawValue
        return current
    }
}

private func modelEntries(_ state: ModelsState) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    var sectionId: Int32 = 0
    var index: Int32 = 0
    let supported = TauSpeechClient.shared.isSupported

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("RECOGNITION MODEL"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    let models = TauSpeechModel.allCases
    for model in models {
        let modelState = state.states[model] ?? .unknown
        let installed = model == .system || modelState.installed
        var description = model.info
        let type: GeneralInteractedType
        var enabled = true
        if !model.isDownloadable {
            type = .selectable(state.selected == model)
        } else if !supported {
            enabled = false
            //TODOLANG
            description += "\nRequires macOS 14 or later."
            type = .none
        } else if modelState.downloading {
            //TODOLANG
            description += "\nDownloading… click to cancel."
            type = .context("\(Int((modelState.progress * 100).rounded()))%")
        } else if installed {
            //TODOLANG
            description += "\nDownloaded. Right-click to delete."
            type = .selectable(state.selected == model)
        } else {
            if let error = modelState.error {
                //TODOLANG
                description += "\nDownload failed: \(error)"
            }
            //TODOLANG
            type = .context("Download")
        }
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_model(model), data: .init(name: model.title, color: theme.colors.text, type: type, viewType: bestGeneralViewType(models, for: model), enabled: enabled, description: description, action: {
            if !model.isDownloadable || modelState.installed {
                select(model)
            } else if modelState.downloading {
                TauSpeechClient.shared.cancelDownload(model)
            } else {
                TauSpeechClient.shared.download(model)
            }
        }, menuItems: {
            guard model.isDownloadable, modelState.installed else {
                return []
            }
            //TODOLANG
            return [ContextMenuItem("Delete Model", handler: {
                if state.selected == model {
                    select(.system)
                }
                TauSpeechClient.shared.delete(model)
            }, itemMode: .destruct)]
        })))
        index += 1
    }

    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Downloaded models run only on this Mac: voice messages never leave it. Models are fetched from Hugging Face and kept until you delete them."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    return entries
}

func TauSpeechModelsController() -> InputDataController {
    let downloadable = TauSpeechModel.allCases.filter { $0.isDownloadable }
    let states: Signal<[TauSpeechModel: TauSpeechModelState], NoError>
    if TauSpeechClient.shared.isSupported {
        states = combineLatest(downloadable.map { model in
            TauSpeechClient.shared.state(model) |> map { (model, $0) }
        }) |> map { values in
            var result: [TauSpeechModel: TauSpeechModelState] = [:]
            for (model, state) in values {
                result[model] = state
            }
            return result
        }
    } else {
        states = .single([:])
    }
    let selected = TauSettings.shared.signal |> map { TauSpeechModel(rawValue: $0.transcriptionModel) ?? .system } |> distinctUntilChanged
    let signal = combineLatest(selected, states) |> map { ModelsState(selected: $0, states: $1) } |> distinctUntilChanged |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: modelEntries(state))
    }
    //TODOLANG
    return InputDataController(dataSignal: signal, title: "Recognition Model", hasDone: false, identifier: "taugram-speech-models")
}
