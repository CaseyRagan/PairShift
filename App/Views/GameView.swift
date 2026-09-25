import SwiftUI
import SpriteKit
import PairShiftCore

@MainActor
struct GameView: View {
    @ObservedObject var store: GameStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("showDirectionControls") private var showDirectionControls = false
    @State private var scene = BoardScene(size: CGSize(width: 360, height: 360))
    @State private var showJourney = false
    @State private var showSettings = false
    @State private var isAnimating = false
    @State private var queuedDirection: MoveDirection?
    @State private var animateNextState = false

    private var reducedMotion: Bool { systemReduceMotion || store.settings.reduceMotion }
    private var directionsVisible: Bool { voiceOver || showDirectionControls }
    private var isFinal: Bool { store.levelIndex == store.levels.count - 1 }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 700
            let boardSide = min(geometry.size.width - 24, geometry.size.height * (compact ? 0.43 : 0.47))
            ZStack {
                AtmosphereBackground()
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: compact ? 4 : 8)
                    levelHeading(compact: compact)
                        .padding(.bottom, compact ? 0 : 8)
                    BoardSurface(scene: scene, paused: scenePhase == .background || showJourney || showSettings)
                        .frame(width: boardSide, height: boardSide)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Puzzle board")
                        .accessibilityValue(boardDescription)
                        .accessibilityIdentifier("puzzleBoard")
                        .accessibilityHint("Use the direction buttons or actions to move every loose tile.")
                        .accessibilityAction(named: "Slide up") { requestMove(.up) }
                        .accessibilityAction(named: "Slide right") { requestMove(.right) }
                        .accessibilityAction(named: "Slide down") { requestMove(.down) }
                        .accessibilityAction(named: "Slide left") { requestMove(.left) }
                    progressStrip.frame(height: compact ? 40 : 48)
                    if directionsVisible && !store.state.isSolved {
                        directionControls.padding(.vertical, 5)
                    } else {
                        Text(store.state.isSolved ? "Every pair, in its place." : (store.level.hint ?? "Take your time. Find your flow."))
                            .font(.system(size: compact ? 12 : 13, weight: .regular))
                            .foregroundStyle(PairShiftStyle.secondary(scheme))
                            .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                            .frame(height: compact ? 30 : 36)
                            .padding(.horizontal, 26)
                    }
                    Spacer(minLength: compact ? 4 : 8)
                    if store.state.isSolved {
                        completionControls
                    } else {
                        playControls(compact: compact)
                    }
                    if !compact {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle").font(.system(size: 9))
                            Text(store.state.isSolved ? "A LITTLE CLARITY, ONE PAIR AT A TIME" : "ONE SWIPE. EVERYTHING MOVES.")
                                .font(.system(size: 8, weight: .medium)).tracking(1.6)
                        }
                        .foregroundStyle(PairShiftStyle.secondary(scheme).opacity(0.8))
                        .frame(height: 30)
                        .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, compact ? 10 : 4)
            }
        }
        .foregroundStyle(PairShiftStyle.text(scheme))
        .sheet(isPresented: $showJourney) { JourneyView(store: store) }
        .sheet(isPresented: $showSettings) { SettingsView(store: store) }
        .onAppear {
            scene.scaleMode = .resizeFill
            scene.backgroundColor = .clear
            scene.onSwipe = { direction in requestMove(direction) }
            scene.onAnimationFinished = {
                isAnimating = false
                if let next = queuedDirection {
                    queuedDirection = nil
                    requestMove(next)
                }
            }
            synchronizeScene(animated: false)
        }
        .onChange(of: store.state) { _, _ in
            synchronizeScene(animated: animateNextState)
            animateNextState = false
        }
        .onChange(of: store.levelIndex) { _, _ in cancelPendingInput(); synchronizeScene(animated: false) }
        .onChange(of: scheme) { _, _ in cancelPendingInput(); synchronizeScene(animated: false) }
        .onChange(of: reducedMotion) { _, _ in cancelPendingInput(); synchronizeScene(animated: false) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { cancelPendingInput() }
            if phase == .active { synchronizeScene(animated: false) }
        }
        .onChange(of: showJourney) { _, value in cancelPendingInput(); if value { store.stopFeedback() } else { synchronizeScene(animated: false) } }
        .onChange(of: showSettings) { _, value in cancelPendingInput(); if value { store.stopFeedback() } else { synchronizeScene(animated: false) } }
        .overlay(alignment: .bottom) {
            if store.saveFailed {
                HStack {
                    Text("Progress couldn’t be saved.")
                    Button("Retry") { store.saveNow() }
                }
                    .font(.footnote).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding(16).accessibilityAddTraits(.updatesFrequently)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var header: some View {
        HStack {
            RoundIconButton(symbol: "square.grid.2x2", label: "Journey") { showJourney = true }
                .accessibilityIdentifier("journeyButton")
            Spacer()
            VStack(spacing: 5) {
                Text("PAIRSHIFT").font(.system(size: 17, weight: .light)).tracking(4.3)
                Text("FIND YOUR FLOW").font(.system(size: 7, weight: .medium)).tracking(2.6)
                    .foregroundStyle(PairShiftStyle.secondary(scheme))
            }
            .accessibilityElement(children: .combine)
            Spacer()
            RoundIconButton(symbol: "slider.horizontal.3", label: "Settings") { showSettings = true }
                .accessibilityIdentifier("settingsButton")
        }.frame(height: 46)
    }

    private func levelHeading(compact: Bool) -> some View {
        VStack(spacing: compact ? 4 : 7) {
            Eyebrow(text: "\(store.level.chapter)  /  \(String(format: "%02d", store.level.id))")
                .accessibilityIdentifier("levelIndicator")
            Text(store.state.isSolved ? (isFinal ? "Journey complete." : "Beautifully connected.") : store.level.title)
                .font(.system(size: compact ? 25 : 30, weight: .light, design: .serif))
                .tracking(-0.5)
                .lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityIdentifier("levelTitle")
        }.frame(height: compact ? 48 : 58)
    }

    private var progressStrip: some View {
        HStack(spacing: 24) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(String(format: "%02d", store.state.moveCount)).font(.system(size: 25, weight: .light, design: .rounded)).monospacedDigit()
                    .accessibilityIdentifier("moveCount")
                Text("MOVES").font(.system(size: 9, weight: .medium)).tracking(1.6).foregroundStyle(PairShiftStyle.secondary(scheme))
            }.accessibilityElement(children: .ignore).accessibilityLabel("Moves").accessibilityValue("\(store.state.moveCount)").accessibilityIdentifier("moveCounter")
            Rectangle().fill(PairShiftStyle.text(scheme).opacity(0.14)).frame(width: 1, height: 22)
            HStack(spacing: 9) {
                Image(systemName: "link").font(.system(size: 17, weight: .light)).foregroundStyle(PairShiftStyle.accent(scheme))
                Text("\(store.state.bondedPairCount) / \(store.state.totalPairCount)")
                    .font(.system(size: 15, weight: .regular, design: .rounded)).monospacedDigit()
                Text("PAIRS").font(.system(size: 9, weight: .medium)).tracking(1.6).foregroundStyle(PairShiftStyle.secondary(scheme))
            }.accessibilityElement(children: .ignore).accessibilityLabel("\(store.state.bondedPairCount) of \(store.state.totalPairCount) pairs bonded")
        }
    }

    private func playControls(compact: Bool) -> some View {
        HStack(spacing: 16) {
            Button { cancelPendingInput(); store.undo() } label: {
                HStack(spacing: 10) { Image(systemName: "arrow.uturn.backward").font(.system(size: 19, weight: .light)); Text("Undo").font(.system(size: 14, weight: .medium)) }
                    .frame(maxWidth: .infinity).frame(height: compact ? 50 : 58)
            }
            .disabled(!store.canUndo).opacity(store.canUndo ? 1 : 0.42).accessibilityIdentifier("undoButton")
            Button { cancelPendingInput(); store.restart() } label: {
                HStack(spacing: 10) { Image(systemName: "arrow.clockwise").font(.system(size: 19, weight: .light)); Text("Restart").font(.system(size: 14, weight: .medium)) }
                    .frame(maxWidth: .infinity).frame(height: compact ? 50 : 58)
            }.accessibilityIdentifier("restartButton")
        }.buttonStyle(GlassButtonStyle()).padding(.horizontal, 14)
    }

    private var completionControls: some View {
        VStack(spacing: 7) {
            Button {
                cancelPendingInput()
                if isFinal { showJourney = true } else { store.nextLevel() }
            } label: {
                HStack { Spacer(); Text(isFinal ? "Explore your Journey" : "Next puzzle"); Spacer(); Image(systemName: "arrow.right").padding(.trailing, 20) }
            }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("nextPuzzleButton")
            HStack(spacing: 24) {
                Button("Undo last move") { cancelPendingInput(); store.undo() }.accessibilityIdentifier("undoButton")
                Button("Play again") { cancelPendingInput(); store.restart() }.accessibilityIdentifier("replayButton")
            }
            .font(.system(size: 12)).foregroundStyle(PairShiftStyle.secondary(scheme)).frame(minHeight: 32)
        }.padding(.horizontal, 12)
    }

    private var directionControls: some View {
        HStack(spacing: 12) {
            directionButton(.left, "arrow.left", "Slide left")
            directionButton(.up, "arrow.up", "Slide up")
            directionButton(.down, "arrow.down", "Slide down")
            directionButton(.right, "arrow.right", "Slide right")
        }
    }

    private func directionButton(_ direction: MoveDirection, _ image: String, _ label: String) -> some View {
        Button { requestMove(direction) } label: { Image(systemName: image).font(.system(size: 16)).frame(width: 48, height: 44) }
            .buttonStyle(GlassButtonStyle()).accessibilityLabel(label).accessibilityIdentifier("direction_\(direction.rawValue)")
    }

    private func requestMove(_ direction: MoveDirection) {
        guard !store.state.isSolved, !showJourney, !showSettings, scenePhase != .background else { return }
        if isAnimating { queuedDirection = direction; return }
        animateNextState = true
        if let result = store.move(direction), result.didChange { isAnimating = true }
        else { animateNextState = false }
    }

    private func synchronizeScene(animated: Bool) {
        scene.display(store.state, animated: animated, reduceMotion: reducedMotion, lightMode: scheme == .light)
    }

    private func cancelPendingInput() {
        queuedDirection = nil
        isAnimating = false
        animateNextState = false
    }

    private var boardDescription: String {
        let names = ["blue circle", "coral star", "gold triangle", "jade diamond", "violet crescent", "cyan wave"]
        let tiles = store.state.tiles.sorted { $0.id < $1.id }.map { tile in
            "\(names[tile.pairID % names.count]), row \(tile.position.row + 1), column \(tile.position.column + 1)\(tile.isBonded ? ", bonded" : "")"
        }
        let walls = store.state.walls.map { "wall, row \($0.row + 1), column \($0.column + 1)" }
        return "\(store.state.size) by \(store.state.size) grid. " + (tiles + walls).joined(separator: ". ")
    }
}
