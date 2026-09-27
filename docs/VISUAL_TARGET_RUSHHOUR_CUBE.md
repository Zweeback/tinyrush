# TinyRush visual target — Rush Hour traffic cube

The target look is a **large physical puzzle cube** covered in road grids and colorful toy vehicles.

## Non-negotiable visual read

- dark charcoal cube body with slightly raised frame/corners
- road grid on the top and visible side faces
- white lane/grid markings with a few emissive route cues
- chunky glossy toy cars in saturated blue, green, orange, purple, pink and red
- target car gets a warm gold parking-pad glow
- camera shows the top plus two side faces at once
- bright cyan/blue sky and a miniature city/park ring around the cube base
- soft, readable lighting rather than realistic materials

## Implementation in `feature/rushhour-cube-visuals`

- top gameplay remains the existing deterministic 2D board model
- the world renderer now builds the puzzle as a deep cube instead of a flat island
- visible cube side faces carry road grids and decorative traffic so the silhouette already matches the intended game identity
- playable cars use a more detailed toy-car body, cabin glass, bumpers, wheels, hubs and emissive lights
- branding is `TinyRush`

## Next mechanical milestone

The decorative side-face traffic is **not** a substitute for the real cube mechanic. Cross-face movement must be implemented in the board/topology model and solver first, then the view can animate legal transitions around cube edges.
