import PairShiftCore
import SpriteKit
import UIKit

/// Snapshot renderer. Puzzle rules stay in PairShiftCore; this scene owns only
/// presentation, gesture interpretation, and a short animation completion gate.
@MainActor
final class BoardScene: SKScene {
    var onSwipe: ((MoveDirection) -> Void)?
    var onAnimationFinished: (() -> Void)?

    private let trayLayer = SKNode()
    private let bridgeLayer = SKNode()
    private let tileLayer = SKNode()
    private let effectLayer = SKNode()
    private var tileNodes: [Int: SKSpriteNode] = [:]
    private var currentState: GameState?
    private var currentLightMode = false
    private var currentReduceMotion = false
    private var renderedGridSize = 0
    private var renderedSceneSize = CGSize.zero
    private var renderedLightMode: Bool?
    private var touchOrigin: CGPoint?
    private var trackedTouch: UITouch?
    private var gestureCommitted = false
    private var animationGeneration = 0
    private var renderUntil: TimeInterval = 0
    private var requestedRenderDuration: TimeInterval = 0.3
    private var minimumFramesRemaining = 4

    private let slideDuration: TimeInterval = 0.19

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        anchorPoint = .zero
        scaleMode = .resizeFill
        isUserInteractionEnabled = true
        trayLayer.zPosition = 0
        bridgeLayer.zPosition = 2
        tileLayer.zPosition = 3
        effectLayer.zPosition = 5
        addChild(trayLayer)
        addChild(bridgeLayer)
        addChild(tileLayer)
        addChild(effectLayer)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("Use init(size:)") }

    override func didMove(to view: SKView) {
        requestFrames(for: 0.3)
        view.allowsTransparency = true
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false
        if let currentState {
            render(currentState, previous: nil, animated: false)
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 1, size.height > 1, let currentState else { return }
        requestFrames(for: 0.3)
        // A SwiftUI relayout must never masquerade as another player move.
        render(currentState, previous: nil, animated: false)
    }

    func display(_ state: GameState, animated: Bool, reduceMotion: Bool, lightMode: Bool) {
        requestFrames(for: animated && !reduceMotion ? 0.95 : 0.15)
        if !animated || reduceMotion {
            // Undo, restart, level selection, and appearance changes replace
            // the visual snapshot, including any effects from the prior move.
            effectLayer.removeAllChildren()
        }
        let previous = currentState
        currentState = state
        currentReduceMotion = reduceMotion
        currentLightMode = lightMode
        animationGeneration += 1
        removeAction(forKey: "move-completion")
        render(state, previous: previous, animated: animated && !reduceMotion)

        if animated {
            let generation = animationGeneration
            // Root receives one completion for the newest snapshot, including
            // Reduce Motion moves, so buffered inputs cannot remain locked.
            let duration = reduceMotion ? 0.01 : slideDuration + 0.025
            run(.sequence([.wait(forDuration: duration), .run { [weak self] in
                guard let self, self.animationGeneration == generation else { return }
                self.onAnimationFinished?()
            }]), withKey: "move-completion")
        }
    }

    /// The native view can skip unchanged board frames after brief effects end.
    /// Its delegate remains alive, so the next input wakes drawing immediately.
    func shouldRenderFrame(at _: TimeInterval) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        if requestedRenderDuration > 0 {
            // Start when SKView is ready to present, not when SwiftUI first
            // requested the snapshot. Cold Metal setup can outlast that request.
            renderUntil = max(renderUntil, now + requestedRenderDuration)
            requestedRenderDuration = 0
        }
        if minimumFramesRemaining > 0 {
            minimumFramesRemaining -= 1
            return true
        }
        return now < renderUntil
    }

    func resumeRendering() {
        requestFrames(for: 0.3)
    }

    private func requestFrames(for duration: TimeInterval) {
        requestedRenderDuration = max(requestedRenderDuration, duration)
        // Even an unusually long first draw cannot consume the entire budget.
        minimumFramesRemaining = max(minimumFramesRemaining, 4)
    }

    private var boardRect: CGRect {
        let side = max(1, min(size.width, size.height) - 8)
        return CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2,
                      width: side, height: side)
    }

    private var gridRect: CGRect { boardRect.insetBy(dx: boardRect.width * 0.051, dy: boardRect.height * 0.051) }

    private func point(for position: GridPosition, gridSize: Int) -> CGPoint {
        let rect = gridRect
        let cell = rect.width / CGFloat(max(1, gridSize))
        return CGPoint(x: rect.minX + (CGFloat(position.column) + 0.5) * cell,
                       y: rect.maxY - (CGFloat(position.row) + 0.5) * cell)
    }

    private func render(_ state: GameState, previous: GameState?, animated: Bool) {
        guard size.width > 1, size.height > 1, state.size > 0 else { return }
        let gridChanged = renderedGridSize != state.size || renderedSceneSize != size || renderedLightMode != currentLightMode
        if gridChanged {
            rebuildTray(state)
        } else if previous.map({ $0.walls != state.walls }) ?? true {
            rebuildTray(state)
        }
        let cell = gridRect.width / CGFloat(state.size)
        let oldTiles = Dictionary(uniqueKeysWithValues: (previous?.tiles ?? []).map { ($0.id, $0) })
        let liveIDs = Set(state.tiles.map(\.id))
        for id in tileNodes.keys.filter({ !liveIDs.contains($0) }) {
            tileNodes.removeValue(forKey: id)?.removeFromParent()
        }

        let mayAnimate = animated && !gridChanged
        var newlyBondedPairs = Set<Int>()
        for tile in state.tiles {
            let node: SKSpriteNode
            if let existing = tileNodes[tile.id] {
                node = existing
            } else {
                node = SKSpriteNode()
                node.name = "tile-\(tile.id)"
                tileLayer.addChild(node)
                tileNodes[tile.id] = node
            }
            node.removeAllActions()
            node.setScale(1)
            node.alpha = 1
            node.texture = PairTileArtwork.texture(for: tile.pairID, lightMode: currentLightMode, bonded: tile.isBonded)
            node.size = CGSize(width: cell * 1.13, height: cell * 1.13)
            let destination = point(for: tile.position, gridSize: state.size)
            let isNewBond = tile.isBonded && oldTiles[tile.id]?.isBonded == false
            if isNewBond { newlyBondedPairs.insert(tile.pairID) }

            if mayAnimate, oldTiles[tile.id] != nil {
                let movement = SKAction.move(to: destination, duration: slideDuration)
                movement.timingMode = .easeOut
                node.run(movement, withKey: "slide")
                if isNewBond {
                    node.run(.sequence([
                        .wait(forDuration: slideDuration * 0.78),
                        .scale(to: 1.045, duration: 0.08),
                        .scale(to: 1, duration: 0.15)
                    ]), withKey: "bond-arrival")
                }
            } else {
                node.position = destination
            }
        }

        bridgeLayer.removeAllActions()
        bridgeLayer.removeAllChildren()
        drawBridges(state, newlyBondedPairs: mayAnimate ? newlyBondedPairs : [], delay: mayAnimate ? slideDuration : 0)
        if mayAnimate && !newlyBondedPairs.isEmpty {
            let positions = state.tiles.filter { newlyBondedPairs.contains($0.pairID) }
            for tile in positions {
                bondAccent(at: point(for: tile.position, gridSize: state.size), pairID: tile.pairID, cell: cell)
            }
        }
        if mayAnimate, state.isSolved, previous?.isSolved == false {
            completionRipple()
        }
    }

    private func rebuildTray(_ state: GameState) {
        renderedGridSize = state.size
        renderedSceneSize = size
        renderedLightMode = currentLightMode
        trayLayer.removeAllChildren()
        effectLayer.removeAllChildren()
        let tray = SKSpriteNode(texture: PairTileArtwork.trayTexture(lightMode: currentLightMode))
        tray.size = boardRect.size
        tray.position = CGPoint(x: boardRect.midX, y: boardRect.midY)
        trayLayer.addChild(tray)
        let cell = gridRect.width / CGFloat(state.size)
        let walls = Set(state.walls)
        for row in 0..<state.size {
            for column in 0..<state.size {
                let position = GridPosition(row: row, column: column)
                let wall = walls.contains(position)
                let node = SKSpriteNode(texture: wall
                                        ? PairTileArtwork.wallTexture(lightMode: currentLightMode)
                                        : PairTileArtwork.wellTexture(lightMode: currentLightMode))
                let width = cell * (wall ? 1.02 : 0.89)
                node.size = CGSize(width: width, height: width)
                node.position = point(for: position, gridSize: state.size)
                node.zPosition = 1
                trayLayer.addChild(node)
            }
        }
    }

    private func drawBridges(_ state: GameState, newlyBondedPairs: Set<Int>, delay: TimeInterval) {
        let pairs = Dictionary(grouping: state.tiles.filter(\.isBonded), by: \.pairID)
        let cell = gridRect.width / CGFloat(state.size)
        for (pairID, tiles) in pairs {
            guard tiles.count == 2 else { continue }
            let start = point(for: tiles[0].position, gridSize: state.size)
            let end = point(for: tiles[1].position, gridSize: state.size)
            let path = CGMutablePath()
            path.move(to: start)
            path.addLine(to: end)
            let holder = SKNode()
            let halo = SKShapeNode(path: path)
            halo.strokeColor = PairTileArtwork.color(for: pairID).withAlphaComponent(currentLightMode ? 0.38 : 0.72)
            halo.lineWidth = cell * 0.073
            halo.glowWidth = cell * 0.10
            halo.blendMode = .add
            holder.addChild(halo)
            let core = SKShapeNode(path: path)
            core.strokeColor = PairTileArtwork.color(for: pairID).withAlphaComponent(0.97)
            core.lineWidth = max(2, cell * 0.041)
            core.glowWidth = 1.5
            holder.addChild(core)
            let highlight = SKShapeNode(path: path)
            highlight.strokeColor = UIColor.white.withAlphaComponent(0.88)
            highlight.lineWidth = max(1, cell * 0.015)
            holder.addChild(highlight)
            bridgeLayer.addChild(holder)
            if newlyBondedPairs.contains(pairID) {
                holder.alpha = 0
                holder.run(.sequence([.wait(forDuration: delay * 0.8), .fadeIn(withDuration: 0.09)]))
            }
        }
    }

    private func bondAccent(at position: CGPoint, pairID: Int, cell: CGFloat) {
        let glow = SKSpriteNode(texture: PairTileArtwork.glowTexture())
        glow.color = PairTileArtwork.color(for: pairID)
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.position = position
        glow.size = CGSize(width: cell * 1.6, height: cell * 1.6)
        glow.alpha = 0
        effectLayer.addChild(glow)
        glow.run(.sequence([
            .wait(forDuration: slideDuration * 0.8),
            .fadeAlpha(to: currentLightMode ? 0.22 : 0.32, duration: 0.06),
            .group([.fadeOut(withDuration: 0.32), .scale(to: 1.23, duration: 0.32)]),
            .removeFromParent()
        ]))
    }

    private func completionRipple() {
        let ripple = SKShapeNode(rectOf: gridRect.size, cornerRadius: 22)
        ripple.position = CGPoint(x: boardRect.midX, y: boardRect.midY)
        ripple.strokeColor = UIColor(red: 0.70, green: 0.88, blue: 1, alpha: 0.65)
        ripple.lineWidth = 1
        ripple.glowWidth = 3
        ripple.alpha = 0
        effectLayer.addChild(ripple)
        ripple.run(.sequence([
            .wait(forDuration: slideDuration + 0.08),
            .fadeIn(withDuration: 0.12),
            .group([.scale(to: 1.06, duration: 0.50), .fadeOut(withDuration: 0.50)]),
            .removeFromParent()
        ]))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard trackedTouch == nil, let touch = touches.first else { return }
        trackedTouch = touch
        touchOrigin = touch.location(in: self)
        gestureCommitted = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !gestureCommitted, let trackedTouch, touches.contains(trackedTouch) else { return }
        commitGestureIfNeeded(at: trackedTouch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let trackedTouch, touches.contains(trackedTouch) else { return }
        if !gestureCommitted { commitGestureIfNeeded(at: trackedTouch.location(in: self)) }
        resetGesture()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { resetGesture() }

    private func commitGestureIfNeeded(at point: CGPoint) {
        guard let touchOrigin else { return }
        let dx = point.x - touchOrigin.x
        let dy = point.y - touchOrigin.y
        let threshold = max(16, min(24, boardRect.width * 0.05))
        guard max(abs(dx), abs(dy)) >= threshold else { return }
        gestureCommitted = true
        if abs(dx) > abs(dy) {
            onSwipe?(dx > 0 ? .right : .left)
        } else {
            onSwipe?(dy > 0 ? .up : .down)
        }
    }

    private func resetGesture() {
        trackedTouch = nil
        touchOrigin = nil
        gestureCommitted = false
    }
}
