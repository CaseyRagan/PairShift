import Foundation
import PairShiftCore

struct SavedProgress: Codable, Sendable {
    static let currentSchema = 1

    var schemaVersion = currentSchema
    var currentLevelID: Int
    var session: GameSession
    var completedLevelIDs: Set<Int>
    var bestMoves: [Int: Int]
    var settings: GameSettings
}

/// A serial writer preserves snapshot order; atomic replacement never leaves a
/// partially encoded save. This class has no mutable state shared across threads.
final class ProgressPersistence: @unchecked Sendable {
    let url: URL
    private let queue = DispatchQueue(label: "com.pairshift.progress", qos: .utility)

    init(url: URL) { self.url = url }

    static var defaultURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("PairShift", isDirectory: true)
            .appendingPathComponent("progress.json", isDirectory: false)
    }

    func load() -> SavedProgress? {
        // Defensive bound for malformed files, far above normal Journey saves.
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let length = attributes[.size] as? NSNumber,
              length.intValue <= 16_000_000,
              let data = try? Data(contentsOf: url),
              let save = try? JSONDecoder().decode(SavedProgress.self, from: data),
              save.schemaVersion == SavedProgress.currentSchema else { return nil }
        return save
    }

    func write(_ snapshot: SavedProgress, completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [url] in
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                completion(true)
            } catch {
                completion(false)
            }
        }
    }

    func waitForWrites() async {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume() }
        }
    }
}
