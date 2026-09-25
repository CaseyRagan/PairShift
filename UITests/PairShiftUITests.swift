import XCTest

@MainActor
final class PairShiftUITests: XCTestCase {
    private var app: XCUIApplication!
    private var board: XCUIElement { app.descendants(matching: .any)["puzzleBoard"].firstMatch }
    private var counter: XCUIElement { app.descendants(matching: .any)["moveCounter"].firstMatch }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-progress"]
        app.launch()
        XCTAssertTrue(board.waitForExistence(timeout: 8))
    }

    func testUndoRestartAndExactResume() {
        let initial = board.value as? String
        swipe("right")
        XCTAssertTrue(app.buttons["nextPuzzleButton"].waitForExistence(timeout: 3))
        app.buttons["undoButton"].tap()
        waitForMoves(0)
        XCTAssertEqual(board.value as? String, initial)
        swipe("right")
        app.buttons["nextPuzzleButton"].tap()
        waitForMoves(0)
        swipe("up")
        waitForMoves(1)
        let beforeResume = board.value as? String
        XCUIDevice.shared.press(.home)
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        waitForMoves(1)
        XCTAssertEqual(board.value as? String, beforeResume)
        app.buttons["undoButton"].tap()
        waitForMoves(0)
        swipe("up")
        app.buttons["restartButton"].tap()
        waitForMoves(0)
    }

    func testAllTwentyPuzzlesAndVisualStates() {
        capture("01-first-light-dark")
        for (index, solution) in VerifiedPaths.solutions.enumerated() {
            if [5, 7, 12, 19].contains(index) { capture(String(format: "%02d-gameplay-dark", index + 1)) }
            for (moveIndex, direction) in solution.enumerated() {
                swipe(direction)
                waitForMoves(moveIndex + 1)
            }
            XCTAssertTrue(app.buttons["nextPuzzleButton"].waitForExistence(timeout: 3), "Level \(index + 1) should complete")
            if index == 0 { capture("02-first-connection") }
            if index < VerifiedPaths.solutions.count - 1 {
                app.buttons["nextPuzzleButton"].tap()
                waitForMoves(0)
            }
        }
        capture("20-journey-complete")
        app.buttons["nextPuzzleButton"].tap()
        XCTAssertTrue(app.buttons["level_20"].waitForExistence(timeout: 3))
        capture("21-journey")
        app.buttons["level_8"].tap()
        waitForMoves(0)
        app.buttons["settingsButton"].tap()
        app.segmentedControls["appearancePicker"].buttons["Light"].tap()
        app.switches["Reduce motion"].tap()
        capture("22-settings-light")
        app.buttons["closeSettings"].tap()
        capture("23-gameplay-light")
        for (index, direction) in VerifiedPaths.solutions[7].enumerated() {
            swipe(direction)
            waitForMoves(index + 1)
        }
        XCTAssertTrue(app.buttons["nextPuzzleButton"].waitForExistence(timeout: 3))
        capture("24-reduced-motion-complete")
    }

    private func swipe(_ direction: String) {
        let center = board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let offsets: [String: CGVector] = ["up": .init(dx: 0.5, dy: 0.12), "down": .init(dx: 0.5, dy: 0.88), "left": .init(dx: 0.12, dy: 0.5), "right": .init(dx: 0.88, dy: 0.5)]
        center.press(forDuration: 0.05, thenDragTo: board.coordinate(withNormalizedOffset: offsets[direction]!))
    }

    private func waitForMoves(_ count: Int) {
        let predicate = NSPredicate(format: "value == %@", String(count))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: counter)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed, "Expected \(count) moves; got \(counter.value ?? "none")")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
