import Combine
import Foundation
import PairShiftCore
import UIKit

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var session: GameSession
    @Published private(set) var levelIndex: Int
    @Published private(set) var completedLevelIDs: Set<Int>
    @Published private(set) var bestMoves: [Int: Int]
    @Published private(set) var saveFailed = false
    @Published var settings: GameSettings {
        didSet {
            guard settings != oldValue else { return }
            if !settings.soundEnabled || !settings.hapticsEnabled { feedback.stop() }
            scheduleSave()
        }
    }

    let levels: [LevelDefinition]
    var state: GameState { session.state }
    var level: LevelDefinition { levels[levelIndex] }
    var canUndo: Bool { session.canUndo }
    var canGoNext: Bool { state.isSolved && levelIndex + 1 < levels.count }

    private let persistence: ProgressPersistence
    private let feedback: any GameFeedback
    private var saveTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var active = true
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var saveSequence = 0

    init(saveURL: URL? = nil, feedback: (any GameFeedback)? = nil) {
        let catalog = LevelCatalog.all
        precondition(!catalog.isEmpty, "PairShift requires at least one puzzle.")
        let persistence = ProgressPersistence(url: saveURL ?? ProgressPersistence.defaultURL)
        let saved = persistence.load()
        let validIDs = Set(catalog.map(\.id))
        var restoredCompleted = saved?.completedLevelIDs.intersection(validIDs) ?? []
        var restoredBest = saved?.bestMoves.filter { validIDs.contains($0.key) && $0.value > 0 } ?? [:]
        let savedIndex = saved.flatMap { save in catalog.firstIndex { $0.id == save.currentLevelID } } ?? 0
        // Even a well-formed save cannot skip the campaign's unlocking rule.
        let unlocked = savedIndex == 0 || restoredCompleted.contains(catalog[savedIndex].id)
            || restoredCompleted.contains(catalog[savedIndex - 1].id)
        let restoredIndex = unlocked ? savedIndex : 0
        let initial = catalog[restoredIndex].initialState
        let restoredSession: GameSession
        if let saved, Self.isValid(saved.session, for: initial) {
            restoredSession = saved.session
        } else {
            restoredSession = GameSession(initialState: initial)
        }
        // A save may have been interrupted between the last frame and its UI.
        if restoredSession.state.isSolved {
            restoredCompleted.insert(catalog[restoredIndex].id)
            restoredBest[catalog[restoredIndex].id] = min(restoredBest[catalog[restoredIndex].id] ?? .max, restoredSession.state.moveCount)
        }
        levels = catalog
        self.persistence = persistence
        self.feedback = feedback ?? FeedbackService()
        completedLevelIDs = restoredCompleted
        bestMoves = restoredBest
        settings = saved?.settings ?? GameSettings()
        levelIndex = restoredIndex
        session = restoredSession
    }

    @discardableResult
    func move(_ direction: MoveDirection) -> MoveResult? {
        guard active, !state.isSolved else { return nil }
        var next = session
        let result = next.move(direction)
        guard result.didChange else { return nil }
        cancelFeedback()
        session = next
        if result.state.isSolved {
            completedLevelIDs.insert(level.id)
            bestMoves[level.id] = min(bestMoves[level.id] ?? .max, result.state.moveCount)
        }
        feedback.play(.move, settings: settings)
        if !result.newlyBondedPairIDs.isEmpty {
            let count = result.newlyBondedPairIDs.count
            let solved = result.state.isSolved
            feedbackTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
                guard let self, self.active, !Task.isCancelled else { return }
                self.feedback.play(.bond(count), settings: self.settings)
                if solved {
                    do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
                    guard self.active, !Task.isCancelled else { return }
                    self.feedback.play(.complete, settings: self.settings)
                }
            }
        }
        scheduleSave()
        return result
    }

    func undo() {
        guard active, canUndo else { return }
        cancelFeedback(stopPlaying: true)
        var next = session
        guard next.undo() else { return }
        session = next
        feedback.play(.undo, settings: settings)
        scheduleSave()
    }

    func restart() {
        cancelFeedback(stopPlaying: true)
        session = GameSession(initialState: level.initialState)
        scheduleSave()
    }

    func selectLevel(id: Int) {
        guard let index = levels.firstIndex(where: { $0.id == id }), isUnlocked(levels[index]) else { return }
        cancelFeedback(stopPlaying: true)
        if index == levelIndex, !state.isSolved { return }
        levelIndex = index
        session = GameSession(initialState: levels[index].initialState)
        scheduleSave()
    }

    func nextLevel() {
        guard canGoNext else { return }
        selectLevel(id: levels[levelIndex + 1].id)
    }

    func isUnlocked(_ level: LevelDefinition) -> Bool {
        guard let index = levels.firstIndex(where: { $0.id == level.id }) else { return false }
        return index == 0 || completedLevelIDs.contains(level.id) || completedLevelIDs.contains(levels[index - 1].id)
    }

    func setActive(_ isActive: Bool) {
        active = isActive
        if !isActive {
            cancelFeedback(stopPlaying: true)
            saveNow()
        }
    }

    /// Stops a pending board cue when another screen covers the board.
    func stopFeedback() {
        cancelFeedback(stopPlaying: true)
    }

    /// Enqueues the current snapshot immediately. Encoding and disk work remain off
    /// the main actor; an iOS background task protects a lifecycle-triggered write.
    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        if !active, backgroundTask == .invalid {
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Preserve puzzle") { [weak self] in
                Task { @MainActor in self?.endBackgroundTask() }
            }
        }
        let snapshot = SavedProgress(currentLevelID: level.id, session: session,
                                     completedLevelIDs: completedLevelIDs, bestMoves: bestMoves, settings: settings)
        saveSequence += 1
        let sequence = saveSequence
        persistence.write(snapshot) { [weak self] success in
            Task { @MainActor in
                guard let self, sequence == self.saveSequence else { return }
                self.saveFailed = !success
                self.endBackgroundTask()
            }
        }
    }

    /// Awaitable flush for tests and controlled export; normal play uses saveNow().
    func waitForPendingSave() async {
        saveNow()
        await persistence.waitForWrites()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(220)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    private func cancelFeedback(stopPlaying: Bool = false) {
        feedbackTask?.cancel()
        feedbackTask = nil
        if stopPlaying { feedback.stop() }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private static func isValid(_ session: GameSession, for expected: GameState) -> Bool {
        guard session.initialState == expected, expected.validationIssues.isEmpty,
              session.undoStack.count <= 10_000 else { return false }
        let states = session.undoStack + [session.state]
        guard states.first == expected else { return false }
        for (index, state) in states.enumerated() {
            guard state.validationIssues.isEmpty, state.size == expected.size, state.walls == expected.walls,
                  state.moveCount == expected.moveCount + index,
                  state.tiles.map({ [$0.id, $0.pairID] }) == expected.tiles.map({ [$0.id, $0.pairID] }) else { return false }
            if index > 0 {
                let previous = states[index - 1]
                guard !previous.isSolved, MoveDirection.allCases.contains(where: {
                    let result = GameEngine.applyMove(previous, direction: $0)
                    return result.didChange && result.state == state
                }) else { return false }
            }
        }
        return true
    }
}
