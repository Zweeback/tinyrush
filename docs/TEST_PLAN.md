# Test plan

## Fast preflight

Run `python tools/run_checks.py` for structural validation, level BFS verification, declared-path replay, `res://` reference auditing, scene node-path contracts and duplicate `class_name` checks.

## Godot headless

Run the import, short boot smoke and the test scripts under `tests/` using Godot 4.3.

## Device smoke

On Android verify: single tap selection, endcap movement, drag-to-orbit from empty space and from on top of a car, pinch zoom, undo, restart, auto-solve, world progression, vibration and blocked-move feedback.

## Exit criteria

No parser/runtime errors, all automated checks green, no accidental movement while starting an orbit gesture, and every world can be completed manually and through auto-solve.
