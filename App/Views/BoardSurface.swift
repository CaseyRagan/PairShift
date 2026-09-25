import SwiftUI
import SpriteKit

/// Owns the native SKView explicitly so scene installation is independent of
/// SwiftUI's view reconstruction and the application's initial active phase.
struct BoardSurface: UIViewRepresentable {
    let scene: BoardScene
    let paused: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.allowsTransparency = true
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        view.delegate = context.coordinator
        // Install the scene before applying lifecycle pause state. This ensures
        // an initial inactive SwiftUI phase cannot skip scene attachment.
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        if view.scene !== scene { view.presentScene(scene) }
        let wasPaused = view.isPaused
        view.isPaused = paused
        if wasPaused && !paused { scene.resumeRendering() }
    }

    static func dismantleUIView(_ view: SKView, coordinator: Coordinator) {
        view.isPaused = true
        view.delegate = nil
        view.presentScene(nil)
    }

    @MainActor
    final class Coordinator: NSObject, @MainActor SKViewDelegate {
        func view(_ view: SKView, shouldRenderAtTime time: TimeInterval) -> Bool {
            (view.scene as? BoardScene)?.shouldRenderFrame(at: time) ?? true
        }
    }
}
