# Release checklist

Before merging a playable Parking Panic release candidate:

- [ ] `python tools/run_checks.py` passes.
- [ ] Godot headless import passes.
- [ ] Main scene boots headlessly without parser/runtime errors.
- [ ] All Godot puzzle tests pass.
- [ ] At least one Android-device touch smoke test is completed.
- [ ] New/changed levels have a replayable optimal path and solver-verified optimal move count.
- [ ] Puzzle rules remain in the model layer; presentation code does not invent legal moves.
- [ ] Release notes identify known prototype assets and remaining blockers.
