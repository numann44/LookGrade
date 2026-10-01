import Foundation

/// Persists the most recent full `ScanResult` so Home, Tips and the Score
/// Report survive a relaunch showing the user's *real* scores — previously
/// `LastResultModel` was memory-only and reverted to `MockScanData` (a fake
/// 8.2) on every cold launch, contradicting the persisted Progress history.
final class LastResultStore {
    static let key = "facerate.last_result.v1"
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> ScanResult? {
        guard let raw = defaults.string(forKey: Self.key), let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder.iso8601.decode(ScanResult.self, from: data)
    }

    func save(_ result: ScanResult) {
        guard let data = try? JSONEncoder.iso8601.encode(result), let str = String(data: data, encoding: .utf8) else { return }
        defaults.set(str, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
