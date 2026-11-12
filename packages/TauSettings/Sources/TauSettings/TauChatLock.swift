import Foundation
import Security
import CommonCrypto
import SwiftSignalKit
import Postbox

public enum TauChatLockVerifyResult: Equatable {
    case success
    case invalid
    case cooldown(Int)
}

private struct TauChatLockRecord: Codable {
    var salt: Data
    var iterations: Int
    var hash: Data
}

private struct TauChatLockKeychain {
    static let service = "com.kidzyaka.taugram.chatlock"
    static let account = "passcode"

    static func read() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    static func write(_ data: Data) -> Bool {
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private func tauRandomBytes(_ count: Int) -> Data {
    var data = Data(count: count)
    let status = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
    if status != errSecSuccess {
        for i in 0 ..< count {
            data[i] = UInt8.random(in: 0 ... 255)
        }
    }
    return data
}

private func tauDerive(code: String, salt: Data, iterations: Int) -> Data {
    let password = Array(("taugram.chatlock.v1\0" + code).utf8)
    var key = Data(count: 32)
    _ = key.withUnsafeMutableBytes { keyBytes in
        salt.withUnsafeBytes { saltBytes in
            password.withUnsafeBufferPointer { passwordBytes in
                passwordBytes.baseAddress!.withMemoryRebound(to: Int8.self, capacity: password.count) { passwordPointer in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), passwordPointer, password.count, saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations), keyBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), 32)
                }
            }
        }
    }
    return key
}

private func tauConstantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
    guard lhs.count == rhs.count else {
        return false
    }
    var difference: UInt8 = 0
    for i in 0 ..< lhs.count {
        difference |= lhs[i] ^ rhs[i]
    }
    return difference == 0
}

public final class TauChatLock {
    public static let shared = TauChatLock()

    private static let iterations = 600_000
    private static let failuresKey = "taugram.chatlock.failures"
    private static let cooldownKey = "taugram.chatlock.cooldownUntil"

    private let lock = NSLock()
    private var record: TauChatLockRecord?
    private var unlocked = Set<Int64>()
    private let changesPipe = ValuePipe<Void>()
    public var setupPasscode: ((@escaping () -> Void) -> Void)?

    private init() {
        if let data = TauChatLockKeychain.read() {
            self.record = try? JSONDecoder().decode(TauChatLockRecord.self, from: data)
        }
    }

    public var changes: Signal<Void, NoError> {
        return self.changesPipe.signal()
    }

    public var hasPasscode: Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.record != nil
    }

    public var biometricsEnabled: Bool {
        return self.hasPasscode && TauSettings.shared.current.chatLockBiometrics
    }

    public func setPasscode(_ code: String) -> Bool {
        let salt = tauRandomBytes(16)
        let record = TauChatLockRecord(salt: salt, iterations: TauChatLock.iterations, hash: tauDerive(code: code, salt: salt, iterations: TauChatLock.iterations))
        guard let data = try? JSONEncoder().encode(record), TauChatLockKeychain.write(data) else {
            return false
        }
        self.lock.lock()
        self.record = record
        self.unlocked.removeAll()
        self.lock.unlock()
        self.resetFailures()
        self.changesPipe.putNext(Void())
        return true
    }

    public func removePasscode() {
        TauChatLockKeychain.delete()
        self.lock.lock()
        self.record = nil
        self.unlocked.removeAll()
        self.lock.unlock()
        TauSettings.shared.update { current in
            var current = current
            current.lockedChats = []
            current.chatLockBiometrics = false
            return current
        }
        self.changesPipe.putNext(Void())
    }

    public var cooldownRemaining: Int {
        let until = UserDefaults.standard.double(forKey: TauChatLock.cooldownKey)
        return max(0, Int(ceil(until - Date().timeIntervalSince1970)))
    }

    public func verify(_ code: String) -> TauChatLockVerifyResult {
        let cooldown = self.cooldownRemaining
        if cooldown > 0 {
            return .cooldown(cooldown)
        }
        self.lock.lock()
        let record = self.record
        self.lock.unlock()
        guard let record else {
            return .invalid
        }
        if tauConstantTimeEqual(tauDerive(code: code, salt: record.salt, iterations: record.iterations), record.hash) {
            self.resetFailures()
            return .success
        }
        let failures = UserDefaults.standard.integer(forKey: TauChatLock.failuresKey) + 1
        UserDefaults.standard.set(failures, forKey: TauChatLock.failuresKey)
        if failures >= 5 {
            let seconds = min(3600, 30 << min(failures - 5, 7))
            UserDefaults.standard.set(Date().timeIntervalSince1970 + Double(seconds), forKey: TauChatLock.cooldownKey)
            return .cooldown(seconds)
        }
        return .invalid
    }

    private func resetFailures() {
        UserDefaults.standard.removeObject(forKey: TauChatLock.failuresKey)
        UserDefaults.standard.removeObject(forKey: TauChatLock.cooldownKey)
    }

    public func isLockedChat(_ peerId: PeerId) -> Bool {
        guard self.hasPasscode else {
            return false
        }
        return TauSettings.shared.current.lockedChats.contains(peerId.toInt64())
    }

    public func needsUnlock(_ peerId: PeerId) -> Bool {
        guard self.isLockedChat(peerId) else {
            return false
        }
        self.lock.lock()
        defer { self.lock.unlock() }
        return !self.unlocked.contains(peerId.toInt64())
    }

    public func setLocked(_ peerId: PeerId, locked: Bool) {
        let id = peerId.toInt64()
        TauSettings.shared.update { current in
            var current = current
            current.lockedChats.removeAll(where: { $0 == id })
            if locked {
                current.lockedChats.append(id)
            }
            return current
        }
        self.lock.lock()
        self.unlocked.remove(id)
        self.lock.unlock()
        self.changesPipe.putNext(Void())
    }

    public func markUnlocked(_ peerId: PeerId) {
        self.lock.lock()
        self.unlocked.insert(peerId.toInt64())
        self.lock.unlock()
        self.changesPipe.putNext(Void())
    }

    public func relock(_ peerId: PeerId) {
        self.lock.lock()
        let removed = self.unlocked.remove(peerId.toInt64()) != nil
        self.lock.unlock()
        if removed {
            self.changesPipe.putNext(Void())
        }
    }

    public func relockAll() {
        self.lock.lock()
        let hadUnlocked = !self.unlocked.isEmpty
        self.unlocked.removeAll()
        self.lock.unlock()
        if hadUnlocked {
            self.changesPipe.putNext(Void())
        }
    }
}
