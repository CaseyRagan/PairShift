import Foundation

public struct LevelDefinition: Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let chapter: String
    public let hint: String?
    public let initialState: GameState

    public init(id: Int, title: String, chapter: String, hint: String? = nil, initialState: GameState) {
        self.id = id
        self.title = title
        self.chapter = chapter
        self.hint = hint
        self.initialState = initialState
    }
}

/// Twenty authored boards. Letters are the six visual identities: circle, star,
/// triangle, diamond, crescent, wave. Dots are empty cells; # is a stone.
/// No board is generated during play. The verifier independently replays each one.
public enum LevelCatalog {
    public static let all: [LevelDefinition] = [
        level(1, "First light", "First light", "Swipe across the board. Bring matching symbols together.", [
            "A..A", "....", "B..B", "...."
        ]),
        level(2, "In step", "First light", "One swipe moves every loose tile.", [
            "A..B", "....", "..A.", "B..."
        ]),
        level(3, "A small turn", "First light", "Pairs stay where they connect.", [
            "A.B.", "C...", ".A.C", "B..."
        ]),
        level(4, "Together", "First light", nil, [
            "A..B", ".C..", "..A.", "B.C."
        ]),
        level(5, "Close quarters", "First light", "A connected pair can guide another.", [
            "A.B.", ".C..", "B.A.", "..C."
        ]),
        level(6, "Finding flow", "Finding flow", nil, [
            "A.B.", "C.D.", ".A.C", "BD.."
        ]),
        level(7, "The shape of it", "Finding flow", nil, [
            "A.C.", ".B.D", "C.A.", "D.B."
        ]),
        level(8, "A little patience", "Finding flow", "Sometimes a pair is worth waiting for.", [
            "A...", ".B.C", "C...", ".A.B"
        ]),
        level(9, "The long way", "Finding flow", nil, [
            "A...", "DB.C", "C...", ".ADB"
        ]),
        level(10, "Room to breathe", "Finding flow", nil, [
            "A..D", ".B.C", "C...", ".ADB"
        ]),
        level(11, "Between moments", "Still stones", nil, [
            "A.E.D", ".B..C", "C....", ".A.DB", "E...."
        ]),
        level(12, "Hold that thought", "Still stones", nil, [
            "AD...", ".B..C", "C.E..", ".A.DB", "...E."
        ]),
        level(13, "Still stones", "Still stones", "Stone stays still. Find a way around.", [
            "A...B", ".C...", "..#..", "B..A.", "..C.."
        ]),
        level(14, "A quiet corner", "Still stones", nil, [
            "A..B.", ".#..C", "D.A..", "B..#.", ".C.D."
        ]),
        level(15, "Narrow passage", "Still stones", nil, [
            "A...B", ".C#..", "D.A.C", "..#B.", "...D."
        ]),
        level(16, "Around the bend", "In harmony", nil, [
            "A.B.C", ".#D..", "E...A", "B.D#.", "C..E."
        ]),
        level(17, "Ripple effect", "In harmony", nil, [
            "A.B.C", "D.E.F", "..A..", "B.D.C", "E...F"
        ]),
        level(18, "A different route", "In harmony", nil, [
            "A..BC", "D.#.E", ".F.A.", "B.D.F", "CE..."
        ]),
        level(19, "Almost home", "In harmony", nil, [
            "A.B.C", ".D#E.", "F...A", "B.E.D", "C.F.."
        ]),
        level(20, "In harmony", "In harmony", nil, [
            "A.B.C", "D.E.F", ".#A#.", "B.C.D", "E...F"
        ])
    ]

    private static func level(_ id: Int, _ title: String, _ chapter: String, _ hint: String?, _ rows: [String]) -> LevelDefinition {
        let state = authoredState(rows)
        precondition(state.validationIssues.isEmpty, "Invalid authored level \(id): \(state.validationIssues)")
        return .init(id: id, title: title, chapter: chapter, hint: hint, initialState: state)
    }

    /// A compact, deterministic notation used by the curation CLI and tests.
    /// Each A–F letter must occur twice; callers validate notation before parsing.
    public static func authoredState(_ rows: [String]) -> GameState {
        var tiles: [PuzzleTile] = []
        var walls: [GridPosition] = []
        for (row, cells) in rows.enumerated() {
            for (column, character) in cells.enumerated() {
                let position = GridPosition(row: row, column: column)
                if character == "#" { walls.append(position) }
                if let ascii = character.asciiValue, (65...70).contains(ascii) {
                    tiles.append(.init(id: tiles.count, pairID: Int(ascii - 65), position: position))
                }
            }
        }
        return .init(size: rows.count, tiles: tiles, walls: walls)
    }
}
