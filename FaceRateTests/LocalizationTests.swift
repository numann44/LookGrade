import XCTest
@testable import FaceRate

final class LocalizationTests: XCTestCase {
    private func languageBundle(_ language: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }

    func testEveryLanguageShipsTheSameCompleteCatalogAndPermissions() throws {
        let english = try languageBundle("en")
        let enURL = try XCTUnwrap(english.url(forResource: "Localizable", withExtension: "strings"))
        let reference = try XCTUnwrap(NSDictionary(contentsOf: enURL) as? [String: String])
        XCTAssertGreaterThan(reference.count, 650)
        for language in L10n.supportedLanguages {
            let bundle = try languageBundle(language)
            let url = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"))
            let values = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
            XCTAssertEqual(Set(values.keys), Set(reference.keys), language)
            XCTAssertFalse(values.values.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }), language)
            for key in ["NSCameraUsageDescription", "NSPhotoLibraryUsageDescription"] {
                let value = bundle.localizedString(forKey: key, value: "MISSING", table: "InfoPlist")
                XCTAssertNotEqual(value, "MISSING", "\(language): \(key)")
            }
        }
    }

    func testPaywallKeepsActualPricesAndCanReorderArguments() throws {
        let turkish = try languageBundle("tr")
        XCTAssertEqual(L10n.text("\("₺499,99") per year", bundle: turkish), "Yıllık ₺499,99")
        let message = L10n.text("Private 50 percent off yearly offer, \("₺999,99") reduced to \("₺499,99")", bundle: turkish)
        XCTAssertTrue(message.contains("₺999,99"))
        XCTAssertTrue(message.contains("₺499,99"))
        let savings = L10n.text("SAVE \(50)%", bundle: turkish)
        // The injected bundle changes copy, while numbers follow the active
        // app locale (Arabic uses ٥٠). Do not assume Latin digits in this test.
        let fifty = 50.formatted(.number.grouping(.never).locale(L10n.locale))
        XCTAssertEqual(savings, "%\(fifty) TASARRUF")
    }

    func testNamesStayVerbatimEvenWhenTheyContainFormatCharacters() throws {
        let name = "Aylin %@ 💫"
        for language in L10n.supportedLanguages {
            let bundle = try languageBundle(language)
            let value = L10n.text("Ready, \(name)?", bundle: bundle)
            XCTAssertTrue(value.contains(name), language)
            XCTAssertFalse(value.contains("%1$@"), language)
        }
    }

    func testStoredFindingsKeepStableSourceKeysAcrossLanguages() {
        let findings = FindingsCatalog.build(from: ScoreCategory.allCases.map { CategoryScore(category: $0, value: 7) })
        XCTAssertFalse(findings.isEmpty)
        let english = Bundle(path: Bundle.main.path(forResource: "en", ofType: "lproj")!)!
        for finding in findings {
            XCTAssertEqual(L10n.lookup(finding.title, bundle: english), finding.title)
            XCTAssertEqual(L10n.lookup(finding.body, bundle: english), finding.body)
        }
    }

    func testReadingTimeExpandsForLongTranslations() {
        XCTAssertEqual(L10n.readingDelay(for: "Hello"), 5.5)
        XCTAssertGreaterThan(L10n.readingDelay(for: String(repeating: "あ", count: 120)), 5.5)
        XCTAssertLessThanOrEqual(L10n.readingDelay(for: String(repeating: "あ", count: 1000)), 14)
    }

    func testEveryFormattedTranslationRendersAndPreservesArguments() throws {
        let positional = try NSRegularExpression(pattern: "%([0-9]+)\\$@")
        for language in L10n.supportedLanguages {
            let bundle = try languageBundle(language)
            let url = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"))
            let catalog = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
            for (key, value) in catalog {
                let matches = positional.matches(in: key, range: NSRange(key.startIndex..., in: key))
                let count = matches.compactMap { match -> Int? in
                    guard let range = Range(match.range(at: 1), in: key) else { return nil }
                    return Int(key[range])
                }.max() ?? 0
                if count > 0 {
                    // Include currency, bidi, emoji, and printf-like user input.
                    let arguments = (1...count).map { "ARG\($0)[₺49,99 العربية %@ 💫]" }
                    let rendered = String(format: value, locale: Locale(identifier: language), arguments: arguments)
                    for argument in arguments { XCTAssertTrue(rendered.contains(argument), "\(language): \(key)") }
                    XCTAssertFalse(rendered.contains("%1$@"), "\(language): \(key)")
                } else if key.contains("%lld") {
                    for count: Int64 in [0, 1, 2, 5, 11, 101] {
                        XCTAssertFalse(String(format: value, count).contains("%lld"), language)
                    }
                } else if key.contains("%.1f") {
                    let rendered = String(format: value, 7.5, 8.2)
                    XCTAssertTrue(rendered.contains("7.5"), language)
                    XCTAssertTrue(rendered.contains("8.2"), language)
                }
            }
        }
    }

    func testGeneratedTipsAndStoredFindingsResolveBeyondOnboarding() throws {
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        let bundle = try languageBundle(language)
        let url = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"))
        let catalog = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
        let translatedValues = Set(catalog.values)
        for category in ScoreCategory.allCases {
            for score in [4.0, 7.0, 9.0] {
                let tip = TipBuilder.forScore(category, score)
                for text in [tip.headline] + tip.actions + tip.tags {
                    XCTAssertTrue(translatedValues.contains(text), "Uncatalogued tip: \(text)")
                }
                XCTAssertFalse(tip.body.contains("%1$@"))
            }
        }
        for weakCategory in ScoreCategory.allCases {
            let scores = ScoreCategory.allCases.map { CategoryScore(category: $0, value: $0 == weakCategory ? 3 : 9) }
            for finding in FindingsCatalog.build(from: scores) {
                XCTAssertNotNil(catalog[finding.title], finding.title)
                XCTAssertNotNil(catalog[finding.body], finding.body)
            }
        }
    }
}
