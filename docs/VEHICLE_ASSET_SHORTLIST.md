# Vehicle asset shortlist

Goal: replace the procedural placeholder bodies with toy-like, readable vehicle meshes while keeping the puzzle grid and movement logic deterministic.

## Primary candidates

### Kenney — Toy Car Kit
- https://kenney.nl/assets/toy-car-kit
- 100 files
- CC0
- Best stylistic fit for TinyRush: chunky toy proportions, simple materials, readable at small scale.

### Kenney — Car Kit
- https://kenney.nl/assets/car-kit
- 45 files
- CC0
- Useful for more conventional car silhouettes and additional variation.

### RGS_Dev — Free Low Poly Vehicles Pack
- https://rgsdev.itch.io/free-low-poly-vehicles-pack
- CC0
- Includes sedan, hatchback, SUV, van, truck, bus, taxi and more.
- Wheels are separated and colors are material-driven, which is useful for recoloring puzzle pieces.

### Quaternius — Cars Pack
- https://quaternius.com/packs/cars.html
- 8 models
- FBX / OBJ / Blend
- Pack page currently marks the pack CC0.

## TinyRush three-archetype mapping

1. **hero** — the special red 2-cell target car
2. **car** — normal 2-cell blockers
3. **truck** — long 3-cell blockers

This is the actual Rush Hour gameplay taxonomy. A van/SUV may later be a visual skin for a normal 2-cell car, but it is not a separate rules class.

The model layer owns the archetype metadata. Imported meshes should only replace presentation; they must not define legal movement.
