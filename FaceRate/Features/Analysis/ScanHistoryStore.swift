import Foundation
import Security

/// The quota must not be coupled to the visible scan history: a user may erase
/// their photos/history without making the paid 24-hour allowance reusable.
/// Keychain items normally survive an app reinstall for the same bundle/team,
/// while records are pruned after the rolling window has safely elapsed.
struct ScanQuotaRecord: Codable, Equatable {
    let id: String
    let capturedAt: Date
}

protocol ScanQuotaLedger: AnyObject {
    func records() -> [ScanQuotaRecord]
    func record(id: String, capturedAt: Date)
}

final class KeychainScanQuotaLedger: ScanQuotaLedger {
    private static let account = "lookgrade.scan-quota.v1"
    private static let service = "com.lokman.facerate"
    private static let retention: TimeInterval = 48 * 60 * 60

    func records() -> [ScanQuotaRecord] {
        let cutoff = Date().addingTimeInterval(-Self.retention)
        let current = decode().filter { $0.capturedAt > cutoff }
        persist(current)
        return current
    }

    func record(id: String, capturedAt: Date) {
        var current = records()
        guard !current.contains(where: { $0.id == id }) else { return }
        current.append(ScanQuotaRecord(id: id, capturedAt: capturedAt))
        persist(current)
    }

    private func decode() -> [ScanQuotaRecord] {
        guard let data = KeychainDataStore.read(service: Self.service, account: Self.account) else { return [] }
        return (try? JSONDecoder.iso8601.decode([ScanQuotaRecord].self, from: data)) ?? []
    }

    private func persist(_ records: [ScanQuotaRecord]) {
        guard let data = try? JSONEncoder.iso8601.encode(records) else { return }
        KeychainDataStore.write(data, service: Self.service, account: Self.account)
    }
}

/// Minimal keychain wrapper shared by quota and subscription-recovery state.
/// `ThisDeviceOnly` avoids syncing usage data to another person's device.
enum KeychainDataStore {
    static func read(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func write(_ data: Data, service: String, account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let update = [kSecValueData as String: data]
        if SecItemUpdate(base as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

/// History is a small list (capped at `maxEntries`) so a single UserDefaults
/// string is plenty. Newest-first. Same key/shape as the Flutter app's
/// `shared_preferences` store, minus the `flutter.` prefix Flutter adds on
/// iOS — see `LegacyDataMigrator`.
final class ScanHistoryStore {
    static let key = "facerate.scan_history.v1"
    private static let maxEntries = 200

    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// Decodes each entry independently for display — a single malformed/
    /// legacy-format entry is skipped rather than failing the whole array.
    func load() -> [ScanHistoryEntry] {
        loadRaw().compactMap { decode($0) }
    }

    /// Adds a new entry. Writes operate on the *raw* JSON array so an entry
    /// this build can't decode (an older/newer schema) is carried through
    /// verbatim instead of being permanently dropped on the next mutation —
    /// the previous decode→re-encode round-trip silently deleted such entries.
    @discardableResult
    func add(_ entry: ScanHistoryEntry) -> [ScanHistoryEntry] {
        var raw = loadRaw()
        if let obj = jsonObject(for: entry) {
            raw.insert(obj, at: 0)
        }
        if raw.count > Self.maxEntries {
            raw.removeSubrange(Self.maxEntries...)
        }
        persistRaw(raw)
        return load()
    }

    @discardableResult
    func remove(id: String) -> [ScanHistoryEntry] {
        let next = loadRaw().filter { ($0["id"] as? String) != id }
        persistRaw(next)
        return load()
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }

    // MARK: - Raw storage

    private func loadRaw() -> [[String: Any]] {
        guard let raw = defaults.string(forKey: Self.key), let data = raw.data(using: .utf8),
              let objects = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return objects
    }

    private func persistRaw(_ objects: [[String: Any]]) {
        guard let data = try? JSONSerialization.data(withJSONObject: objects),
              let str = String(data: data, encoding: .utf8) else { return }
        defaults.set(str, forKey: Self.key)
    }

    private func decode(_ obj: [String: Any]) -> ScanHistoryEntry? {
        guard let itemData = try? JSONSerialization.data(withJSONObject: obj) else { return nil }
        return try? JSONDecoder.iso8601.decode(ScanHistoryEntry.self, from: itemData)
    }

    private func jsonObject(for entry: ScanHistoryEntry) -> [String: Any]? {
        guard let data = try? JSONEncoder.iso8601.encode(entry) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
