# Build plan and evidence

## Milestone status

1. Establish the native project and local Git history. **Complete**
2. Implement the engine, verify 20 curated levels and exact state history. **Complete**
3. Build original board materials, motion, app UI, persistence and feedback. **Complete**
4. Run unit and UI checks; inspect simulator screenshots in dark, light and reduced-motion modes. **Complete**
5. Document verified behavior, physical-device setup and remaining limitations; commit the playable app. **In progress**

## Environment

Xcode 26.1.1, Swift 6.2.1, macOS arm64, iOS 26.1 simulator runtime. The UI suite ran on the iPhone 15 simulator. The intended physical-device target is the user's iPhone 15; it was not available to `devicectl` during this run.

## Decisions

- SwiftUI + SpriteKit and a local Swift package, with no third-party dependencies.
- Play offline after installation. No remote server or account is required.
- A local Git repository is set up. No remote hosting was requested or configured.
- Original generated alpine atmosphere and app icon are committed. Tile art is rendered and cached in code.

## Verification

- `swift test -c release`: **15 tests passed**, including an independent cell-step comparison across thousands of deterministic transitions and checks for undo/restart and all authored boards.
- `swift run -c release pairshift-verify`: **all 20 puzzles verified** by shortest-path search. Optimal solutions range from 1 to 15 moves; the largest search visited 31,073 states.
- `xcodebuild -project PairShift.xcodeproj -scheme PairShift -destination 'platform=iOS Simulator,id=98D1B876-A5D9-468F-8365-511C4BF37FD6' -derivedDataPath DerivedData test CODE_SIGNING_ALLOWED=NO`: **10 tests passed, 0 failures** on the iPhone 15 simulator (8 persistence/lifecycle tests and 2 UI tests). The UI tests played through all 20 levels using actual swipe gestures, and checked undo, restart, exact resume, Journey, light appearance and reduced-motion completion.
- `xcodebuild ... build CODE_SIGNING_ALLOWED=NO`: **succeeded**.
- Reviewed captured simulator screens for the opening board, a completed bond, Journey completion, Journey selection, light-mode settings and reduced-motion completion. Captures and the `.xcresult` bundle are local under ignored `Artifacts/Visual-QA/` and `Artifacts/` folders; they are not part of the source commit.

The simulator results establish app behavior in that environment. They do not measure real-device frame pacing, energy use, touch feel, or physical haptic strength. Those checks require installing on the physical iPhone 15. To install from Xcode, select a signing team under **PairShift → Signing & Capabilities**, connect and select the phone, then follow Xcode's device setup prompts.

## Next acceptance step

Have someone who has not seen the rules play the opening puzzles without coaching. Observe whether the first swipe and permanent bonding rule are clear; then tune onboarding and difficulty from that evidence. Physical-device touch, haptics, sound balance and performance checks should happen in the same session.
