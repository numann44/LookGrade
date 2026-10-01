import XCTest
@testable import FaceRate

final class FindingsCatalogTests: XCTestCase {
    func testBuildsFourFindingsFromFullCategories() {
        let cats = ScoreCategory.allCases.enumerated().map {
            CategoryScore(category: $0.element, value: Double($0.offset) + 2)
        }
        XCTAssertEqual(FindingsCatalog.build(from: cats).count, 4)
    }

    func testDegenerateInputDoesNotCrash() {
        let findings = FindingsCatalog.build(from: [CategoryScore(category: .skin, value: 8)])
        XCTAssertEqual(findings.count, 1)
    }

    func testStrongestCategoryLeadsAsStrength() {
        let cats: [CategoryScore] = [
            .init(category: .eyes, value: 9.5),
            .init(category: .skin, value: 8.0),
            .init(category: .jawline, value: 7.0),
            .init(category: .nose, value: 5.5),
        ]
        let findings = FindingsCatalog.build(from: cats)
        XCTAssertEqual(findings.first?.category, .eyes)
        XCTAssertTrue(findings.contains { $0.category == .nose })
    }
}
