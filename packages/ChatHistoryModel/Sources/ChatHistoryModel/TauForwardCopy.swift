import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramContext

private func tauIsServerProtected(_ message: Message, cachedData: CachedPeerData?) -> Bool {
    if message.isCopyProtected(ignoringTaugram: true) {
        return true
    }
    if let cachedData = cachedData as? CachedUserData {
        return cachedData.flags.contains(.copyProtectionEnabled) || cachedData.flags.contains(.myCopyProtectionEnabled)
    }
    return false
}

private func tauTemporaryCopy(of path: String, fileName: String?) -> String? {
    let directory = NSTemporaryDirectory() + "taugram-forward-\(Int64.random(in: 1 ... Int64.max))"
    do {
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let target = directory + "/" + (fileName?.isEmpty == false ? fileName! : "file")
        try FileManager.default.copyItem(atPath: path, toPath: target)
        return target
    } catch {
        return nil
    }
}

private func tauDownloadedPath(context: any AccountContextProtocol, message: Message, media: Media, resource: MediaResource, contentType: MediaResourceUserContentType) -> Signal<String?, NoError> {
    let mediaBox = context.account.postbox.mediaBox
    let reference = AnyMediaReference.message(message: MessageReference(message), media: media).resourceReference(resource)
    let fetch = fetchedMediaResource(mediaBox: mediaBox, userLocation: .peer(message.id.peerId), userContentType: contentType, reference: reference)
    let data = mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> filter { $0.complete }
        |> take(1)
        |> map { data -> String? in return data.path }
    return Signal { subscriber in
        let fetchDisposable = fetch.start()
        let dataDisposable = data.start(next: { path in
            subscriber.putNext(path)
            subscriber.putCompletion()
        })
        return ActionDisposable {
            fetchDisposable.dispose()
            dataDisposable.dispose()
        }
    }
}

private func tauCopiedMedia(context: any AccountContextProtocol, message: Message) -> Signal<Media?, NoError> {
    for media in message.media {
        if let image = media as? TelegramMediaImage, let representation = largestImageRepresentation(image.representations) {
            return tauDownloadedPath(context: context, message: message, media: image, resource: representation.resource, contentType: .image)
                |> map { path -> Media? in
                    guard let path, let copy = tauTemporaryCopy(of: path, fileName: "photo.jpg") else {
                        return nil
                    }
                    let randomId = Int64.random(in: Int64.min ... Int64.max)
                    let resource = LocalFileReferenceMediaResource(localFilePath: copy, randomId: randomId, isUniquelyReferencedTemporaryFile: true)
                    return TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: randomId), representations: [TelegramMediaImageRepresentation(dimensions: representation.dimensions, resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                }
        }
        if let file = media as? TelegramMediaFile {
            return tauDownloadedPath(context: context, message: message, media: file, resource: file.resource, contentType: .file)
                |> map { path -> Media? in
                    guard let path, let copy = tauTemporaryCopy(of: path, fileName: file.fileName) else {
                        return nil
                    }
                    let randomId = Int64.random(in: Int64.min ... Int64.max)
                    let resource = LocalFileReferenceMediaResource(localFilePath: copy, randomId: randomId, isUniquelyReferencedTemporaryFile: true, size: file.size)
                    return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: file.immediateThumbnailData, mimeType: file.mimeType, size: file.size, attributes: file.attributes, alternativeRepresentations: [])
                }
        }
        if media is TelegramMediaMap || media is TelegramMediaContact {
            return .single(media)
        }
    }
    return .single(nil)
}

private func tauCopyMessage(context: any AccountContextProtocol, message: Message, threadId: Int64?, attributes: [MessageAttribute]) -> Signal<EnqueueMessage?, NoError> {
    return tauCopiedMedia(context: context, message: message) |> map { media -> EnqueueMessage? in
        if media == nil && message.text.isEmpty {
            return nil
        }
        var messageAttributes = attributes
        for attribute in message.attributes {
            if let attribute = attribute as? TextEntitiesMessageAttribute, !attribute.entities.isEmpty {
                messageAttributes.append(TextEntitiesMessageAttribute(entities: attribute.entities))
            }
        }
        return .message(text: message.text, attributes: messageAttributes, inlineStickers: [:], mediaReference: media.flatMap { AnyMediaReference.standalone(media: $0) }, threadId: threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: message.groupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: [])
    }
}

func tauForwardMessages(messageIds: [MessageId], context: any AccountContextProtocol, peerId: PeerId, threadId: Int64?, attributes: [MessageAttribute], regular: Signal<[MessageId?], NoError>) -> Signal<[MessageId?], NoError> {
    guard TauCoreSettings.shared.bypassesContentProtection else {
        return regular
    }
    let attributes = attributes.filter { !($0 is ForwardOptionsMessageAttribute) }
    return context.account.postbox.transaction { transaction -> (messages: [Message], isProtected: Bool) in
        var messages: [Message] = []
        var isProtected = false
        for id in messageIds.sorted() {
            if let message = transaction.getMessage(id) {
                messages.append(message)
                if tauIsServerProtected(message, cachedData: transaction.getPeerCachedData(peerId: id.peerId)) {
                    isProtected = true
                }
            }
        }
        return (messages, isProtected)
    }
    |> mapToSignal { messages, isProtected -> Signal<[MessageId?], NoError> in
        guard isProtected else {
            return regular
        }
        return combineLatest(messages.map { tauCopyMessage(context: context, message: $0, threadId: threadId, attributes: attributes) })
            |> mapToSignal { copies -> Signal<[MessageId?], NoError> in
                return enqueueMessages(account: context.account, peerId: peerId, messages: copies.compactMap { $0 })
            }
    }
}
