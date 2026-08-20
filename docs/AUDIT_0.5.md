# Parking Panic 0.5 Audit

Date: 2026-08-20

## Scope

Static/source audit of the Godot project, puzzle data, input flow, model/solver boundary, scene contracts, world builder and CI definition. The local execution environment used for this audit does not contain a Godot binary, so native parser/render/device execution remains an external gate.

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
| Low | Selection feedback was only scale-based and picker visibility code did not create a visible endcap cue. | Added an emissive selection marker and simplified deterministic picker behavior. |
| Low | Project metadata/UI hints still described the older Paris-only/empty-space-drag behavior. | Updated version metadata, hints and responsive top/progress anchors. |

## Verified locally

`python tools/run_checks.py` passes and currently proves:

- every indexed level exists and is structurally valid;
- Paris optimal = 9 cell moves, 683 BFS states;
- Cairo optimal = 12 cell moves, 270 BFS states;
- Tokyo optimal = 12 cell moves, 1171 BFS states;
- every declared `optimal_path` replays legally and exits on its final step;
- all scanned `res://` references resolve;
- scene-attached script `$Node/Path` references resolve for both scenes;
- no duplicate `class_name` declarations are present.

## Remaining release blockers

1. **Native Godot smoke test:** import/parse/run the project with Godot 4.3 and inspect runtime errors.
2. **Physical input test:** verify mouse, single-touch, pinch and orbit behavior on at least one Android device.
3. **Export test:** create and install an Android build; current repository only has a Web export preset.
4. **Procedural presentation debt:** car meshes, city meshes, audio tones and burst particles remain prototype assets. Their boundaries are now replaceable, but they are not production assets.
5. **Scale behavior:** runtime BFS is fine for current small levels, but should move to build-time verification/baked metadata before a large campaign.
6. **Signature mechanic not implemented:** multi-face/cube topology is still a roadmap item and must be solved in the model/solver before visual edge wrapping.

## Release recommendation

Treat `0.5.0-alpha` as the first audited test candidate. Do not add cube-face driving or large content batches until native Godot CI and one physical-device smoke test are green.
