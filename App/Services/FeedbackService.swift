import AVFoundation
import CoreHaptics
import UIKit

enum FeedbackCue: Equatable, Sendable {
    case move
    case bond(Int)
    case complete
    case undo
}

@MainActor
protocol GameFeedback: AnyObject {
    func play(_ cue: FeedbackCue, settings: GameSettings)
    func stop()
}

/// Original, synthesized one-shot cues. No assets, network, or continuous audio.
/// The ambient audio category keeps other audio playing and honors the silent switch.
@MainActor
final class FeedbackService: GameFeedback {
    private enum SoundKind: CaseIterable, Sendable {
        case move, bond, multiBond, complete, undo
    }

    private var players: [SoundKind: AVAudioPlayer] = [:]
    private var audioReady = false
    private var hapticEngine: CHHapticEngine?
    private var hapticPlayer: (any CHHapticPatternPlayer)?
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let successFeedback = UINotificationFeedbackGenerator()

    init() {
        // PCM synthesis is performed away from the first touch and the render loop.
        Task.detached(priority: .utility) { [weak self] in
            let clips = SoundKind.allCases.map { ($0, Self.synthesize($0)) }
            await self?.install(clips)
        }
    }

    func play(_ cue: FeedbackCue, settings: GameSettings) {
        guard UIApplication.shared.applicationState != .background else { return }
        if settings.hapticsEnabled { playHaptic(cue) }
        guard settings.soundEnabled else { return }
        if !audioReady {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                audioReady = true
            } catch {
                // A competing audio session must never prevent a puzzle move.
                return
            }
        }
        let kind: SoundKind
        switch cue {
        case .move: kind = .move
        case .bond(let count): kind = count > 1 ? .multiBond : .bond
        case .complete: kind = .complete
        case .undo: kind = .undo
        }
        guard let player = players[kind] else { return }
        player.currentTime = 0
        player.play()
    }

    func stop() {
        players.values.forEach { $0.stop() }
        try? hapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        hapticPlayer = nil
        hapticEngine?.stop(completionHandler: nil)
        if audioReady {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            audioReady = false
        }
    }

    private func install(_ clips: [(SoundKind, Data)]) {
        for (kind, data) in clips {
            guard let player = try? AVAudioPlayer(data: data) else { continue }
            player.prepareToPlay()
            players[kind] = player
        }
    }

    private func playHaptic(_ cue: FeedbackCue) {
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                if hapticEngine == nil { hapticEngine = try CHHapticEngine() }
                guard let engine = hapticEngine else { return }
                try engine.start()
                let events: [(Double, Float, Float)]
                switch cue {
                case .move: events = [(0, 0.20, 0.25)]
                case .bond(let count):
                    events = count > 1
                        ? [(0, 0.52, 0.68), (0.045, 0.32, 0.85), (0.10, 0.22, 0.5)]
                        : [(0, 0.45, 0.70), (0.045, 0.18, 0.4)]
                case .complete:
                    events = [(0, 0.55, 0.35), (0.075, 0.32, 0.55), (0.16, 0.65, 0.70)]
                case .undo: events = [(0, 0.17, 0.15)]
                }
                let pattern = try CHHapticPattern(events: events.map { time, intensity, sharpness in
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                    ], relativeTime: time)
                }, parameters: [])
                let player = try engine.makePlayer(with: pattern)
                hapticPlayer = player
                try player.start(atTime: CHHapticTimeImmediate)
                return
            } catch {
                hapticEngine = nil
            }
        }
        switch cue {
        case .move, .undo:
            softImpact.impactOccurred(intensity: 0.35)
            softImpact.prepare()
        case .bond:
            lightImpact.impactOccurred(intensity: 0.75)
            lightImpact.prepare()
        case .complete:
            successFeedback.notificationOccurred(.success)
            successFeedback.prepare()
        }
    }

    private nonisolated static func synthesize(_ kind: SoundKind) -> Data {
        let sampleRate = 44_100
        let duration: Double
        let volume: Double
        let frequencies: [Double]
        switch kind {
        case .move: duration = 0.055; volume = 0.10; frequencies = [260]
        case .bond: duration = 0.25; volume = 0.22; frequencies = [659.255, 1_318.51]
        case .multiBond: duration = 0.34; volume = 0.24; frequencies = [523.251, 659.255, 783.991]
        case .complete: duration = 0.68; volume = 0.23; frequencies = [523.251, 659.255, 783.991, 1_046.502]
        case .undo: duration = 0.10; volume = 0.11; frequencies = [349.228]
        }
        let count = Int(Double(sampleRate) * duration)
        var pcm = Data(capacity: count * 2)
        for index in 0..<count {
            let time = Double(index) / Double(sampleRate)
            var signal = 0.0
            for (voice, baseFrequency) in frequencies.enumerated() {
                let onset = (kind == .complete || kind == .multiBond) ? Double(voice) * 0.035 : 0
                let localTime = time - onset
                guard localTime >= 0 else { continue }
                let attack = min(1, localTime / 0.006)
                let release = min(1, max(0, duration - time) / 0.035)
                let decay = exp(-localTime * (kind == .complete ? 6 : 14))
                let pitchFall = kind == .move ? -700.0 : (kind == .undo ? -600.0 : 0)
                let phase = 2 * Double.pi * (baseFrequency * localTime + 0.5 * pitchFall * localTime * localTime)
                let tone = sin(phase) + 0.18 * sin(phase * 2.002) + 0.04 * sin(phase * 3.01)
                signal += tone * attack * decay * release / Double(frequencies.count)
            }
            let sample = Int16(max(-1, min(1, signal * volume)) * Double(Int16.max))
            append(UInt16(bitPattern: sample), to: &pcm)
        }

        var wav = Data("RIFF".utf8)
        append(UInt32(36 + pcm.count), to: &wav)
        wav.append(Data("WAVEfmt ".utf8))
        append(UInt32(16), to: &wav)
        append(UInt16(1), to: &wav) // PCM
        append(UInt16(1), to: &wav) // Mono
        append(UInt32(sampleRate), to: &wav)
        append(UInt32(sampleRate * 2), to: &wav)
        append(UInt16(2), to: &wav)
        append(UInt16(16), to: &wav)
        wav.append(Data("data".utf8))
        append(UInt32(pcm.count), to: &wav)
        wav.append(pcm)
        return wav
    }

    private nonisolated static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}
