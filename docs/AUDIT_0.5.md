# Parking Panic 0.5 / 0.5.1 Audit

Date: 2026-08-20

## Scope

Audit of the Godot project, puzzle data, input flow, model/solver boundary, scene contracts, world builder and CI. The first pass was static because the local container had no Godot binary. The repository now runs the official Godot 4.3 editor in GitHub Actions, including import, native GDScript tests and a GL Compatibility main-scene smoke test under Xvfb.

## Fixed in 0.5

| Severity | Finding | Resolution |
|---|---|---|
| High | Tap actions fired on pointer-down, so trying to orbit from a car could accidentally move/select it. | Tap is now committed on release; crossing a drag threshold cancels the pending tap and begins orbit. |
| High | Large body picker and move endcaps overlapped in one collision layer, leaving the first ray hit ambiguous. | Endcaps and body selector now use separate collision layers; endcaps are queried first. |
| High | `optimal_moves` was checked by BFS, but the checked-in `optimal_path` itself could silently become stale or illegal. | Python and Godot test paths now replay declared optimal paths and require final exit at the declared optimal length. |
| High | Runtime level validation did not fully validate axis, target flags, exit alignment, duplicate/static cells or malformed lengths. | Added `ParkingPanicLevelValidator` and expanded dependency-free validation. |
| Medium | BFS copied the full move path into every queued state, causing unnecessary memory growth as puzzles scale. | Solver now stores parent/move maps and reconstructs only the winning path. |
| Medium | Undo and normal move animations could overlap with further UI actions. | Move/undo transitions now hold the busy gate until their animation window completes. |
| Medium | World exit gate rendering assumed an X-axis exit. | Exit gate now supports either valid board axis. |
| Medium | World island and dressing dimensions were hard-coded around a 6x6 board. | Dimensions now derive from board bounds and cell size. |
| Medium | Tokyo's disjoint static cells caused the landmark to be placed at the average of unrelated blockers, visually occupying logical road cells. | Added explicit `landmark_cells`; landmark placement is separated from all static blockers. |
| Medium | Scene `$Node/Path` contracts could break without a Godot run and go unnoticed by the Python preflight. | Added static scene/script contract audit. |
| Low | Selection feedback was only scale-based. | Added an emissive selection marker and simplified deterministic picker behavior. |

## Native-CI findings fixed in 0.5.1

The first real Godot 4.3 run exposed several GDScript `Variant` inference warnings that were treated as parser errors. They were present in the input controller, board logic, FX math, procedural car view and world builder. These were invisible to the dependency-free Python checks. All affected boundaries now use explicit types/casts where Godot 4.3 cannot infer a stable type.

The first headless main-scene smoke also produced repeated dummy-renderer `mesh_get_surface_count` errors. These were not game-script failures; they were caused by instantiating procedural 3D meshes against Godot's headless dummy rendering backend. The CI smoke was therefore redesigned instead of suppressing the messages: parser/solver tests remain headless, while the actual main scene boots with the GL Compatibility renderer under Xvfb.

## Verified

The dependency-free preflight passes and proves:

- every indexed level exists and is structurally valid;
- every declared `optimal_path` replays legally and exits on its final step;
- all scanned `res://` references resolve;
- scene-attached script `$Node/Path` references resolve;
- no duplicate `class_name` declarations are present.

The official Godot 4.3 CI additionally passes:

- project import with parser/compiler-error rejection;
- Paris solver baseline: 9 optimal moves, 683 visited states, peak queue 144;
- Cairo: 12 optimal moves, 270 visited states, peak queue 61;
- Tokyo: 12 optimal moves, 1171 visited states, peak queue 180;
- runtime level-validator tests;
- board-rule replay tests;
- main-scene boot using the GL Compatibility renderer under Xvfb.

## Remaining release blockers

1. **Physical input test:** verify single-touch, pinch, orbit-from-car, fallback movement buttons and haptics on at least one Android device.
2. **Android export test:** create, install and boot an APK. The current checked-in export preset is Web only.
3. **Procedural presentation debt:** car meshes, city meshes, audio tones and burst particles remain prototype assets. Their architecture is replaceable, but they are not production assets.
4. **Scale behavior:** runtime BFS is appropriate for the current tiny catalog but should move toward build-time verification/baked metadata before a large campaign.
5. **Signature mechanic:** multi-face/cube topology is still intentionally unimplemented. It should enter the board model and solver before any visual edge-wrapping code.

## Release recommendation

`0.5.1-alpha` is the first alpha in this project that is both source-audited and actually imported, solved, tested and graphically booted by Godot 4.3 in CI. Merge it as the stable development baseline, then complete the Android physical-device gate before starting the cube-face topology milestone.
