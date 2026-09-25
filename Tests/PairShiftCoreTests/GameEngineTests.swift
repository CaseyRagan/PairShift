import Foundation
import Testing
@testable import PairShiftCore

struct GameEngineTests {
    private func board(_ rows: [String]) -> GameState { LevelCatalog.authoredState(rows) }

    @Test func frontToBackCompressionPreservesOrder() {
        let start = board(["A.B.", "....", "B..A", "...."])
        let result = GameEngine.applyMove(start, direction: .left)
        #expect(result.state.tiles.map(\.position) == [
            .init(row: 0, column: 0), .init(row: 0, column: 1),
            .init(row: 2, column: 0), .init(row: 2, column: 1)
        ])
        #expect(result.newlyBondedPairIDs.isEmpty)
        #expect(result.state.moveCount == 1)
    }

    @Test func edgesAndWallsStopTravel() {
        let state = board(["A.#B", "....", ".B.A", "...."])
        let result = GameEngine.applyMove(state, direction: .right).state
        #expect(result.tiles[0].position == .init(row: 0, column: 1))
        #expect(result.tiles[1].position == .init(row: 0, column: 3))
        #expect(result.tiles[2].position == .init(row: 2, column: 2))
        #expect(result.tiles[3].position == .init(row: 2, column: 3))
        #expect(result.validationIssues.isEmpty)
    }

    @Test func simultaneousBondsPersistAndBlock() {
        let start = board(["A..A", "B..B", "C...", "...C"])
        let first = GameEngine.applyMove(start, direction: .left)
        #expect(first.newlyBondedPairIDs == [0, 1, 2])
        #expect(first.state.isSolved)
        let next = GameEngine.applyMove(first.state, direction: .right)
        #expect(next.state == first.state)
        #expect(!next.didChange)
    }

    @Test func aBondedPairActsAsGeometry() {
        var state = board([".AA.", "B..B", "....", "...."])
        state.tiles[0].isBonded = true
        state.tiles[1].isBonded = true
        let first = GameEngine.applyMove(state, direction: .up)
        #expect(first.state.tiles[0] == state.tiles[0])
        #expect(first.state.tiles[1] == state.tiles[1])
        let second = GameEngine.applyMove(first.state, direction: .left)
        #expect(second.state.tiles[2].position == .init(row: 0, column: 0))
        #expect(second.state.tiles[3].position == .init(row: 0, column: 3))
        #expect(!second.state.isSolved)
        #expect(!second.didChange)
    }

    @Test func matchingChecksHappenAfterAllMovement() {
        let state = board(["A...", ".A..", "B...", "...B"])
        let result = GameEngine.applyMove(state, direction: .right)
        #expect(result.newlyBondedPairIDs == [0, 1])
        #expect(result.state.tiles[0].position == .init(row: 0, column: 3))
        #expect(result.state.tiles[1].position == .init(row: 1, column: 3))
        #expect(result.state.isSolved)
    }

    @Test func diagonalMembersDoNotBond() {
        let state = board(["AB..", "BA..", "....", "...."])
        let result = GameEngine.applyMove(state, direction: .left)
        #expect(!result.didChange)
        #expect(result.newlyBondedPairIDs.isEmpty)
        #expect(result.state.moveCount == 0)
        #expect(!result.state.isSolved)
    }

    @Test func exactUndoAndRestartAcrossBonds() throws {
        let initial = board(["A...", ".B..", "...A", "..B."])
        var session = GameSession(initialState: initial)
        let first = session.move(.up)
        #expect(first.state.bondedPairCount == 1)
        let postBond = session.state
        session.move(.down)
        let firstUndo = session.undo()
        #expect(firstUndo)
        #expect(session.state == postBond)
        let secondUndo = session.undo()
        #expect(secondUndo)
        #expect(session.state == initial)
        let emptyUndo = session.undo()
        #expect(!emptyUndo)
        session.move(.up)
        session.move(.down)
        let saved = try JSONEncoder().encode(session)
        var restored = try JSONDecoder().decode(GameSession.self, from: saved)
        #expect(restored == session)
        let restoredUndo = restored.undo()
        #expect(restoredUndo)
        #expect(restored.state == postBond)
        restored.restart()
        #expect(restored.state == initial)
        #expect(restored.undoStack.isEmpty)
    }

    @Test func noOpDoesNotConsumeAMoveOrHistory() {
        var session = GameSession(initialState: board(["AB..", "BA..", "....", "...."]))
        let original = session
        let result = session.move(.left)
        #expect(!result.didChange)
        #expect(session == original)
    }

    @Test func canonicalKeyIgnoresIdentityOrderAndMoves() {
        let initial = LevelCatalog.all[0].initialState
        var equivalent = initial
        equivalent.tiles.reverse()
        for index in equivalent.tiles.indices { equivalent.tiles[index].id += 100 }
        equivalent.moveCount = 32
        #expect(initial.canonicalKey == equivalent.canonicalKey)
        equivalent.tiles[0].isBonded.toggle()
        #expect(initial.canonicalKey != equivalent.canonicalKey)
    }

    @Test func invalidStatesAreRejectedWithoutMutation() {
        var invalid = LevelCatalog.all[0].initialState
        invalid.tiles[1].position = invalid.tiles[0].position
        invalid.tiles[1].id = invalid.tiles[0].id
        invalid.tiles[2].isBonded = true
        invalid.walls.append(.init(row: -1, column: 0))
        #expect(invalid.validationIssues.count >= 4)
        #expect(!GameEngine.applyMove(invalid, direction: .left).didChange)
        #expect(PuzzleVerifier.solve(invalid).status == .invalid)
    }

    @Test func verifierDistinguishesUnsolvableAndBudgetExhaustion() {
        let impossible = board(["AB..", "BA..", "....", "...."])
        #expect(PuzzleVerifier.solve(impossible).status == .unsolvable)
        #expect(PuzzleVerifier.solve(LevelCatalog.all[1].initialState, stateLimit: 1).status == .searchLimitReached)
        let easy = PuzzleVerifier.solve(LevelCatalog.all[0].initialState)
        #expect(easy.status == .solved)
        #expect(easy.optimalMoveCount == 1)
    }
}
