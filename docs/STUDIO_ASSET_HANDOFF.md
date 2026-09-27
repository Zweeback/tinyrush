# Shared studio → Parking Panic handoff

Parking Panic now accepts optional production landmark GLBs from the shared 3D/film studio while preserving the existing procedural fallback.

## Export side

The studio should publish a game/mobile GLB with:

- baked transforms;
- Y-up glTF convention;
- deterministic scale;
- bounded polygon count;
- PBR textures;
- provenance retained in the studio manifest.

## Game side

Copy the selected GLB under `assets/studio/<world>/` and add these optional level properties:

- `landmark_scene`: Godot resource path to the GLB.
- `landmark_scale`: uniform scale, default `1.0`.
- `landmark_yaw_degrees`: Y rotation, default `0`.
- `landmark_offset`: local XYZ offset from the logical landmark center.

The board model, solver, collision occupancy and `landmark_cells` remain authoritative. A visual landmark cannot change puzzle legality.

If the external scene fails to load, runtime emits a warning and renders the existing procedural Eiffel Tower / pyramid / Tokyo Tower instead.
