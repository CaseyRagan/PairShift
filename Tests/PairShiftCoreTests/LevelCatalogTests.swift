import Foundation
import Testing
@testable import PairShiftCore

struct LevelCatalogTests {
    @Test func authoredCatalogHasStableValidDistinctBoards() {
        #expect(LevelCatalog.all.map(\.id) == Array(1...20))
        #expect(Set(LevelCatalog.all.map { $0.initialState.canonicalKey }).count == 20)
        #expect(Set(LevelCatalog.all.map(\.chapter)).count == 4)
        for level in LevelCatalog.all {
            let state = level.initialState
            #expect(state.validationIssues.isEmpty, "Level \(level.id)")
            #expect(state.moveCount == 0)
            #expect(state.tiles.allSatisfy { !$0.isBonded })
            #expect((4...5).contains(state.size))
            for members in Dictionary(grouping: state.tiles, by: \.pairID).values {
                #expect(!members[0].position.isAdjacent(to: members[1].position), "Level \(level.id) begins with an adjacent unbonded pair")
            }
            if level.id < 13 { #expect(state.walls.isEmpty) }
            if (13...16).contains(level.id) { #expect((1...2).contains(state.walls.count)) }
        }
    }

    @Test func everyLevelHasAShortestSolutionThatReplaysAndUndoes() throws {
        let certifiedLengths = [1, 2, 3, 3, 4, 5, 6, 4, 6, 7, 7, 7, 3, 4, 5, 10, 11, 9, 11, 15]
        for level in LevelCatalog.all {
            let verification = PuzzleVerifier.solve(level.initialState)
            try #require(verification.status == .solved, "Level \(level.id): \(verification.status)")
            #expect(verification.optimalMoveCount == certifiedLengths[level.id - 1])
            var session = GameSession(initialState: level.initialState)
            for direction in verification.solution {
                let before = session.state
                let first = session.move(direction)
                let second = GameEngine.applyMove(before, direction: direction)
                #expect(first == second)
                #expect(first.didChange)
                #expect(first.state.validationIssues.isEmpty)
                for locked in before.tiles.filter(\.isBonded) {
                    #expect(first.state.tiles.first(where: { $0.id == locked.id }) == locked)
                }
            }
            #expect(session.state.isSolved)
            #expect(session.state.moveCount == certifiedLengths[level.id - 1])
            #expect(session.state.bondedPairCount == session.state.totalPairCount)
            for _ in verification.solution { session.undo() }
            #expect(session.state == level.initialState)
            #expect(!session.canUndo)
        }
    }

    @Test func earlyOpeningsAreForgivingAndPatienceHasAConsequence() {
        for level in LevelCatalog.all.prefix(5) {
            for direction in MoveDirection.allCases {
                let branch = GameEngine.applyMove(level.initialState, direction: direction)
                #expect(PuzzleVerifier.solve(branch.state).status == .solved, "Level \(level.id) opening \(direction)")
            }
        }
        let patience = LevelCatalog.all[7].initialState
        let tempting = GameEngine.applyMove(patience, direction: .right)
        #expect(!tempting.newlyBondedPairIDs.isEmpty)
        #expect(PuzzleVerifier.solve(tempting.state).status == .unsolvable)
        let patient = GameEngine.applyMove(patience, direction: .left)
        #expect(patient.newlyBondedPairIDs.isEmpty)
        #expect(PuzzleVerifier.solve(patient.state).status == .solved)
    }

    @Test func thousandsOfTransitionsMatchIndependentCellStepModel() {
        for level in LevelCatalog.all {
            var frontier = [level.initialState]
            var visited: Set<String> = [level.initialState.canonicalKey]
            var index = 0
            while index < min(80, frontier.count) {
                let state = frontier[index]
                for direction in MoveDirection.allCases {
                    let actual = GameEngine.applyMove(state, direction: direction)
                    let reference = cellStepReference(state, direction: direction)
                    #expect(actual.state == reference, "Level \(level.id), \(direction)")
                    #expect(actual.state.validationIssues.isEmpty)
                    var shuffled = state
                    shuffled.tiles.reverse()
                    let reordered = GameEngine.applyMove(shuffled, direction: direction)
                    #expect(actual.state.canonicalKey == reordered.state.canonicalKey)
                    #expect(actual.newlyBondedPairIDs == reordered.newlyBondedPairIDs)
                    if visited.insert(actual.state.canonicalKey).inserted { frontier.append(actual.state) }
                }
                index += 1
            }
        }
    }

    // Unlike the engine's ordered full compression, this model starts with every
    // occupied cell and moves one tile by one cell at a time, repeating to rest.
    // It independently checks collisions, order preservation and end-only bonding.
    private func cellStepReference(_ original: GameState, direction: MoveDirection) -> GameState {
        if original.isSolved { return original }
        var state = original
        var occupied = Set(state.walls + state.tiles.map(\.position))
        var anythingMoved = true
        while anythingMoved {
            anythingMoved = false
            for index in state.tiles.indices where !state.tiles[index].isBonded {
                let oldPosition = state.tiles[index].position
                let destination = GridPosition(row: oldPosition.row + direction.rowOffset, column: oldPosition.column + direction.columnOffset)
                if (0..<state.size).contains(destination.row), (0..<state.size).contains(destination.column), !occupied.contains(destination) {
                    occupied.remove(oldPosition)
                    occupied.insert(destination)
                    state.tiles[index].position = destination
                    anythingMoved = true
                }
            }
        }
        for first in state.tiles.indices {
            for second in state.tiles.indices where first < second {
                if state.tiles[first].pairID == state.tiles[second].pairID {
                    let a = state.tiles[first].position, b = state.tiles[second].position
                    if abs(a.row - b.row) + abs(a.column - b.column) == 1 {
                        state.tiles[first].isBonded = true
                        state.tiles[second].isBonded = true
                    }
                }
            }
        }
        if state != original { state.moveCount += 1 }
        return state
    }
}
