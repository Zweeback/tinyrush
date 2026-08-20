# Changelog

## 0.5.0-alpha
- Reworked pointer input so taps trigger on release and drags can begin even on top of cars.
- Split endcap and body pickers onto deterministic collision layers to remove overlap ambiguity.
- Added visible selection marker and safer non-overshooting move tween.
- Added `ParkingPanicLevelValidator` for runtime bounds, overlap, target and exit validation.
- Reworked BFS to reconstruct paths from parent maps instead of copying full paths per queued state.
- Added `legal_steps()` and occupancy-map helpers to `ParkingBoard`.
- Runtime now rejects stale `optimal_moves` metadata when it disagrees with the solver.
- Python validator now replays every declared `optimal_path` in addition to proving optimality with BFS.
- Added scene/script contract audit and aggregate `tools/run_checks.py` preflight.
- Added Godot validator and board-rules tests to CI.
- Locked move/undo transitions against overlapping UI actions.
- Made world island sizing and exit-gate rendering board/axis aware.
- Separated `landmark_cells` from generic static blockers so Tokyo and future worlds keep visual landmarks aligned with grid truth; non-landmark blockers now render explicitly.
- Updated responsive top/progress UI anchors and project metadata.

## 0.4.0-alpha
- Added real level catalog and 3-world progression.
- Added Cairo/Pyramid and Tokyo/Tower landmark puzzles.
- Runtime solver verifies each loaded puzzle instead of trusting hard-coded claims.
- Added next-world flow and progress UI.
- Replaced Paris-only world renderer with theme-driven world builder.
- Added dependency-free Python BFS validator and `res://` audit.
- Added GitHub Actions headless Godot CI.
