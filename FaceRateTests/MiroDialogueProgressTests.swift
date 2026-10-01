import XCTest
@testable import FaceRate

final class MiroDialogueProgressTests: XCTestCase {
    func testTapInvalidatesThePreviousLinesTimer() {
        var dialogue = MiroDialogueProgress(count: 3)
        XCTAssertEqual(dialogue.advance(from: 0, now: 100), .next)
        XCTAssertEqual(dialogue.advance(from: 0, now: 105.5), .ignored)
        XCTAssertEqual(dialogue.index, 1)
        XCTAssertEqual(dialogue.advance(from: 1, now: 105.6), .next)
    }

    func testTimerAndTapCannotSkipTwoLinesTogether() {
        var dialogue = MiroDialogueProgress(count: 3)
        XCTAssertEqual(dialogue.advance(from: 0, now: 100), .next)
        XCTAssertEqual(dialogue.advance(from: 1, now: 100.1), .ignored)
        XCTAssertEqual(dialogue.index, 1)
        XCTAssertEqual(dialogue.advance(from: 1, now: 100.5), .next)
    }

    func testFinalLineStaysReadableAndFinishesExactlyOnce() {
        var dialogue = MiroDialogueProgress(count: 2)
        XCTAssertEqual(dialogue.advance(from: 0, now: 100), .next)
        XCTAssertFalse(dialogue.isFinished)
        XCTAssertEqual(dialogue.index, 1)
        XCTAssertEqual(dialogue.advance(from: 1, now: 105.5), .finished)
        XCTAssertEqual(dialogue.index, 1) // Always safe to index the message list.
        XCTAssertEqual(dialogue.advance(from: 1, now: 111), .ignored)
    }
}
