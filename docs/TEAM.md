# Developer Team Lanes

- **Gameplay / Systems:** board rules, input, progression, lifecycle and win state.
- **Puzzle / Tools:** level schema, BFS verification, generator work and difficulty metrics.
- **3D / Juice:** tiny-car view, landmarks, camera, particles, lighting, audio/haptics.
- **QA / Release:** static audits, Godot headless tests, exports and device smoke tests.

## Merge gates

A change is not merge-ready unless:

1. `python tools/run_checks.py` passes.
2. Godot headless import succeeds in CI.
3. all Godot tests pass.
4. new/edited levels have a declared path that replays and matches BFS optimality.
5. presentation changes do not introduce puzzle rules outside the model layer.

For the future cube mechanic, the model/solver tests land before cross-face animation.
