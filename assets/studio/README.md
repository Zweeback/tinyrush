# Studio landmark assets

Production landmarks exported by the shared 3D/film studio can be copied here as GLB files and referenced from a level without changing puzzle rules.

Example level fields:

```json
{
  "landmark": "eiffel",
  "landmark_scene": "res://assets/studio/paris/eiffel.glb",
  "landmark_scale": 0.42,
  "landmark_yaw_degrees": 90.0,
  "landmark_offset": [0.0, 0.0, 0.0]
}
```

Runtime behavior:

1. If `landmark_scene` exists and imports as a `PackedScene`, it is instantiated at the logical landmark center.
2. Scale, yaw and local offset are applied from level metadata.
3. If the external asset is missing or invalid, the existing procedural landmark is used automatically.

This keeps gameplay truth and visual assets separate. Large generated GLBs should enter through the project asset workflow rather than being treated as level data.
