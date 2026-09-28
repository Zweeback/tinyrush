## Scope
- What puzzle/data/presentation behavior changes?

## Required validation
- [ ] `python tools/run_checks.py`
- [ ] Godot parser/import gate passes
- [ ] Solver tests pass
- [ ] Level-validator and board-rule tests pass
- [ ] GL Compatibility main-scene smoke test passes when runtime changes

## Determinism
- [ ] Existing optimal paths remain valid or are explicitly versioned
- [ ] Old level data remains backward-compatible
- [ ] Solver semantics were not changed silently

## Delivery safety
- [ ] No auto-merge, deployment, secret, permission, or billing change

## Evidence
Include exact validation commands, CI run references, and any changed optimal-state counts.
