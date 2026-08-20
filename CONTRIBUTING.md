# Contributing

Keep changes in one primary lane per commit when practical: gameplay, puzzle/tools, 3D/juice, or QA/release.

Before opening a PR:

```bash
python tools/run_checks.py
```

When Godot 4.3 is available, also run the scripts under `tests/` headlessly. Do not change a level's `optimal_moves` by hand without updating a legal `optimal_path`; the validator proves both.

Prototype visuals may remain procedural, but puzzle behavior belongs in the model layer and must be testable without rendering.
