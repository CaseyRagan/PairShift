import XCTest
import PairShiftCore
@testable import PairShift

@MainActor
final class GameStoreTests: XCTestCase {
    private final class RecordedFeedback: GameFeedback {
        var cues: [FeedbackCue] = []
        var stopCount = 0

        func play(_ cue: FeedbackCue, settings: GameSettings) { cues.append(cue) }
        func stop() { stopCount += 1 }
    }

    private func temporarySaveURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("PairShiftTests-\(UUID().uuidString)")
            .appendingPathComponent("progress.json")
    }

    private func removeSave(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private func write(_ save: SavedProgress, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(save).write(to: url, options: .atomic)
    }

    func testResumePreservesEveryUndoSnapshotAndSettings() async throws {
        let url = temporarySaveURL()
        defer { removeSave(url) }
        let level = try XCTUnwrap(LevelCatalog.all.first {
            PuzzleVerifier.solve($0.initialState).solution.count >= 3
        })
        let directions = PuzzleVerifier.solve(level.initialState).solution
        var session = GameSession(initialState: level.initialState)
        session.move(directions[0])
        session.move(directions[1])
        let completed = Set(LevelCatalog.all.filter { $0.id < level.id }.map(\.id))
        var settings = GameSettings()
        settings.soundEnabled = false
        settings.reduceMotion = true
        settings.appearance = .light
        try write(SavedProgress(currentLevelID: level.id, session: session, completedLevelIDs: completed,
                                bestMoves: [1: 1], settings: settings), to: url)
        let original = GameStore(saveURL: url, feedback: RecordedFeedback())
        XCTAssertEqual(original.session, session)
        await original.waitForPendingSave()

        let restored = GameStore(saveURL: url, feedback: RecordedFeedback())
        XCTAssertEqual(restored.session, session)
        XCTAssertEqual(restored.settings, settings)
        XCTAssertEqual(restored.completedLevelIDs, completed)
        restored.undo()
        XCTAssertEqual(restored.state, session.undoStack.last)
        restored.undo()
        XCTAssertEqual(restored.state, level.initialState)
        XCTAssertFalse(restored.canUndo)
        await restored.waitForPendingSave()
    }

    func testMalformedSaveRecoversToFirstPuzzle() throws {
        let url = temporarySaveURL()
        defer { removeSave(url) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{interrupted-write".utf8).write(to: url)
        let store = GameStore(saveURL: url, feedback: RecordedFeedback())
        XCTAssertEqual(store.level.id, LevelCatalog.all[0].id)
        XCTAssertEqual(store.state, LevelCatalog.all[0].initialState)
        XCTAssertTrue(store.completedLevelIDs.isEmpty)
        XCTAssertEqual(store.settings, GameSettings())
    }

    func testValidButUnreachableHistoryIsRejectedWithoutLosingSettings() throws {
        let url = temporarySaveURL()
        defer { removeSave(url) }
        let level = try XCTUnwrap(LevelCatalog.all.first {
            PuzzleVerifier.solve($0.initialState).solution.count >= 3
        })
        let directions = PuzzleVerifier.solve(level.initialState).solution
        var session = GameSession(initialState: level.initialState)
        session.move(directions[0])
        session.move(directions[1])
        var settings = GameSettings()
        settings.hapticsEnabled = false
        let completed = Set(LevelCatalog.all.filter { $0.id < level.id }.map(\.id))
        let save = SavedProgress(currentLevelID: level.id, session: session, completedLevelIDs: completed,
                                 bestMoves: [:], settings: settings)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(save)) as? [String: Any])
        var encodedSession = try XCTUnwrap(json["session"] as? [String: Any])
        var history = try XCTUnwrap(encodedSession["undoStack"] as? [[String: Any]])
        // A repeated board with an incremented counter is structurally valid,
        // but the engine never records a no-op as a move.
        history[1] = history[0]
        history[1]["moveCount"] = 1
        encodedSession["undoStack"] = history
        json["session"] = encodedSession
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: json).write(to: url)

        let store = GameStore(saveURL: url, feedback: RecordedFeedback())
        XCTAssertEqual(store.state, level.initialState)
        XCTAssertFalse(store.canUndo)
        XCTAssertEqual(store.completedLevelIDs, completed)
        XCTAssertEqual(store.settings, settings)
    }

    func testSessionFromDifferentPuzzleCannotBeRestored() throws {
        let url = temporarySaveURL()
        defer { removeSave(url) }
        let first = LevelCatalog.all[0]
        let second = LevelCatalog.all[1]
        try write(SavedProgress(currentLevelID: second.id, session: GameSession(initialState: first.initialState),
                                completedLevelIDs: [first.id], bestMoves: [first.id: 1], settings: GameSettings()), to: url)
        let store = GameStore(saveURL: url, feedback: RecordedFeedback())
        XCTAssertEqual(store.level.id, second.id)
        XCTAssertEqual(store.state, second.initialState)
    }

    func testCompletionUnlocksNextAndRetainsBestAcrossUndoAndRestart() async throws {
        let url = temporarySaveURL()
        defer { removeSave(url) }
        let store = GameStore(saveURL: url, feedback: RecordedFeedback())
        let first = store.level
        let next = store.levels[1]
        XCTAssertFalse(store.isUnlocked(next))
        store.selectLevel(id: next.id)
        XCTAssertEqual(store.level.id, first.id)
        let solution = PuzzleVerifier.solve(first.initialState).solution
        for move in solution { store.move(move) }
        XCTAssertTrue(store.state.isSolved)
        XCTAssertTrue(store.canGoNext)
        XCTAssertTrue(store.isUnlocked(next))
        XCTAssertEqual(store.bestMoves[first.id], solution.count)
        store.undo()
        XCTAssertFalse(store.state.isSolved)
        XCTAssertTrue(store.completedLevelIDs.contains(first.id))
        store.restart()
        XCTAssertEqual(store.state, first.initialState)
        XCTAssertEqual(store.bestMoves[first.id], solution.count)
        await store.waitForPendingSave()
        let restored = GameStore(saveURL: url, feedback: RecordedFeedback())
        XCTAssertTrue(restored.isUnlocked(next))
        XCTAssertEqual(restored.bestMoves[first.id], solution.count)
    }

    func testBackgroundCancelsDelayedBondAndCompletionFeedback() async throws {
        let url = temporarySaveURL()
        defer { removeSave(url) }
        let feedback = RecordedFeedback()
        let store = GameStore(saveURL: url, feedback: feedback)
        let solution = PuzzleVerifier.solve(store.state).solution
        for move in solution { store.move(move) }
        let immediateCues = feedback.cues
        store.setActive(false)
        XCTAssertNil(store.move(.left))
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(feedback.cues, immediateCues)
        XCTAssertGreaterThan(feedback.stopCount, 0)
        await store.waitForPendingSave()
    }

    func testBackgroundFlushPersistsChangesToEverySetting() async throws {
        let url = temporarySaveURL()
        defer { removeSave(url) }
        let store = GameStore(saveURL: url, feedback: RecordedFeedback())
        store.settings.soundEnabled = false
        store.settings.hapticsEnabled = false
        store.settings.reduceMotion = true
        store.settings.appearance = .light
        store.setActive(false)
        await store.waitForPendingSave()
        let restored = GameStore(saveURL: url, feedback: RecordedFeedback())
        XCTAssertFalse(restored.settings.soundEnabled)
        XCTAssertFalse(restored.settings.hapticsEnabled)
        XCTAssertTrue(restored.settings.reduceMotion)
        XCTAssertEqual(restored.settings.appearance, .light)
    }

    func testCoveringBoardCancelsPendingFeedbackWithoutChangingPuzzle() async throws {
        let url = temporarySaveURL()
        defer { removeSave(url) }
        let feedback = RecordedFeedback()
        let store = GameStore(saveURL: url, feedback: feedback)
        for move in PuzzleVerifier.solve(store.state).solution { store.move(move) }
        let state = store.state
        let immediateCues = feedback.cues
        store.stopFeedback()
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(feedback.cues, immediateCues)
        XCTAssertEqual(store.state, state)
        await store.waitForPendingSave()
    }
}
