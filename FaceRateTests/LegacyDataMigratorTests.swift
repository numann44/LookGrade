import XCTest
@testable import FaceRate

/// Covers the one-time Flutter→native UserDefaults migration — the highest-
/// value untested unit, since a regression here silently loses returning
/// users' data.
final class LegacyDataMigratorTests: XCTestCase {
    private let suite = "facerate.tests.migrator"
    private var defaults: UserDefaults!
    private var legacyHistoryKey: String { "flutter." + ScanHistoryStore.key }

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testCopiesLegacyValueToNewKey() {
        defaults.set("[{\"id\":\"1\"}]", forKey: legacyHistoryKey)
        LegacyDataMigrator.runOnce(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: ScanHistoryStore.key), "[{\"id\":\"1\"}]")
    }

    func testDoesNotOverwriteExistingNewValue() {
        defaults.set("native", forKey: ScanHistoryStore.key)
        defaults.set("legacy", forKey: legacyHistoryKey)
        LegacyDataMigrator.runOnce(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: ScanHistoryStore.key), "native")
    }

    func testRunOnceIsIdempotent() {
        defaults.set("legacy", forKey: legacyHistoryKey)
        LegacyDataMigrator.runOnce(defaults: defaults)
        // User deletes the migrated value; a second run must NOT re-copy it.
        defaults.removeObject(forKey: ScanHistoryStore.key)
        LegacyDataMigrator.runOnce(defaults: defaults)
        XCTAssertNil(defaults.string(forKey: ScanHistoryStore.key))
    }

    func testClearLegacyDataRemovesPrefixedKeys() {
        defaults.set("x", forKey: legacyHistoryKey)
        defaults.set("y", forKey: "flutter." + EntitlementsStore.key)
        LegacyDataMigrator.clearLegacyData(defaults: defaults)
        XCTAssertNil(defaults.string(forKey: legacyHistoryKey))
        XCTAssertNil(defaults.string(forKey: "flutter." + EntitlementsStore.key))
    }
}
