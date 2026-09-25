import Foundation

public enum MoveDirection: String, CaseIterable, Codable, Sendable {
    case up, right, down, left

    public var rowOffset: Int { self == .up ? -1 : self == .down ? 1 : 0 }
    public var columnOffset: Int { self == .left ? -1 : self == .right ? 1 : 0 }
    public var symbol: String {
        switch self { case .up: "↑"; case .right: "→"; case .down: "↓"; case .left: "←" }
    }
}

public struct GridPosition: Codable, Hashable, Sendable {
    public var row: Int
    public var column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    public func isAdjacent(to other: GridPosition) -> Bool {
        abs(row - other.row) + abs(column - other.column) == 1
    }

    public func moved(_ direction: MoveDirection) -> GridPosition {
        .init(row: row + direction.rowOffset, column: column + direction.columnOffset)
    }
}

public struct PuzzleTile: Codable, Equatable, Sendable, Identifiable {
    public var id: Int
    public var pairID: Int
    public var position: GridPosition
    public var isBonded: Bool

    public init(id: Int, pairID: Int, position: GridPosition, isBonded: Bool = false) {
        self.id = id
        self.pairID = pairID
        self.position = position
        self.isBonded = isBonded
    }
}

public struct GameState: Codable, Equatable, Sendable {
    public var size: Int
    public var tiles: [PuzzleTile]
    public var walls: [GridPosition]
    public var moveCount: Int

    public init(size: Int, tiles: [PuzzleTile], walls: [GridPosition] = [], moveCount: Int = 0) {
        self.size = size
        self.tiles = tiles
        self.walls = walls
        self.moveCount = moveCount
    }

    public var isSolved: Bool { !tiles.isEmpty && tiles.allSatisfy(\.isBonded) }
    public var bondedPairCount: Int { Set(tiles.filter(\.isBonded).map(\.pairID)).count }
    public var totalPairCount: Int { Set(tiles.map(\.pairID)).count }

    /// Tile identities and order have no effect on the puzzle. A pair's two members
    /// are interchangeable; move count is deliberately absent from the search key.
    public var canonicalKey: String {
        let obstacles = walls.map { $0.row * size + $0.column }.sorted().map(String.init).joined(separator: ",")
        let pairs = Dictionary(grouping: tiles, by: \.pairID).sorted { $0.key < $1.key }.map { pairID, members in
            let cells = members.map { "\($0.position.row * size + $0.position.column):\($0.isBonded ? 1 : 0)" }.sorted().joined(separator: ",")
            return "\(pairID)=\(cells)"
        }.joined(separator: ";")
        return "\(size)|\(obstacles)|\(pairs)"
    }

    /// Useful at content and persistence boundaries. Invalid data is never executed.
    public var validationIssues: [String] {
        var issues: [String] = []
        if !(2...8).contains(size) { issues.append("Board size must be between 2 and 8.") }
        if moveCount < 0 { issues.append("Move count cannot be negative.") }
        if tiles.isEmpty { issues.append("A puzzle must contain at least one pair.") }
        if Set(tiles.map(\.id)).count != tiles.count { issues.append("Tile IDs must be unique.") }
        if Set(tiles.map(\.position)).count != tiles.count { issues.append("Tiles overlap.") }
        if Set(walls).count != walls.count { issues.append("Walls overlap.") }
        let wallSet = Set(walls)
        if tiles.contains(where: { wallSet.contains($0.position) }) { issues.append("A tile overlaps a wall.") }
        if (tiles.map(\.position) + walls).contains(where: { !(0..<size).contains($0.row) || !(0..<size).contains($0.column) }) {
            issues.append("A cell is outside the board.")
        }
        for (pairID, members) in Dictionary(grouping: tiles, by: \.pairID).sorted(by: { $0.key < $1.key }) {
            if pairID < 0 { issues.append("Pair IDs cannot be negative.") }
            guard members.count == 2 else { issues.append("Pair \(pairID) must have exactly two tiles."); continue }
            if members[0].isBonded != members[1].isBonded { issues.append("Pair \(pairID) is only partly bonded.") }
            if members[0].isBonded && !members[0].position.isAdjacent(to: members[1].position) {
                issues.append("Bonded pair \(pairID) must be adjacent.")
            }
        }
        return issues
    }
}

public struct MoveResult: Equatable, Sendable {
    public let state: GameState
    public let didChange: Bool
    public let newlyBondedPairIDs: [Int]

    public init(state: GameState, didChange: Bool, newlyBondedPairIDs: [Int]) {
        self.state = state
        self.didChange = didChange
        self.newlyBondedPairIDs = newlyBondedPairIDs
    }
}
