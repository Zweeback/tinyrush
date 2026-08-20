# Architecture

## Boundaries

`data/levels/*.json` is the source of truth for puzzle content. The runtime boundary is deliberately one-way:

`JSON -> validator -> board/model -> solver/controller -> view/FX`

- `ParkingCarState` holds per-car deterministic state.
- `ParkingBoard` owns occupancy, legal one-cell moves, exits and state keys.
- `ParkingPanicLevelValidator` rejects malformed content before a board is configured.
- `ParkingPanicSolver` performs BFS using board legal steps and parent-map reconstruction.
- `ParkingPanicInputController` owns tap/drag/pinch arbitration and ray queries.
- `ParkingPanicCarView` owns meshes, picker volumes and animation only.
- `ParkingPanicWorld` builds themed dioramas from level metadata.
- `ParkingPanicAudio` and `ParkingPanicFX` are presentation services.
- `main.gd` coordinates level lifecycle, history, progression and UI.

## Invariants

- A car axis is exactly `[1,0]` or `[0,1]`.
- Exactly one car is the target and it matches `exit.target`.
- Initial cars do not overlap each other, static cells or board bounds.
- Target axis and lane match the exit.
- One player action moves one grid cell; the final exit action also counts as one move.
- Every checked-in level has a replayable declared optimal path and a BFS-proven optimal move count.

## Next topology milestone

Multi-face/cube routing must enter the model layer first. A future board state must include face/orientation topology, and the solver must prove cross-face transitions before visuals animate cars around edges. Do not implement cube wrapping only in `CarView`.
