# Puzzle catalog and verification

PairShift ships 20 manually authored Journey boards. Every starting board has an exhaustively verified shortest solution, and every reported solution has been replayed through the public game engine. No random level generation runs during authoring or gameplay.

The source of truth is `Sources/PairShiftCore/LevelCatalog.swift`. The checked-in `Sources/PairShiftVerifier/verification-report.json` contains one shortest direction sequence per level, the number of states visited, and a successful replay flag. The optimal counts below are development evidence; this milestone does not present a player-facing PAR system.

## Catalog

| Level | Title | Grid | Pairs | Stone cells | Optimal moves |
| ---: | --- | :---: | ---: | ---: | ---: |
| 1 | First light | 4 × 4 | 2 | 0 | 1 |
| 2 | In step | 4 × 4 | 2 | 0 | 2 |
| 3 | A small turn | 4 × 4 | 3 | 0 | 3 |
| 4 | Together | 4 × 4 | 3 | 0 | 3 |
| 5 | Close quarters | 4 × 4 | 3 | 0 | 4 |
| 6 | Finding flow | 4 × 4 | 4 | 0 | 5 |
| 7 | The shape of it | 4 × 4 | 4 | 0 | 6 |
| 8 | A little patience | 4 × 4 | 3 | 0 | 4 |
| 9 | The long way | 4 × 4 | 4 | 0 | 6 |
| 10 | Room to breathe | 4 × 4 | 4 | 0 | 7 |
| 11 | Between moments | 5 × 5 | 5 | 0 | 7 |
| 12 | Hold that thought | 5 × 5 | 5 | 0 | 7 |
| 13 | Still stones | 5 × 5 | 3 | 1 | 3 |
| 14 | A quiet corner | 5 × 5 | 4 | 2 | 4 |
| 15 | Narrow passage | 5 × 5 | 4 | 2 | 5 |
| 16 | Around the bend | 5 × 5 | 5 | 2 | 10 |
| 17 | Ripple effect | 5 × 5 | 6 | 0 | 11 |
| 18 | A different route | 5 × 5 | 6 | 1 | 9 |
| 19 | Almost home | 5 × 5 | 6 | 1 | 11 |
| 20 | In harmony | 5 × 5 | 6 | 2 | 15 |

Journey chapters contain five levels each: First light, Finding flow, Still stones, and In harmony.

## Manual curation

Boards are literal row strings: `.` is an empty cell, `#` is a stone, and letters A–F identify pairs. The letter identities are blue circle, coral star, gold triangle, jade diamond, violet crescent, and cyan wave. Each letter occurs exactly twice. All authored pairs begin loose and nonadjacent; the board never opens with an unexplained existing connection.

The first five levels introduce the shared movement and permanent bonds in one to four optimal moves. All four opening directions remain solvable on these five boards. This forgiveness applies to the opening; subsequent choices can still create a dead end.

Levels 5–7 use completed pairs as geometry for the remaining pieces. Level 8 deliberately reduces the pair count to isolate a new idea: a right swipe immediately connects the triangles but makes the remaining puzzle unsolvable. A left swipe delays that connection and preserves the route. Levels 9–12 develop decisions about when and where to connect pairs. The board grows to 5 × 5 at level 11.

Stones arrive at level 13 with fewer pairs and a short solution. Levels 14–16 expand the use of fixed obstacles, followed by six-pair planning boards in levels 17–20. Counts intentionally include easier moments; optimal path length alone does not measure human difficulty.

Candidate boards were edited by hand and examined with the verifier's opening and path branch reports. These reports informed revisions to early difficulty, initial pair placement, and misleading easy connections. The curation tools do not generate candidate boards.

## What verification proves

`GameEngine.applyMove` fully compresses loose tiles in the chosen direction, processing the leading cells first. Stones and existing bonds block travel. After all movement resolves, matching orthogonally adjacent pieces bond simultaneously. A bond occupies its two cells permanently. A no-op does not increment the move count or add an undo snapshot.

`PuzzleVerifier.solve` performs breadth-first search with every valid changed move costing one. It removes duplicate states using a canonical key that includes board dimensions, stones, pair positions, and bond status. Tile ordering, tile identities within a pair, and move count do not change the search state. The first found solution is therefore shortest: all smaller depths have been considered before it.

The CLI replays the returned directions through the public engine and checks both completion and move count. Its default search limit is 250,000 distinct states. A limit result is explicitly `searchLimitReached`, not a claim of unsolvability or optimality. `unsolvable` means the reachable state space was exhausted without a solution. All 20 catalog boards return `solved`; the largest search in this catalog visits 31,073 states.

Solvable means **a solution exists from the published starting board**. It does not mean that every player move preserves a solution. Creating a dead end through a premature bond is part of the puzzle. Unlimited exact Undo and Restart are the recovery tools. There is no automatic dead-end detector or solver-derived hint in the gameplay flow.

The solver shares the production transition engine. To reduce the risk of the verifier merely agreeing with a movement bug, the test suite also compares thousands of transitions with an independently written model that advances pieces one cell at a time until they stop, then checks bonds.

## Commands

Run from the repository root:

```sh
swift test -c release
swift run -c release pairshift-verify
swift run -c release pairshift-verify --json
```

After an intentional catalog change, regenerate the report and inspect its diff:

```sh
swift run -c release pairshift-verify --json > Sources/PairShiftVerifier/verification-report.json
```

Inspect a manually authored candidate without changing the shipped catalog:

```sh
swift run -c release pairshift-verify 'A.../.B.C/C.../.A.B' --inspect
swift run -c release pairshift-verify 'A.../.B.C/C.../.A.B' --trace
```

`--inspect` reports the bonds and remaining solvability after each opening direction. `--trace` inspects all branches along one shortest solution; it is an authoring diagnostic that reveals solutions. The verifier exits zero only when every selected board is solved and successfully replayed. It exits one on verification failure and two for malformed board notation.

Keep level IDs stable. An altered initial board is a new puzzle definition even if its ID is reused; the app validates saved sessions against the current initial state before restoring them.

## Engine test coverage

The core package currently has 15 passing tests across `GameEngineTests` and `LevelCatalogTests`. They cover:

- Leading-edge compression and order preservation; board edges, stones, and bonded pieces blocking movement.
- Orthogonal bonding after movement, multiple simultaneous bonds, and diagonals remaining separate.
- Stable bonded positions, legal final occupancy, deterministic results, and independence from tile array ordering.
- No-op moves consuming neither move count nor undo history.
- Exact undo before and after bonding, exact restart, and Codable session restoration with undo history.
- Structural rejection of invalid states and canonical keys that ignore identity/order/move-count differences.
- Distinct solver results for invalid input, exhausted search budgets, unsolvability, and verified shortest solutions.
- All 20 valid, distinct initial boards, each shortest solution replayed and completely undone.
- Recovery from every opening direction in the first five puzzles and the deliberate patience lesson in level 8.
- Thousands of transitions compared with the separate cell-step movement model.

These tests cover the engine and content. They do not establish gesture reliability, rendering quality, audio/haptic quality, app lifecycle persistence, or usability on a physical iPhone; those need app tests and device play.

One release-mode run of the already-built verifier completed the full catalog in approximately 0.25 seconds on the local development Mac. The 15 core tests completed in approximately 0.44 seconds after compilation. These are local CPU observations, not repeatable benchmark guarantees, GPU frame-time measurements, or iPhone 15 performance claims. The app never runs the solver during a move.

## Human playtest questions

Ask first-time players to begin without a verbal rules explanation. Observe whether they understand that every loose piece moves, recognize that connected pieces remain fixed, and discover Undo when a choice stops working. The intended first-session signal is that at least 80% can explain the objective after three puzzles, with many voluntarily continuing. That target has not yet been measured.

Watch level 8 for productive discovery versus unexplained frustration. Levels 9–12 revisit related arrangements to teach placement and timing; players may experience those as useful variations or as repetition. The change from five optimal moves at level 15 to ten at level 16 is the largest mid-campaign increase and deserves close observation. The final 15-move board may need a softer lead-in based on real play.

Record solve attempts, Undo/Restart use, hesitations, mistaken swipes, and voluntary continuation during supervised playtests. Check symbol recognition and board readability in light mode, dark mode, Reduce Motion, and with accessibility controls. Solver results establish correctness and shortest paths; they do not establish that this difficulty sequence feels fair, intuitive, or compelling.
