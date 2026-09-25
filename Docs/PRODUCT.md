# PairShift — first playable milestone

One swipe moves everything. Make every pair stick.

## Approved direction

The user approved a native iPhone-first app developed in this repository, using SwiftUI for app UI and SpriteKit for the board. Physical playtests will use an iPhone 15. The visual reference is the supplied PairShift concept image: luminous acrylic tiles, inset symbols, restrained bonded bridges, glass/slate board, and atmospheric mountain scenery. The image is art direction, not an additional feature request.

First milestone: 20 curated Journey puzzles, deterministic engine, independent solvability verifier, exact undo/restart, local progress and full resume history, tactile sound/haptics, appearance and reduced-motion settings, polished completion and next-level flow. The user explicitly approved moving basic solver verification into this milestone.

Daily, Expert, Stats, theme store, accounts, payments, ads, backend, procedural generation, cloud sync and publishing are later milestones.

## Rules

- Small square grid: 4×4 then 5×5. Each symbol/color appears exactly twice.
- A swipe moves every loose tile as far as possible, with no overlap, through available cells in that direction.
- Movement resolves fully before bonding. Only matching tiles orthogonally adjacent at the end bond.
- Bonded tiles remain in both occupied cells and are immovable obstacles.
- Multiple pairs can bond after one move. Solve by bonding all pairs.
- No-op inputs do not increment moves. All meaningful moves, including bonding, have exact undo snapshots.
- Authored starts avoid adjacent unbonded pairs. Walls appear later.
- No random gameplay and no network dependency.

## Experience

Launch directly into a playable board or exact resumed state. All controls are reachable and touch-friendly. No mandatory completion delay. Undo stays available after completion. No color-only identification. Honor system Reduce Motion, readable dynamic text, VoiceOver labels and alternative direction buttons. Build light and dark appearance.

Visual quality means crisp original materials, restrained lighting, readable state, coordinated motion/audio/haptics and consistent frame pacing. Target 60 fps on the iPhone 15. Device claims require measurement; the simulator cannot certify battery, thermals, haptics or physical touch latency.

## Playtest gate

Test without verbally explaining the rules. Observe whether players understand the aim after three puzzles, notice that bonds become obstacles, use undo naturally, and voluntarily continue. Revise the first 20 before expanding content.

