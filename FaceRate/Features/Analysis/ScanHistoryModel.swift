import Foundation
import Observation

struct ScanQuotaStatus: Equatable {
    let limit: Int
    let used: Int
    let nextReset: Date?

    var remaining: Int { max(0, limit - used) }
    var canAnalyze: Bool { remaining > 0 }
}

@Observable
@MainActor
final class ScanHistoryModel {
    static let analysesPerWindow = 5
    static let quotaWindow: TimeInterval = 24 * 60 * 60

    private let store: ScanHistoryStore
    private let quotaLedger: ScanQuotaLedger
    private(set) var entries: [ScanHistoryEntry]

    init(
        store: ScanHistoryStore = ScanHistoryStore(),
        quotaLedger: ScanQuotaLedger = KeychainScanQuotaLedger()
    ) {
        self.store = store
        self.quotaLedger = quotaLedger
        self.entries = store.load()
        // One-time upgrade bridge: scans already saved by older builds still
        // count inside the active window once the independent ledger starts.
        for entry in entries {
            quotaLedger.record(id: entry.id, capturedAt: entry.capturedAt)
        }
    }

    func append(_ result: ScanResult) {
        let entry = ScanHistoryEntry.from(result: result)
        quotaLedger.record(id: entry.id, capturedAt: entry.capturedAt)
        entries = store.add(entry)
    }

    func remove(id: String) {
        entries = store.remove(id: id)
    }

    func clear() {
        store.clear()
        entries = []
    }

    /// Rolling subscription allowance shared by every paid plan. It reads the
    /// privacy-minimal keychain ledger rather than the visible history, so
    /// removing scans or "Delete all data" cannot reset the allowance.
    func quotaStatus(now: Date = Date()) -> ScanQuotaStatus {
        let cutoff = now.addingTimeInterval(-Self.quotaWindow)
        let recent = quotaLedger.records()
            .filter { $0.capturedAt > cutoff && $0.capturedAt <= now }
            .sorted { $0.capturedAt < $1.capturedAt }

        let nextReset: Date?
        if recent.count >= Self.analysesPerWindow {
            let resetIndex = recent.count - Self.analysesPerWindow
            nextReset = recent[resetIndex].capturedAt.addingTimeInterval(Self.quotaWindow)
        } else {
            nextReset = nil
        }

        return ScanQuotaStatus(
            limit: Self.analysesPerWindow,
            used: recent.count,
            nextReset: nextReset
        )
    }

    /// Consecutive-day streak counting back from `now`.
    func currentStreak(now: Date = Date()) -> Int {
        let cal = Calendar.current
        let days = Set(entries.map { cal.startOfDay(for: $0.capturedAt) })
        var streak = 0
        var cursor = cal.startOfDay(for: now)
        while days.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}
