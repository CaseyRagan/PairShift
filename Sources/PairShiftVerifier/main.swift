import Foundation
import PairShiftCore

struct LevelReport: Codable {
    let id: Int
    let title: String
    let size: Int
    let pairCount: Int
    let wallCount: Int
    let status: VerificationResult.Status
    let optimalMoves: Int?
    let solution: [MoveDirection]
    let visitedStateCount: Int
    let replayVerified: Bool
}

let arguments = CommandLine.arguments.dropFirst()
if arguments.contains("--help") {
    print("""
    PairShift content verifier
    Usage: swift run -c release pairshift-verify [--json] [--inspect] [--trace]
           swift run -c release pairshift-verify 'A..A/..../B..B/....'
    --json     Emit the shortest solution and replay result for every level.
    --inspect  Inspect solvability and new bonds after each opening direction.
    --trace    Inspect all branches along the shortest path (curation tool).
    Exit 0: every board is solved and replayed. Exit 1: verification failed.
    """)
    exit(0)
}
let isJSON = arguments.contains("--json")
let inspect = arguments.contains("--inspect")
let trace = arguments.contains("--trace")
let customRows = arguments.first(where: { $0.contains("/") })?.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
if let rows = customRows {
    let allowed = Set(".#ABCDEF")
    guard (2...8).contains(rows.count), rows.allSatisfy({ $0.count == rows.count && Set($0).isSubset(of: allowed) }) else {
        FileHandle.standardError.write(Data("Invalid board notation: use 2–8 square rows containing only ., #, or A–F.\n".utf8))
        exit(2)
    }
}
let levels = customRows.map { [LevelDefinition(id: 0, title: "Authored candidate", chapter: "", initialState: LevelCatalog.authoredState($0))] } ?? LevelCatalog.all
var reports: [LevelReport] = []
for level in levels {
    let result = PuzzleVerifier.solve(level.initialState)
    let replay = result.solution.reduce(level.initialState) { GameEngine.applyMove($0, direction: $1).state }
    let report = LevelReport(id: level.id, title: level.title, size: level.initialState.size, pairCount: level.initialState.totalPairCount, wallCount: level.initialState.walls.count, status: result.status, optimalMoves: result.optimalMoveCount, solution: result.solution, visitedStateCount: result.visitedStateCount, replayVerified: result.status == .solved && replay.isSolved && replay.moveCount == result.solution.count)
    reports.append(report)
    if !isJSON {
        let path = result.solution.map(\.symbol).joined(separator: " ")
        print("\(level.id). \(level.title): \(result.status.rawValue), \(result.optimalMoveCount.map(String.init) ?? "—") moves, \(result.visitedStateCount) states · \(path)")
        if !result.validationIssues.isEmpty { print(result.validationIssues.joined(separator: "\n")) }
        if inspect {
            for direction in MoveDirection.allCases {
                let moved = GameEngine.applyMove(level.initialState, direction: direction)
                let branch = PuzzleVerifier.solve(moved.state)
                print("  \(direction.symbol): bonds \(moved.newlyBondedPairIDs), \(branch.status.rawValue), \(branch.optimalMoveCount.map(String.init) ?? "—") remaining")
            }
        }
        if trace {
            var state = level.initialState
            for (index, optimalDirection) in result.solution.enumerated() {
                print("  Step \(index + 1), optimum \(optimalDirection.symbol)")
                for direction in MoveDirection.allCases {
                    let moved = GameEngine.applyMove(state, direction: direction)
                    guard moved.didChange else { continue }
                    let branch = PuzzleVerifier.solve(moved.state)
                    print("    \(direction.symbol): bonds \(moved.newlyBondedPairIDs), \(branch.status.rawValue), \(branch.optimalMoveCount.map(String.init) ?? "—") remaining")
                }
                state = GameEngine.applyMove(state, direction: optimalDirection).state
            }
        }
    }
}
if isJSON {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(data: try encoder.encode(reports), encoding: .utf8)!)
}
if reports.contains(where: { $0.status != .solved || !$0.replayVerified }) { exit(1) }
