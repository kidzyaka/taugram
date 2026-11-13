import Foundation

public let tauSpeechServiceName = "com.kidzyaka.taugram.Speech"
public let tauSpeechSampleRate: Double = 16000

public enum TauSpeechModel: String, CaseIterable {
    case system
    case parakeetV3
    case whisperLargeV3Turbo

    public var isDownloadable: Bool {
        return self != .system
    }

    //TODOLANG
    public var title: String {
        switch self {
        case .system:
            return "macOS Speech Recognition"
        case .parakeetV3:
            return "Parakeet TDT v3"
        case .whisperLargeV3Turbo:
            return "Whisper Large v3 Turbo"
        }
    }

    //TODOLANG
    public var info: String {
        switch self {
        case .system:
            return "Built in, no download. Quality depends on the language."
        case .parakeetV3:
            return "NVIDIA · 25 European languages including Russian · about 500 MB · very fast on the Neural Engine"
        case .whisperLargeV3Turbo:
            return "OpenAI · 99 languages · about 630 MB · most accurate, slower"
        }
    }
}

@objc public protocol TauSpeechServiceProtocol {
    func modelState(_ model: String, reply: @escaping (_ installed: Bool, _ downloading: Bool, _ progress: Double, _ error: String?) -> Void)
    func downloadModel(_ model: String, reply: @escaping (_ error: String?) -> Void)
    func cancelDownload(_ model: String)
    func deleteModel(_ model: String, reply: @escaping (_ error: String?) -> Void)
    func transcribe(_ model: String, samples: Data, language: String?, reply: @escaping (_ text: String?, _ error: String?) -> Void)
}
