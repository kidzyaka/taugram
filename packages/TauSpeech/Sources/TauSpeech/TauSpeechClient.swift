import Foundation
import SwiftSignalKit
import TauSpeechProtocol

public struct TauSpeechModelState: Equatable {
    public var installed: Bool
    public var downloading: Bool
    public var progress: Double
    public var error: String?

    public static let unknown = TauSpeechModelState(installed: false, downloading: false, progress: 0, error: nil)
}

public enum TauSpeechError: Error {
    case unavailable
    case failed(String)
}

public final class TauSpeechClient {
    public static let shared = TauSpeechClient()

    private let queue = Queue(name: "TauSpeechClient")
    private var connection: NSXPCConnection?

    public var isSupported: Bool {
        if #available(macOS 14.0, *) {
            return true
        } else {
            return false
        }
    }

    private init() {
    }

    private func service(_ failure: @escaping (Error) -> Void) -> TauSpeechServiceProtocol? {
        guard self.isSupported else {
            return nil
        }
        let connection: NSXPCConnection
        if let current = self.connection {
            connection = current
        } else {
            connection = NSXPCConnection(serviceName: tauSpeechServiceName)
            connection.remoteObjectInterface = NSXPCInterface(with: TauSpeechServiceProtocol.self)
            connection.invalidationHandler = { [weak self] in
                self?.queue.async {
                    self?.connection = nil
                }
            }
            connection.resume()
            self.connection = connection
        }
        return connection.remoteObjectProxyWithErrorHandler(failure) as? TauSpeechServiceProtocol
    }

    public func state(_ model: TauSpeechModel) -> Signal<TauSpeechModelState, NoError> {
        let once: Signal<TauSpeechModelState, NoError> = Signal { subscriber in
            self.queue.async {
                let service = self.service({ error in
                    subscriber.putNext(TauSpeechModelState(installed: false, downloading: false, progress: 0, error: error.localizedDescription))
                    subscriber.putCompletion()
                })
                guard let service else {
                    subscriber.putNext(.unknown)
                    subscriber.putCompletion()
                    return
                }
                service.modelState(model.rawValue, reply: { installed, downloading, progress, error in
                    subscriber.putNext(TauSpeechModelState(installed: installed, downloading: downloading, progress: progress, error: error))
                    subscriber.putCompletion()
                })
            }
            return EmptyDisposable
        }
        return (once |> then(.complete() |> delay(0.5, queue: self.queue))) |> restart |> distinctUntilChanged
    }

    public func download(_ model: TauSpeechModel) {
        self.queue.async {
            self.service({ _ in })?.downloadModel(model.rawValue, reply: { _ in })
        }
    }

    public func cancelDownload(_ model: TauSpeechModel) {
        self.queue.async {
            self.service({ _ in })?.cancelDownload(model.rawValue)
        }
    }

    public func delete(_ model: TauSpeechModel) {
        self.queue.async {
            self.service({ _ in })?.deleteModel(model.rawValue, reply: { _ in })
        }
    }

    public func transcribe(_ model: TauSpeechModel, samples: [Float], language: String?) -> Signal<String, TauSpeechError> {
        return Signal { subscriber in
            self.queue.async {
                let service = self.service({ error in
                    subscriber.putError(.failed(error.localizedDescription))
                })
                guard let service else {
                    subscriber.putError(.unavailable)
                    return
                }
                let data = samples.withUnsafeBufferPointer { Data(buffer: $0) }
                service.transcribe(model.rawValue, samples: data, language: language, reply: { text, error in
                    if let text {
                        subscriber.putNext(text)
                        subscriber.putCompletion()
                    } else {
                        subscriber.putError(.failed(error ?? "unknown"))
                    }
                })
            }
            return EmptyDisposable
        }
    }
}
