import Foundation

final class EntitlementsStore {
    static let key = "facerate.entitlements.v1"
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> Entitlements {
        guard let raw = defaults.string(forKey: Self.key), let data = raw.data(using: .utf8),
              let value = try? JSONDecoder.iso8601.decode(Entitlements.self, from: data) else {
            return .initial
        }
        return value
    }

    func save(_ value: Entitlements) {
        guard let data = try? JSONEncoder.iso8601.encode(value), let str = String(data: data, encoding: .utf8) else { return }
        defaults.set(str, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
