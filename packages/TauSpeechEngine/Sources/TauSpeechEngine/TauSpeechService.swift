import Foundation
import FluidAudio
import WhisperKit
import TauSpeechProtocol

private let whisperVariant = "openai_whisper-large-v3-v20240930_turbo_632MB"

private struct DownloadState {
    var progress: Double = 0
    var task: Task<Void, Never>?
}

private actor TauSpeechModels {
    private var parakeet: AsrManager?
    private var whisper: WhisperKit?

    func parakeetManager(directory: URL) async throws -> AsrManager {
        if let parakeet {
            return parakeet
        }
        let models = try await AsrModels.load(from: directory, version: .v3)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        self.parakeet = manager
        return manager
    }

    func whisperKit(folder: URL) async throws -> WhisperKit {
        if let whisper {
            return whisper
        }
        let config = WhisperKitConfig(model: whisperVariant, modelFolder: folder.path, verbose: false, prewarm: false, load: true, download: false)
        let kit = try await WhisperKit(config)
        self.whisper = kit
        return kit
    }

    func unload(_ model: TauSpeechModel) {
        switch model {
        case .parakeetV3:
            self.parakeet = nil
        case .whisperLargeV3Turbo:
            self.whisper = nil
        case .system:
            break
        }
    }
}

final class TauSpeechService: NSObject, TauSpeechServiceProtocol {
    private let lock = NSLock()
    private var downloads: [TauSpeechModel: DownloadState] = [:]
    private var errors: [TauSpeechModel: String] = [:]
    private let models = TauSpeechModels()

    private var baseDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("SpeechModels", isDirectory: true)
    }

    private var parakeetDirectory: URL {
        return self.baseDirectory.appendingPathComponent("parakeet-tdt-0.6b-v3", isDirectory: true)
    }

    private var whisperBase: URL {
        return self.baseDirectory.appendingPathComponent("whisper", isDirectory: true)
    }

    private var whisperFolder: URL {
        return self.whisperBase.appendingPathComponent("models/argmaxinc/whisperkit-coreml/\(whisperVariant)", isDirectory: true)
    }

    private func isInstalled(_ model: TauSpeechModel) -> Bool {
        switch model {
        case .system:
            return true
        case .parakeetV3:
            return AsrModels.modelsExist(at: self.parakeetDirectory, version: .v3)
        case .whisperLargeV3Turbo:
            let folder = self.whisperFolder
            return ["AudioEncoder.mlmodelc", "TextDecoder.mlmodelc", "MelSpectrogram.mlmodelc"].allSatisfy {
                FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path)
            }
        }
    }

    private func setProgress(_ model: TauSpeechModel, _ value: Double) {
        self.lock.lock()
        if var state = self.downloads[model] {
            state.progress = value
            self.downloads[model] = state
        }
        self.lock.unlock()
    }

    private func finish(_ model: TauSpeechModel, error: String?) {
        self.lock.lock()
        self.downloads[model] = nil
        self.errors[model] = error
        self.lock.unlock()
    }

    func modelState(_ model: String, reply: @escaping (Bool, Bool, Double, String?) -> Void) {
        guard let model = TauSpeechModel(rawValue: model) else {
            reply(false, false, 0, "unknown model")
            return
        }
        self.lock.lock()
        let download = self.downloads[model]
        let error = self.errors[model]
        self.lock.unlock()
        reply(download == nil && self.isInstalled(model), download != nil, download?.progress ?? 0, error)
    }

    func downloadModel(_ model: String, reply: @escaping (String?) -> Void) {
        guard let model = TauSpeechModel(rawValue: model), model.isDownloadable else {
            reply("unknown model")
            return
        }
        self.lock.lock()
        if self.downloads[model] != nil {
            self.lock.unlock()
            reply(nil)
            return
        }
        self.errors[model] = nil
        self.downloads[model] = DownloadState()
        self.lock.unlock()

        let task = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                try FileManager.default.createDirectory(at: self.baseDirectory, withIntermediateDirectories: true)
                switch model {
                case .parakeetV3:
                    _ = try await AsrModels.download(to: self.parakeetDirectory, version: .v3, progressHandler: { [weak self] progress in
                        self?.setProgress(model, progress.fractionCompleted)
                    })
                case .whisperLargeV3Turbo:
                    _ = try await WhisperKit.download(variant: whisperVariant, downloadBase: self.whisperBase, progressCallback: { [weak self] progress in
                        self?.setProgress(model, progress.fractionCompleted)
                    })
                case .system:
                    break
                }
                try Task.checkCancellation()
                self.finish(model, error: nil)
            } catch is CancellationError {
                self.finish(model, error: nil)
            } catch {
                self.finish(model, error: error.localizedDescription)
            }
        }
        self.lock.lock()
        self.downloads[model]?.task = task
        self.lock.unlock()
        reply(nil)
    }

    func cancelDownload(_ model: String) {
        guard let model = TauSpeechModel(rawValue: model) else {
            return
        }
        self.lock.lock()
        let task = self.downloads[model]?.task
        self.lock.unlock()
        task?.cancel()
    }

    func deleteModel(_ model: String, reply: @escaping (String?) -> Void) {
        guard let model = TauSpeechModel(rawValue: model), model.isDownloadable else {
            reply("unknown model")
            return
        }
        let directory: URL
        switch model {
        case .parakeetV3:
            directory = self.parakeetDirectory
        case .whisperLargeV3Turbo:
            directory = self.whisperBase
        case .system:
            reply(nil)
            return
        }
        Task {
            await self.models.unload(model)
            do {
                if FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.removeItem(at: directory)
                }
                reply(nil)
            } catch {
                reply(error.localizedDescription)
            }
        }
    }

    func transcribe(_ model: String, samples: Data, language: String?, reply: @escaping (String?, String?) -> Void) {
        guard let model = TauSpeechModel(rawValue: model), model.isDownloadable else {
            reply(nil, "unknown model")
            return
        }
        guard self.isInstalled(model) else {
            reply(nil, "model is not downloaded")
            return
        }
        let floats: [Float] = samples.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        let language = language.map { String($0.prefix(2)).lowercased() }
        Task {
            do {
                switch model {
                case .parakeetV3:
                    let manager = try await self.models.parakeetManager(directory: self.parakeetDirectory)
                    var decoderState = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
                    let result = try await manager.transcribe(floats, decoderState: &decoderState, language: language.flatMap(Language.init(rawValue:)))
                    reply(result.text, nil)
                case .whisperLargeV3Turbo:
                    let kit = try await self.models.whisperKit(folder: self.whisperFolder)
                    let options = DecodingOptions(language: language)
                    let results = await kit.transcribe(audioArrays: [floats], decodeOptions: options)
                    let text = (results.first ?? nil)?.map { $0.text }.joined(separator: " ") ?? ""
                    reply(text.trimmingCharacters(in: .whitespacesAndNewlines), nil)
                case .system:
                    reply(nil, "unsupported")
                }
            } catch {
                reply(nil, error.localizedDescription)
            }
        }
    }
}

private final class TauSpeechListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: TauSpeechServiceProtocol.self)
        connection.exportedObject = tauSpeechService
        connection.resume()
        return true
    }
}

private let tauSpeechService = TauSpeechService()
private let tauSpeechListenerDelegate = TauSpeechListenerDelegate()

public func runTauSpeechService() -> Never {
    let listener = NSXPCListener.service()
    listener.delegate = tauSpeechListenerDelegate
    listener.resume()
    exit(EXIT_FAILURE)
}
