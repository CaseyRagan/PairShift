# PairShift

Native portrait iPhone puzzle game. Product intent is in `Docs/PRODUCT.md`; current work and verification are in `Docs/BUILD.md`.

## Development
- SwiftUI owns app navigation and accessible controls. SpriteKit owns the board presentation. PairShiftCore owns deterministic rules and solver verification.
- Never couple animation timing, sound, storage, network access, or random values to puzzle state.
- Core moves slide all loose tiles fully, then resolve orthogonal matching pairs. Bonds occupy both cells permanently. No-op inputs do not count.
- Use existing palette and symbol identities consistently. Every pair has exactly two tiles.
- Keep the first milestone to 20 authored Journey puzzles, local settings/progress/resume, exact undo/restart, feedback, and accessibility.
- Solver verification must pass for every shipped level. No PAR claims without an exhaustive shortest-path result. Solver work is never on the UI path.
- Run `swift test`, `swift run pairshift-verify`, then build/test the iOS project after relevant changes. Regenerate the Xcode project with `python3 Scripts/generate_project.py` when adding Swift files.
- Preserve the image-generation prompt and provenance for project art in `Docs/ART.md`.
- Make no claim of physical-device performance until measured on a device. Simulator evidence must be labeled.
- Keep handoff documentation current so another model can continue without recreating decisions.
