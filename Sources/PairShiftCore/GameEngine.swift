import Foundation

public enum GameEngine {
    /// Fully compresses each line from its leading edge, then resolves all bonds.
    /// No animation, clock, I/O, or random value participates in a move.
    public static func applyMove(_ state: GameState, direction: MoveDirection) -> MoveResult {
        guard state.validationIssues.isEmpty, !state.isSolved else {
            return .init(state: state, didChange: false, newlyBondedPairIDs: [])
        }
        return resolveValidMove(state, direction: direction)
    }

    // The verifier validates its root once; every successor preserves validity.
    static func resolveValidMove(_ state: GameState, direction: MoveDirection) -> MoveResult {
        var next = state
        var occupied = Set(state.walls)
        occupied.formUnion(state.tiles.filter(\.isBonded).map(\.position))
        let movingIndices = state.tiles.indices.filter { !state.tiles[$0].isBonded }.sorted { lhs, rhs in
            let a = state.tiles[lhs].position
            let b = state.tiles[rhs].position
            switch direction {
            case .up: return a.row == b.row ? a.column < b.column : a.row < b.row
            case .down: return a.row == b.row ? a.column < b.column : a.row > b.row
            case .left: return a.column == b.column ? a.row < b.row : a.column < b.column
            case .right: return a.column == b.column ? a.row < b.row : a.column > b.column
            }
        }
        for index in movingIndices {
            var position = next.tiles[index].position
            while true {
                let candidate = position.moved(direction)
                guard (0..<state.size).contains(candidate.row), (0..<state.size).contains(candidate.column), !occupied.contains(candidate) else { break }
                position = candidate
            }
            next.tiles[index].position = position
            occupied.insert(position)
        }
        var newBonds: [Int] = []
        let pairs = Dictionary(grouping: next.tiles.indices, by: { next.tiles[$0].pairID })
        for pairID in pairs.keys.sorted() {
            guard let members = pairs[pairID], members.count == 2 else { continue }
            let first = members[0], second = members[1]
            if !next.tiles[first].isBonded && next.tiles[first].position.isAdjacent(to: next.tiles[second].position) {
                next.tiles[first].isBonded = true
                next.tiles[second].isBonded = true
                newBonds.append(pairID)
            }
        }
        let changed = next.tiles != state.tiles
        if changed { next.moveCount += 1 }
        return .init(state: next, didChange: changed, newlyBondedPairIDs: newBonds)
    }
}

/// Value-semantic snapshots preserve identity, bonding, and move count exactly.
/// Encode the session to resume a puzzle, including its complete undo history.
public struct GameSession: Codable, Equatable, Sendable {
    public let initialState: GameState
    public private(set) var state: GameState
    public private(set) var undoStack: [GameState]
    public var canUndo: Bool { !undoStack.isEmpty }

    public init(initialState: GameState) {
        self.initialState = initialState
        self.state = initialState
        self.undoStack = []
    }

    @discardableResult public mutating func move(_ direction: MoveDirection) -> MoveResult {
        let result = GameEngine.applyMove(state, direction: direction)
        if result.didChange {
            undoStack.append(state)
            state = result.state
        }
        return result
    }

    @discardableResult public mutating func undo() -> Bool {
        guard let previous = undoStack.popLast() else { return false }
        state = previous
        return true
    }

    public mutating func restart() {
        state = initialState
        undoStack.removeAll(keepingCapacity: true)
    }
}
