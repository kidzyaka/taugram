import Cocoa
import TGUIKit
import SettingsUI
import TauSettingsUI
import ThemeSettings
import ChatHistoryModel
import InAppSettings
import Localization
import TelegramTheme
import TelegramContext
import Postbox
import TelegramCore
import TelegramUtils
import TauSettings
import AlertsUI
import SwiftSignalKit
import Translate

private let tauSettingsIcon = generateTauSettingsIcon()

private final class TauGoogleTranslationService: ExperimentalInternalTranslationService {
    func translate(texts: [AnyHashable: String], fromLang: String, toLang: String) -> Signal<[AnyHashable: String]?, NoError> {
        var signal: Signal<[AnyHashable: String], NoError> = .single([:])
        for (key, text) in texts {
            signal = signal |> mapToSignal { current -> Signal<[AnyHashable: String], NoError> in
                if text.isEmpty {
                    return .single(current)
                }
                return Translate.translateText(text: text, from: fromLang == "auto" ? nil : fromLang, to: toLang)
                |> map { value -> [AnyHashable: String] in
                    var current = current
                    current[key] = value.result
                    return current
                }
                |> `catch` { _ -> Signal<[AnyHashable: String], NoError> in
                    return .single(current)
                }
            }
        }
        return signal |> map { Optional($0) }
    }
}

func installTaugramSettingsHooks(_ hooks: inout SettingsNavigationHooks) {
    var tauHooks = TauSettingsUIHooks()
    tauHooks.makeChatPreviewItems = { size, context, theme in
        return makeTauChatPreviewItems(size: size, context: context, theme: theme)
    }
    TauSettingsUIHooks.install(tauHooks)
    engineExperimentalInternalTranslationService = TauGoogleTranslationService()
    themeSettingsUpdateGuard = { current, updated in
        return tauOLEDThemeGuard(current: current, updated: updated)
    }
    DispatchQueue.main.async {
        TauAppIconManager.applyStored()
        installTauGhostMenuItem()
    }
    hooks.taugram = SettingsTaugramEntry(icon: {
        return tauSettingsIcon
    }, makeController: { context in
        return TauSettingsController(context: context)
    })
}

func presentTaugramConsentIfNeeded(window: Window) {
    DispatchQueue.main.async {
        installTauChatLock(window: window)
        showTauConsentIfNeeded(for: window)
    }
}

private func makeTauChatPreviewItems(size: NSSize, context: any AccountContextProtocol, theme: TelegramPresentationTheme) -> [TableRowItem] {
    guard let context = context as? AccountContext else {
        return []
    }
    let chatInteraction = ChatInteraction(chatLocation: .peer(PeerId(0)), context: context, isLogInteraction: false, disableSelectAbility: true)
    let user1 = TelegramUser(id: PeerId(1), accessHash: nil, firstName: strings().appearanceSettingsChatPreviewUserName1, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
    let user2 = TelegramUser(id: PeerId(2), accessHash: nil, firstName: strings().appearanceSettingsChatPreviewUserName2, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
    let peers = SimpleDictionary<PeerId, Peer>([user1.id: user1, user2.id: user2])
    let first = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: user1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: 60 * 18 + 60 * 60 * 18, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: user1, text: strings().appearanceSettingsChatPreview1, attributes: [], media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
    let second = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: user1.id, namespace: 0, id: 0), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: 60 * 20 + 60 * 60 * 18, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: user2, text: strings().appearanceSettingsChatPreview2, attributes: [ReplyMessageAttribute(messageId: first.id, threadMessageId: nil, quote: nil, isQuote: false, innerSubject: nil)], media: [], peers: peers, associatedMessages: SimpleDictionary([first.id: first]), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
    let third = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: user1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: 60 * 22 + 60 * 60 * 18, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: user1, text: strings().appearanceSettingsChatPreview3, attributes: [], media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
    return [first, second, third].map { message in
        let entry: ChatHistoryEntry = .MessageEntry(message, MessageIndex(message), true, theme.bubbled ? .bubble : .list, .Full(rank: nil, rankType: .none, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(), AutoplayMediaPreferences.defaultSettings))
        return ChatRowItem.item(size, from: entry, interaction: chatInteraction, theme: theme)
    }
}

private let mcpSendLimitPerMinute = 10
private var mcpSendTimestamps: [Date] = []
private var mcpSettingsDisposable: Disposable?

private func mcpJSON(_ object: Any) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
        return "{}"
    }
    return String(data: data, encoding: .utf8) ?? "{}"
}

private func mcpPeerId(_ arguments: [String: Any]) -> PeerId? {
    if let value = arguments["chat_id"] as? String, let id = Int64(value) {
        return PeerId(id)
    }
    if let value = arguments["chat_id"] as? NSNumber {
        return PeerId(value.int64Value)
    }
    return nil
}

private func mcpInt(_ arguments: [String: Any], _ key: String, default value: Int, max maximum: Int) -> Int {
    if let number = arguments[key] as? NSNumber {
        return min(maximum, max(1, number.intValue))
    }
    return value
}

private func mcpPeerType(_ peer: Peer) -> String {
    if let user = peer as? TelegramUser {
        return user.botInfo != nil ? "bot" : "user"
    }
    if peer is TelegramGroup {
        return "group"
    }
    if let channel = peer as? TelegramChannel {
        if case .group = channel.info {
            return "supergroup"
        }
        return "channel"
    }
    if peer is TelegramSecretChat {
        return "secret_chat"
    }
    return "chat"
}

private func mcpPeer(_ peer: Peer, accountPeerId: PeerId? = nil) -> [String: Any] {
    var result: [String: Any] = [
        "chat_id": "\(peer.id.toInt64())",
        "title": peer.id == accountPeerId ? "Saved Messages" : peer.displayTitle,
        "type": mcpPeerType(peer),
    ]
    if let username = peer.addressName {
        result["username"] = username
    }
    return result
}

private func mcpMessage(_ message: Message) -> [String: Any] {
    var result: [String: Any] = [
        "id": Int(message.id.id),
        "date": ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(message.timestamp))),
        "outgoing": !message.flags.contains(.Incoming),
        "text": message.text,
    ]
    if let author = message.author {
        result["from"] = author.displayTitle
    }
    if !message.media.isEmpty {
        result["media"] = message.media.map { String(describing: type(of: $0)).replacingOccurrences(of: "TelegramMedia", with: "").lowercased() }
    }
    for attribute in message.attributes {
        if let reply = attribute as? ReplyMessageAttribute {
            result["reply_to"] = Int(reply.messageId.id)
        }
    }
    if message.tauDeletedAttribute != nil {
        result["deleted"] = true
    }
    return result
}

private func mcpForbiddenChat(_ peerId: PeerId) -> TauMCPError? {
    if TauChatLock.shared.isLockedChat(peerId) {
        //TODOLANG
        return .forbidden("This chat is locked in Taugram and is not available to agents.")
    }
    if peerId.namespace == Namespaces.Peer.SecretChat {
        //TODOLANG
        return .forbidden("Secret chats are not available to agents.")
    }
    return nil
}

private func makeMCPTools(context: AccountContext, window: Window) -> [TauMCPTool] {
    let chatIdSchema: [String: Any] = ["type": "string", "description": "Chat id from list_chats"]

    let listChats = TauMCPTool(name: "list_chats", description: "List the user's chats in chat list order (pinned chats first, then newest), with unread counts and the last message.", inputSchema: [
        "type": "object",
        "properties": [
            "limit": ["type": "integer", "description": "Number of chats, 1-200, default 50"],
            "unread_only": ["type": "boolean", "description": "Only chats with unread messages"],
        ],
    ], call: { arguments, completion in
        let limit = mcpInt(arguments, "limit", default: 50, max: 200)
        let unreadOnly = arguments["unread_only"] as? Bool ?? false
        _ = (context.engine.messages.chatList(group: .root, count: unreadOnly ? 200 : limit + 10) |> take(1)).start(next: { list in
            var chats: [[String: Any]] = []
            for item in list.items.reversed() {
                guard chats.count < limit else {
                    break
                }
                guard let peer = item.renderedPeer.chatMainPeer?._asPeer(), mcpForbiddenChat(item.renderedPeer.peerId) == nil else {
                    continue
                }
                let unread = Int(item.readCounters?.count ?? 0)
                if unreadOnly && unread == 0 {
                    continue
                }
                var chat = mcpPeer(peer, accountPeerId: context.peerId)
                chat["chat_id"] = "\(item.renderedPeer.peerId.toInt64())"
                chat["unread"] = unread
                chat["muted"] = item.isMuted
                if let message = item.messages.last?._asMessage() {
                    chat["last_message"] = mcpMessage(message)
                }
                chats.append(chat)
            }
            completion(.success(mcpJSON(chats)))
        })
    })

    let getChat = TauMCPTool(name: "get_chat", description: "Get a chat or user by chat_id.", inputSchema: [
        "type": "object",
        "properties": ["chat_id": chatIdSchema],
        "required": ["chat_id"],
    ], call: { arguments, completion in
        guard let peerId = mcpPeerId(arguments) else {
            completion(.failure(.invalidParams("chat_id is required")))
            return
        }
        if let error = mcpForbiddenChat(peerId) {
            completion(.failure(error))
            return
        }
        _ = context.account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(peerId)
        }.start(next: { peer in
            if let peer {
                completion(.success(mcpJSON(mcpPeer(peer, accountPeerId: context.peerId))))
            } else {
                completion(.failure(.notFound("No such chat")))
            }
        })
    })

    let readHistory = TauMCPTool(name: "read_history", description: "Read messages of a chat stored on this Mac, oldest first. Reading never marks messages as read.", inputSchema: [
        "type": "object",
        "properties": [
            "chat_id": chatIdSchema,
            "limit": ["type": "integer", "description": "Number of messages, 1-100, default 30"],
            "before_id": ["type": "integer", "description": "Return messages older than this message id"],
        ],
        "required": ["chat_id"],
    ], call: { arguments, completion in
        guard let peerId = mcpPeerId(arguments) else {
            completion(.failure(.invalidParams("chat_id is required")))
            return
        }
        if let error = mcpForbiddenChat(peerId) {
            completion(.failure(error))
            return
        }
        let limit = mcpInt(arguments, "limit", default: 30, max: 100)
        let beforeId = (arguments["before_id"] as? NSNumber)?.int32Value
        _ = context.account.postbox.transaction { transaction -> [Message] in
            var from = MessageIndex.upperBound(peerId: peerId, namespace: Namespaces.Message.Cloud)
            if let beforeId, let message = transaction.getMessage(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: beforeId)) {
                from = MessageIndex(message)
            }
            return transaction.getMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, from: from, includeFrom: false, to: MessageIndex.lowerBound(peerId: peerId, namespace: Namespaces.Message.Cloud), limit: limit)
        }.start(next: { messages in
            let sorted = messages.sorted(by: { MessageIndex($0) < MessageIndex($1) })
            completion(.success(mcpJSON(sorted.map(mcpMessage))))
        })
    })

    let searchMessages = TauMCPTool(name: "search_messages", description: "Search messages in all chats or in one chat.", inputSchema: [
        "type": "object",
        "properties": [
            "query": ["type": "string"],
            "chat_id": chatIdSchema,
            "limit": ["type": "integer", "description": "1-50, default 20"],
        ],
        "required": ["query"],
    ], call: { arguments, completion in
        guard let query = arguments["query"] as? String, !query.isEmpty else {
            completion(.failure(.invalidParams("query is required")))
            return
        }
        let limit = mcpInt(arguments, "limit", default: 20, max: 50)
        let location: SearchMessagesLocation
        if let peerId = mcpPeerId(arguments) {
            if let error = mcpForbiddenChat(peerId) {
                completion(.failure(error))
                return
            }
            location = .peer(peerId: peerId, fromId: nil, tags: nil, reactions: nil, threadId: nil, minDate: nil, maxDate: nil)
        } else {
            location = .general(scope: .everywhere, groupId: nil, tags: nil, minDate: nil, maxDate: nil, folderId: nil, communityId: nil)
        }
        _ = (context.engine.messages.searchMessages(location: location, query: query, state: nil, limit: Int32(limit)) |> take(1)).start(next: { result, _ in
            let messages = result.messages.filter { mcpForbiddenChat($0.id.peerId) == nil }.map { message -> [String: Any] in
                var item = mcpMessage(message)
                item["chat_id"] = "\(message.id.peerId.toInt64())"
                if let peer = message.peers[message.id.peerId] {
                    item["chat_title"] = peer.displayTitle
                }
                return item
            }
            completion(.success(mcpJSON(messages)))
        })
    })

    let unreadSummary = TauMCPTool(name: "get_unread_summary", description: "Chats with unread messages and their counts.", inputSchema: [
        "type": "object",
        "properties": [:],
    ], call: { _, completion in
        _ = (context.engine.messages.chatList(group: .root, count: 200) |> take(1)).start(next: { list in
            var total = 0
            var chats: [[String: Any]] = []
            for item in list.items.reversed() {
                let unread = Int(item.readCounters?.count ?? 0)
                guard unread > 0, let peer = item.renderedPeer.chatMainPeer?._asPeer(), mcpForbiddenChat(item.renderedPeer.peerId) == nil else {
                    continue
                }
                total += unread
                var chat = mcpPeer(peer)
                chat["chat_id"] = "\(item.renderedPeer.peerId.toInt64())"
                chat["unread"] = unread
                chat["muted"] = item.isMuted
                chats.append(chat)
            }
            completion(.success(mcpJSON(["total_unread": total, "chats": chats])))
        })
    })

    let sendMessage = TauMCPTool(name: "send_message", description: "Send a text message to a chat. If the user confirms messages, the call returns status awaiting_confirmation at once and the message is sent only after the user approves it in Taugram; never resend it, check read_history instead.", inputSchema: [
        "type": "object",
        "properties": [
            "chat_id": chatIdSchema,
            "text": ["type": "string"],
            "reply_to": ["type": "integer", "description": "Message id to reply to"],
        ],
        "required": ["chat_id", "text"],
    ], isEnabled: {
        return TauSettings.shared.current.mcpAllowSending
    }, call: { arguments, completion in
        guard let peerId = mcpPeerId(arguments), let text = arguments["text"] as? String, !text.isEmpty else {
            completion(.failure(.invalidParams("chat_id and text are required")))
            return
        }
        if let error = mcpForbiddenChat(peerId) {
            completion(.failure(error))
            return
        }
        let replyTo = (arguments["reply_to"] as? NSNumber).map { MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0.int32Value) }
        Queue.mainQueue().async {
            let now = Date()
            mcpSendTimestamps = mcpSendTimestamps.filter { now.timeIntervalSince($0) < 60 }
            guard mcpSendTimestamps.count < mcpSendLimitPerMinute else {
                //TODOLANG
                completion(.failure(.forbidden("Rate limit: at most \(mcpSendLimitPerMinute) messages per minute.")))
                return
            }
            let send: (Bool) -> Void = { reportResult in
                mcpSendTimestamps.append(Date())
                let message = EnqueueMessage.message(text: text, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: replyTo.map { EngineMessageReplySubject(messageId: $0, quote: nil, innerSubject: nil) }, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start(next: { ids in
                    let queued = ids.first.flatMap { $0 } != nil
                    TauMCPServer.shared.log("send_message", detail: queued ? "confirmed and sent" : "confirmed, not queued", ok: queued)
                    guard reportResult else {
                        return
                    }
                    if let id = ids.first, let id {
                        completion(.success(mcpJSON(["sent": true, "local_id": Int(id.id)])))
                    } else {
                        completion(.failure(.failed("The message was not queued")))
                    }
                })
            }
            let settings = TauSettings.shared.current
            guard settings.mcpConfirmSending, !settings.mcpTrustedChats.contains(peerId.toInt64()) else {
                send(true)
                return
            }
            //TODOLANG
            completion(.success(mcpJSON(["sent": false, "status": "awaiting_confirmation", "note": "The user must confirm this message in Taugram. Do not send it again; check read_history later to see whether it was sent."])))
            _ = (context.account.postbox.transaction { $0.getPeer(peerId) } |> deliverOnMainQueue).start(next: { peer in
                //TODOLANG
                let title = peerId == context.peerId ? "Saved Messages" : (peer?.displayTitle ?? "\(peerId.toInt64())")
                //TODOLANG
                verifyAlert(for: window, header: "An agent wants to send a message", information: "To \(title):\n\n\(text)", ok: "Send", option: "Don't ask again for this chat", optionIsSelected: false, successHandler: { result in
                    if result == .thrid {
                        TauSettings.shared.update { current in
                            var current = current
                            if !current.mcpTrustedChats.contains(peerId.toInt64()) {
                                current.mcpTrustedChats.append(peerId.toInt64())
                            }
                            return current
                        }
                        TauMCPServer.shared.log("send_message", detail: "chat \(peerId.toInt64()) trusted", ok: true)
                    }
                    send(false)
                }, cancelHandler: {
                    TauMCPServer.shared.log("send_message", detail: "declined by the user", ok: false)
                })
            })
        }
    })

    return [listChats, getChat, readHistory, searchMessages, unreadSummary, sendMessage]
}

func installTaugramMCP(context: AccountContext, window: Window) {
    TauMCPServer.shared.setTools(makeMCPTools(context: context, window: window))
    if mcpSettingsDisposable == nil {
        mcpSettingsDisposable = (TauSettings.shared.signal |> map { ($0.mcpEnabled, $0.mcpPort) } |> distinctUntilChanged(isEqual: { $0 == $1 })).start(next: { enabled, port in
            TauMCPServer.shared.update(enabled: enabled, port: port)
        })
    }
}
