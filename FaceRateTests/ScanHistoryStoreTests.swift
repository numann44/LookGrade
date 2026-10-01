import XCTest
@testable import FaceRate

final class ScanHistoryStoreTests: XCTestCase {
    private let suite = "facerate.tests.history"
    private var defaults: UserDefaults!
    private var store: ScanHistoryStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        store = ScanHistoryStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func entry(
        id: String,
        score: Double,
        capturedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> ScanHistoryEntry {
        ScanHistoryEntry(
            id: id,
            capturedAt: capturedAt,
            overallScore: score,
            potentialDelta: 0.5,
            categories: [.skin: score, .eyes: score]
        )
    }

    private func rawString() -> String { defaults.string(forKey: ScanHistoryStore.key) ?? "" }

    private final class MemoryQuotaLedger: ScanQuotaLedger {
        private var values: [ScanQuotaRecord] = []
        func records() -> [ScanQuotaRecord] { values }
        func record(id: String, capturedAt: Date) {
            guard !values.contains(where: { $0.id == id }) else { return }
            values.append(ScanQuotaRecord(id: id, capturedAt: capturedAt))
        }
    }

    func testAddAndLoadRoundTrip() {
        store.add(entry(id: "a", score: 8.0))
        let loaded = store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, "a")
        XCTAssertEqual(loaded.first?.overallScore, 8.0)
    }

    func testNewestFirstOrdering() {
        store.add(entry(id: "a", score: 7.0))
        store.add(entry(id: "b", score: 8.0))
        XCTAssertEqual(store.load().map(\.id), ["b", "a"])
    }

    func testRemoveDeletesMatchingId() {
        store.add(entry(id: "a", score: 8.0))
        store.add(entry(id: "b", score: 7.0))
        store.remove(id: "a")
        XCTAssertEqual(store.load().map(\.id), ["b"])
    }

    /// The important regression: an entry this build can't decode must be
    /// carried through a mutation, not silently dropped on the next write.
    func testCarryThroughPreservesUndecodableEntry() throws {
        store.add(entry(id: "good", score: 8.0))
        // Inject a raw object with no decodable ScanHistoryEntry shape.
        var raw = try JSONSerialization.jsonObject(with: Data(rawString().utf8)) as! [[String: Any]]
        raw.insert(["id": "legacy", "weirdField": true], at: 0)
        defaults.set(String(data: try JSONSerialization.data(withJSONObject: raw), encoding: .utf8), forKey: ScanHistoryStore.key)

        // Skipped for display...
        XCTAssertEqual(store.load().count, 1)
        // ...but preserved on disk across a mutation.
        store.remove(id: "does-not-exist")
        XCTAssertTrue(rawString().contains("legacy"), "undecodable entry was dropped on write")
        // The good entry is still readable too.
        XCTAssertEqual(store.load().map(\.id), ["good"])
    }

    @MainActor
    func testQuotaBlocksSixthAnalysisInsideRollingWindow() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        for index in 0..<5 {
            store.add(entry(
                id: "recent-\(index)",
                score: 8.0,
                capturedAt: now.addingTimeInterval(TimeInterval(-index * 60))
            ))
        }

        let status = ScanHistoryModel(store: store, quotaLedger: MemoryQuotaLedger()).quotaStatus(now: now)

        XCTAssertEqual(status.used, 5)
        XCTAssertEqual(status.remaining, 0)
        XCTAssertFalse(status.canAnalyze)
        XCTAssertEqual(
            status.nextReset,
            now.addingTimeInterval(-4 * 60 + ScanHistoryModel.quotaWindow)
        )
    }

    @MainActor
    func testQuotaIgnoresAnalysesOlderThanTwentyFourHours() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        store.add(entry(
            id: "expired",
            score: 8.0,
            capturedAt: now.addingTimeInterval(-ScanHistoryModel.quotaWindow - 1)
        ))
        for index in 0..<4 {
            store.add(entry(
                id: "recent-\(index)",
                score: 8.0,
                capturedAt: now.addingTimeInterval(TimeInterval(-index * 60))
            ))
        }

        let status = ScanHistoryModel(store: store, quotaLedger: MemoryQuotaLedger()).quotaStatus(now: now)

        XCTAssertEqual(status.used, 4)
        XCTAssertEqual(status.remaining, 1)
        XCTAssertTrue(status.canAnalyze)
        XCTAssertNil(status.nextReset)
    }

    @MainActor
    func testClearingHistoryDoesNotResetRollingQuota() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        for index in 0..<5 {
            store.add(entry(
                id: "recent-\(index)",
                score: 8.0,
                capturedAt: now.addingTimeInterval(TimeInterval(-index * 60))
            ))
        }

        let ledger = MemoryQuotaLedger()
        let history = ScanHistoryModel(store: store, quotaLedger: ledger)
        history.clear()

        XCTAssertTrue(history.entries.isEmpty)
        XCTAssertEqual(history.quotaStatus(now: now).used, 5)
        XCTAssertFalse(history.quotaStatus(now: now).canAnalyze)
    }
}
