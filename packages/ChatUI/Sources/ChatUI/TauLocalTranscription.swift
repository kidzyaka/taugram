import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramContext
import TelegramMediaUtils
import ChatHistoryModel
import TauSettings
import TauSpeech
import TGUIKit
import OpusBinding

func tauTranscribesLocally(_ message: Message) -> Bool {
    guard #available(macOS 10.15, *), TauSettings.shared.current.localTranscription else {
        return false
    }
    guard let file = message.media.first as? TelegramMediaFile else {
        return false
    }
    return file.isVoice
}

func tauLocalTranscription(context: any AccountContextProtocol, message: Message) -> Signal<Bool, NoError> {
    guard #available(macOS 10.15, *), let file = message.media.first as? TelegramMediaFile else {
        return .single(false)
    }
    let messageId = message.id
    let peerId = message.id.peerId
    let fetch = messageMediaFileInteractiveFetched(context: context, messageId: messageId, messageReference: MessageReference(message), file: file, userInitiated: true)
    let data = context.account.postbox.mediaBox.resourceData(file.resource) |> filter { $0.complete } |> take(1)

    let speechModel = TauSpeechModel(rawValue: TauSettings.shared.current.transcriptionModel) ?? .system
    let transcription = data |> castError(ChatDictationError.self) |> mapToSignal { data -> Signal<String, ChatDictationError> in
        guard let clip = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
            return .fail(.unavailable)
        }
        let language = chatDictationLanguage(context: context, peerId: peerId)
        if speechModel.isDownloadable {
            return language |> take(1) |> castError(ChatDictationError.self) |> mapToSignal { language -> Signal<String, ChatDictationError> in
                guard let samples = tauDecodeVoiceSamples(clip) else {
                    return .fail(.unavailable)
                }
                return TauSpeechClient.shared.transcribe(speechModel, samples: samples, language: language)
                |> mapError { _ -> ChatDictationError in
                    return .failed
                }
            }
        }
        let suggestions = context.engine.messages.getTranscriptionLanguages(peerId: peerId)
        return combineLatest(queue: .mainQueue(), requestSpeechRecognitionPermission(), language, suggestions)
        |> castError(ChatDictationError.self)
        |> mapToSignal { granted, language, suggestions -> Signal<String, ChatDictationError> in
            guard granted else {
                return .fail(.speechDenied)
            }
            let source = ChatDictationRecordingSource(audio: .clip(clip, trimRange: nil))
            return nativeRecordedAudioTranscription { completion in
                ChatDictationEngineFactory.make(selection: ChatInputDictationLanguage.selected, chatLanguage: language, suggestedLanguages: suggestions, requiresOnDevice: true, source: source, completion: completion)
            }
        }
    }

    let stored = transcription
    |> mapToSignal { text -> Signal<Bool, ChatDictationError> in
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return context.engine.messages.storeLocallyTranscribedAudio(messageId: messageId, text: trimmed, isFinal: true, error: trimmed.isEmpty ? .generic : nil)
        |> castError(ChatDictationError.self)
        |> map { _ -> Bool in }
        |> then(.single(!trimmed.isEmpty))
    }
    |> `catch` { _ -> Signal<Bool, NoError> in
        return context.engine.messages.storeLocallyTranscribedAudio(messageId: messageId, text: "", isFinal: true, error: .generic)
        |> map { _ -> Bool in }
        |> then(.single(false))
    }

    return Signal { subscriber in
        let fetchDisposable = fetch.start()
        let disposable = stored.start(next: { value in
            subscriber.putNext(value)
        }, completed: {
            subscriber.putCompletion()
        })
        return ActionDisposable {
            fetchDisposable.dispose()
            disposable.dispose()
        }
    }
}

private func tauDecodeVoiceSamples(_ clip: Data) -> [Float]? {
    let path = NSTemporaryDirectory() + "tau-voice-\(arc4random64()).ogg"
    let url = URL(fileURLWithPath: path)
    guard (try? clip.write(to: url)) != nil else {
        return nil
    }
    defer {
        try? FileManager.default.removeItem(at: url)
    }
    guard let reader = OggOpusReader(path: path) else {
        return nil
    }
    let capacity = 4800
    let buffer = UnsafeMutablePointer<Int16>.allocate(capacity: capacity)
    defer {
        buffer.deallocate()
    }
    var result: [Float] = []
    var accumulator: Float = 0
    var accumulated = 0
    while true {
        let count = Int(reader.read(UnsafeMutableRawPointer(buffer), bufSize: Int32(capacity)))
        if count <= 0 || count > capacity {
            break
        }
        for i in 0 ..< count {
            accumulator += Float(buffer[i]) / 32768
            accumulated += 1
            if accumulated == 3 {
                result.append(accumulator / 3)
                accumulator = 0
                accumulated = 0
            }
        }
    }
    return result.isEmpty ? nil : result
}
