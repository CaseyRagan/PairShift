import Foundation

public struct VerificationResult: Codable, Sendable {
    public enum Status: String, Codable, Sendable { case solved, unsolvable, searchLimitReached, invalid }
    public let status: Status
    public let solution: [MoveDirection]
    public let visitedStateCount: Int
    public let validationIssues: [String]
    public var optimalMoveCount: Int? { status == .solved ? solution.count : nil }
}

public enum PuzzleVerifier {
    /// Exhaustive breadth-first search certifies the first solution as shortest.
    /// Intended for content tools and tests, never the gameplay/rendering thread.
    public static func solve(_ initialState: GameState, stateLimit: Int = 250_000) -> VerificationResult {
        let issues = initialState.validationIssues
        guard issues.isEmpty else { return .init(status: .invalid, solution: [], visitedStateCount: 0, validationIssues: issues) }
        if initialState.isSolved { return .init(status: .solved, solution: [], visitedStateCount: 1, validationIssues: []) }
        guard stateLimit > 0 else { return .init(status: .searchLimitReached, solution: [], visitedStateCount: 0, validationIssues: []) }
        struct SearchNode { let state: GameState; let parent: Int; let direction: MoveDirection? }
        var queue = [SearchNode(state: initialState, parent: -1, direction: nil)]
        var visited: Set<String> = [initialState.canonicalKey]
        var head = 0
        while head < queue.count {
            let current = queue[head]
            for direction in MoveDirection.allCases {
                let result = GameEngine.resolveValidMove(current.state, direction: direction)
                guard result.didChange else { continue }
                let key = result.state.canonicalKey
                guard !visited.contains(key) else { continue }
                guard visited.count < stateLimit else {
                    return .init(status: .searchLimitReached, solution: [], visitedStateCount: visited.count, validationIssues: [])
                }
                visited.insert(key)
                if result.state.isSolved {
                    var path = [direction]
                    var ancestor = head
                    while queue[ancestor].parent >= 0 {
                        path.append(queue[ancestor].direction!)
                        ancestor = queue[ancestor].parent
                    }
                    return .init(status: .solved, solution: path.reversed(), visitedStateCount: visited.count, validationIssues: [])
                }
                queue.append(SearchNode(state: result.state, parent: head, direction: direction))
            }
            head += 1
        }
        return .init(status: .unsolvable, solution: [], visitedStateCount: visited.count, validationIssues: [])
    }
}
