import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox

public struct TauDangerousConsent: Codable, Equatable {
    public enum Decision: String, Codable {
        case enabled
        case disabled
    }

    public var version: Int
    public var decision: Decision
    public var date: Date

    public init(version: Int, decision: Decision, date: Date) {
        self.version = version
        self.decision = decision
        self.date = date
    }
}

public struct TauGhostSettings: Codable, Equatable {
    public var hideReadReceipts: Bool = false
    public var hideOnlineStatus: Bool = false
    public var hideTyping: Bool = false
    public var hideStoryViews: Bool = false
    public var hideContentConsumption: Bool = false
    public var hideChannelViews: Bool = false

    public init() {
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hideReadReceipts = try container.decodeIfPresent(Bool.self, forKey: .hideReadReceipts) ?? false
        self.hideOnlineStatus = try container.decodeIfPresent(Bool.self, forKey: .hideOnlineStatus) ?? false
        self.hideTyping = try container.decodeIfPresent(Bool.self, forKey: .hideTyping) ?? false
        self.hideStoryViews = try container.decodeIfPresent(Bool.self, forKey: .hideStoryViews) ?? false
        self.hideContentConsumption = try container.decodeIfPresent(Bool.self, forKey: .hideContentConsumption) ?? false
        self.hideChannelViews = try container.decodeIfPresent(Bool.self, forKey: .hideChannelViews) ?? false
    }

    var coreFlags: TauGhostFlags {
        return TauGhostFlags(hideReadReceipts: self.hideReadReceipts, hideOnlineStatus: self.hideOnlineStatus, hideTyping: self.hideTyping, hideStoryViews: self.hideStoryViews, hideContentConsumption: self.hideContentConsumption, hideChannelViews: self.hideChannelViews)
    }
}

public struct TauSettingsValues: Codable, Equatable {
    public var dangerousConsent: TauDangerousConsent?
    public var dangerousFeaturesEnabled: Bool = true
    public var ghost = TauGhostSettings()
    public var ghostByAccount: [Int64: TauGhostSettings] = [:]
    public var keepDeletedMessages: Bool = false
    public var keepEditHistory: Bool = false
    public var bypassContentProtection: Bool = false
    public var viewOnceWithoutMarking: Bool = false
    public var viewOnceInSecretChats: Bool = false
    public var showSelfDestructingOnMac: Bool = false
    public var lockedChats: [Int64] = []
    public var touchIdChats: [Int64] = []
    public var mcpEnabled: Bool = false
    public var mcpPort: Int = 19815
    public var mcpAllowSending: Bool = false
    public var mcpConfirmSending: Bool = true
    public var mcpTrustedChats: [Int64] = []
    public var showMessageSeconds: Bool = false
    public var hideStoriesInChatList: Bool = false
    public var appIcon: String?
    public var oledMode: Bool = false
    public var oledThemeSnapshot: Data?

    public init() {
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dangerousConsent = try container.decodeIfPresent(TauDangerousConsent.self, forKey: .dangerousConsent)
        self.dangerousFeaturesEnabled = try container.decodeIfPresent(Bool.self, forKey: .dangerousFeaturesEnabled) ?? true
        self.ghost = try container.decodeIfPresent(TauGhostSettings.self, forKey: .ghost) ?? TauGhostSettings()
        self.ghostByAccount = try container.decodeIfPresent([Int64: TauGhostSettings].self, forKey: .ghostByAccount) ?? [:]
        self.keepDeletedMessages = try container.decodeIfPresent(Bool.self, forKey: .keepDeletedMessages) ?? false
        self.keepEditHistory = try container.decodeIfPresent(Bool.self, forKey: .keepEditHistory) ?? false
        self.bypassContentProtection = try container.decodeIfPresent(Bool.self, forKey: .bypassContentProtection) ?? false
        self.viewOnceWithoutMarking = try container.decodeIfPresent(Bool.self, forKey: .viewOnceWithoutMarking) ?? false
        self.viewOnceInSecretChats = try container.decodeIfPresent(Bool.self, forKey: .viewOnceInSecretChats) ?? false
        self.showSelfDestructingOnMac = try container.decodeIfPresent(Bool.self, forKey: .showSelfDestructingOnMac) ?? false
        self.lockedChats = try container.decodeIfPresent([Int64].self, forKey: .lockedChats) ?? []
        self.touchIdChats = try container.decodeIfPresent([Int64].self, forKey: .touchIdChats) ?? []
        self.mcpEnabled = try container.decodeIfPresent(Bool.self, forKey: .mcpEnabled) ?? false
        self.mcpPort = try container.decodeIfPresent(Int.self, forKey: .mcpPort) ?? 19815
        self.mcpAllowSending = try container.decodeIfPresent(Bool.self, forKey: .mcpAllowSending) ?? false
        self.mcpConfirmSending = try container.decodeIfPresent(Bool.self, forKey: .mcpConfirmSending) ?? true
        self.mcpTrustedChats = try container.decodeIfPresent([Int64].self, forKey: .mcpTrustedChats) ?? []
        self.showMessageSeconds = try container.decodeIfPresent(Bool.self, forKey: .showMessageSeconds) ?? false
        self.hideStoriesInChatList = try container.decodeIfPresent(Bool.self, forKey: .hideStoriesInChatList) ?? false
        self.appIcon = try container.decodeIfPresent(String.self, forKey: .appIcon)
        self.oledMode = try container.decodeIfPresent(Bool.self, forKey: .oledMode) ?? false
        self.oledThemeSnapshot = try container.decodeIfPresent(Data.self, forKey: .oledThemeSnapshot)
    }

    public var hasValidDangerousConsent: Bool {
        guard let consent = self.dangerousConsent else {
            return false
        }
        return consent.version >= TauSettings.dangerousConsentVersion && consent.decision == .enabled
    }

    public var dangerousFeaturesAllowed: Bool {
        return self.hasValidDangerousConsent && self.dangerousFeaturesEnabled
    }

    public var needsDangerousConsent: Bool {
        guard let consent = self.dangerousConsent else {
            return true
        }
        return consent.version < TauSettings.dangerousConsentVersion
    }

    var coreFlags: TauCoreFlags {
        var ghostByAccount: [PeerId: TauGhostFlags] = [:]
        for (id, ghost) in self.ghostByAccount {
            ghostByAccount[PeerId(id)] = ghost.coreFlags
        }
        return TauCoreFlags(dangerousFeaturesAllowed: self.dangerousFeaturesAllowed, ghost: self.ghost.coreFlags, ghostByAccount: ghostByAccount, keepDeletedMessages: self.keepDeletedMessages, keepEditHistory: self.keepEditHistory, bypassContentProtection: self.bypassContentProtection, viewOnceWithoutMarking: self.viewOnceWithoutMarking, viewOnceInSecretChats: self.viewOnceInSecretChats)
    }
}

public final class TauSettings {
    public static let dangerousConsentVersion = 1
    public static let shared = TauSettings(defaults: .standard)

    private static let storageKey = "taugram.settings"

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var values: TauSettingsValues
    private let valuesPromise: ValuePromise<TauSettingsValues>

    private init(defaults: UserDefaults) {
        self.defaults = defaults
        let values: TauSettingsValues
        if let data = defaults.data(forKey: TauSettings.storageKey), let decoded = try? JSONDecoder().decode(TauSettingsValues.self, from: data) {
            values = decoded
        } else {
            values = TauSettingsValues()
        }
        self.values = values
        self.valuesPromise = ValuePromise(values, ignoreRepeated: true)
        TauCoreSettings.shared.set(values.coreFlags)
    }

    public func installInCore() {
        TauCoreSettings.shared.set(self.current.coreFlags)
    }

    public var current: TauSettingsValues {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.values
    }

    public var signal: Signal<TauSettingsValues, NoError> {
        return self.valuesPromise.get()
    }

    public func update(_ f: (TauSettingsValues) -> TauSettingsValues) {
        self.lock.lock()
        let updated = f(self.values)
        let changed = updated != self.values
        self.values = updated
        self.lock.unlock()
        guard changed else {
            return
        }
        TauCoreSettings.shared.set(updated.coreFlags)
        if let data = try? JSONEncoder().encode(updated) {
            self.defaults.set(data, forKey: TauSettings.storageKey)
        }
        self.valuesPromise.set(updated)
    }

    public func recordDangerousConsent(_ decision: TauDangerousConsent.Decision) {
        self.update { current in
            var current = current
            current.dangerousConsent = TauDangerousConsent(version: TauSettings.dangerousConsentVersion, decision: decision, date: Date())
            current.dangerousFeaturesEnabled = decision == .enabled
            return current
        }
    }
}
