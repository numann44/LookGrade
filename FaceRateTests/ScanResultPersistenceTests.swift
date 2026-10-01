import XCTest
@testable import FaceRate

final class ScanResultPersistenceTests: XCTestCase {
    func testCapturePathSurvivesContainerRelocation() {
        let filename = "01234567-89AB-CDEF-0123-456789ABCDEF.jpg"
        let oldPath = "/old-container/Library/Caches/ScanImages/" + filename
        let expected = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScanImages").appendingPathComponent(filename).path
        XCTAssertEqual(ScanImageStore.currentPath(forStoredPath: oldPath), expected)
        XCTAssertEqual(ScanImageStore.currentPath(forStoredPath: expected), expected)
    }

    func testUnrelatedPhotoPathsAreNotRewritten() {
        for path in ["", "/tmp/photo.jpg", "/old/Library/Caches/ScanImages/not-a-uuid.jpg",
                     "/old/Library/Caches/ScanImages/../private.jpg"] {
            XCTAssertEqual(ScanImageStore.currentPath(forStoredPath: path), path)
        }
    }

    func testScanResultCodableRoundTrip() throws {
        let result = MockScanData.seedResult()
        let data = try JSONEncoder.iso8601.encode(result)
        let decoded = try JSONDecoder.iso8601.decode(ScanResult.self, from: data)
        XCTAssertEqual(decoded.overallScore, result.overallScore)
        XCTAssertEqual(decoded.categories.count, result.categories.count)
        XCTAssertEqual(decoded.findings.count, result.findings.count)
    }

    func testLastResultStoreRoundTrip() {
        let suite = "facerate.tests.lastresult"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = LastResultStore(defaults: defaults)
        XCTAssertNil(store.load())
        store.save(MockScanData.seedResult())
        XCTAssertEqual(store.load()?.overallScore, MockScanData.seedResult().overallScore)
        store.clear()
        XCTAssertNil(store.load())
    }

    func testReconstructFromHistoryEntryRebuildsCategoriesAndFindings() {
        let entry = ScanHistoryEntry(
            id: "x",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            overallScore: 8.0,
            potentialDelta: 0.4,
            categories: [.eyes: 9, .skin: 7, .jawline: 8, .nose: 6, .symmetry: 8, .lips: 7, .tone: 8, .harmony: 8]
        )
        let result = ScanResult.reconstruct(from: entry)
        XCTAssertEqual(result.categories.count, 8)
        XCTAssertEqual(result.findings.count, 4)
        XCTAssertEqual(result.overallScore, 8.0)
    }
}
