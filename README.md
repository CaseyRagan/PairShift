# PairShift

**One swipe moves everything. Make every pair stick.**

A native iPhone puzzle game with luminous acrylic tiles, a quiet alpine backdrop, and twenty deterministic puzzles. Every match becomes part of the board. Every puzzle has a verified solution.

## Run the iPhone app

1. Open `PairShift.xcodeproj` in Xcode.
2. Choose the **PairShift** scheme and an iPhone simulator.
3. Run. The app opens directly into the first puzzle and resumes exact progress on subsequent launches.

For a physical iPhone, select your signing team under **PairShift → Signing & Capabilities**, connect the phone, select it as the destination, and follow Xcode's device setup prompts. The repository deliberately contains no personal signing identity.

Requires Xcode with Swift 6 and an iOS 17 or newer SDK/runtime. Developed with Xcode 26.1.1. No external packages, server, API keys, or downloaded dependencies are required.

## Play

Swipe anywhere on the board. All loose tiles slide to their furthest valid positions. Matching symbols that finish next to one another bond permanently. Connect every pair to complete the puzzle. Undo and restart are unlimited. Settings include independent sound/haptics, light/dark/system appearance, reduced motion, and optional direction buttons. VoiceOver also exposes each tile's position and direction actions.

The Journey button reopens completed puzzles and the next unlocked puzzle. Closing the app preserves the board, move count, and undo history.

## Verify

```sh
swift test -c release
swift run -c release pairshift-verify
swift run -c release pairshift-verify --json
python3 Scripts/generate_project.py
xcodebuild -project PairShift.xcodeproj -scheme PairShift \
  -destination 'platform=iOS Simulator,name=PairShift iPhone 15' \
  -derivedDataPath DerivedData test CODE_SIGNING_ALLOWED=NO
```

Use an available simulator name if `PairShift iPhone 15` is not installed. The project generator uses only Python's standard library; it keeps source references and UI test solution paths synchronized. The Xcode project and shared scheme are checked in, so generation is needed only after adding/removing source files or changing verified paths.

## Project structure

- `Sources/PairShiftCore` — deterministic rules, value state, exact undo, hand-authored levels and exhaustive BFS verifier.
- `App/Rendering` — cached original tile materials and snapshot-based SpriteKit board.
- `App/Views` — native SwiftUI game, Journey and settings.
- `App/Model`, `App/Services` — progress, validated atomic persistence, original synthesized audio and Core Haptics.
- `Tests`, `AppTests`, `UITests` — engine, save/lifecycle and real gesture-flow checks.
- `Docs` — approved scope, verification evidence, art provenance and next playtest.

`Docs/BUILD.md` records actual validation and limits. Physical iPhone testing is the next acceptance step for touch feel, haptics, sound balance, frame pacing and energy use.

This milestone includes the complete twenty-puzzle Journey. Daily, Expert, accounts, store, analytics, cloud services and App Store submission are future work.
# PairShift
