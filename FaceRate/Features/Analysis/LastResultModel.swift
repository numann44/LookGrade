import Foundation
import Observation

/// The most recent scan result, persisted across launches. `nil` until the
/// user has actually run (or migrated) a scan — production UI shows an empty
/// state rather than fabricated seed data.
@Observable
@MainActor
final class LastResultModel {
    private let store: LastResultStore
    private(set) var result: ScanResult?

    init(store: LastResultStore = LastResultStore()) {
        self.store = store
        self.result = store.load()
    }

    func set(_ newResult: ScanResult) {
        result = newResult
        store.save(newResult)
    }

    /// First-launch-after-upgrade seed: if there's no persisted result yet but
    /// the user has scan history, rebuild the in-memory value from the newest
    /// entry so Home/Tips don't sit empty. Never overwrites a real result.
    func hydrateIfNeeded(from entry: ScanHistoryEntry?) {
        guard result == nil, let entry else { return }
        set(.reconstruct(from: entry))
    }

    /// Used by "Delete all data".
    func reset() {
        result = nil
        store.clear()
    }
}
