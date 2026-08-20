# Roadmap

## M0.5 — Audited world-tour slice (current)
- 3 verified worlds: Paris, Cairo, Tokyo
- deterministic tap-vs-orbit input
- one-cell moves, undo, restart, auto-solve
- runtime level validation + BFS
- landmark obstacles and world progression
- static scene/resource contracts + headless CI definition

## M1 — Device-ready mobile feel
- obtain green Godot headless CI on the remote repository
- Android export pipeline and physical-device smoke test
- safe-area/UI pass for portrait and landscape
- touch-target debug overlay and optional input telemetry
- pooled/asset-based audio and FX instead of procedural placeholders
- stronger combo/parking feedback without obscuring puzzle readability

## M2 — Signature mechanic
- cube-face topology in pure board model
- solver supports face transitions
- cars wrap across cube edges
- orbit snap to active face
- tests for orientation transforms at every cube edge

## M3 — Content pipeline
- level generator + difficulty metrics
- duplicate/isomorphism detection
- 30-level starter campaign
- themed GLB asset swap without board-code changes
