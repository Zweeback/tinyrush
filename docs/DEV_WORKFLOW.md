# Developer workflow

Work in small branches with one primary lane: gameplay/systems, puzzle/tools, 3D/juice, or QA/release. Open a PR into `main`, keep CI green, and prefer squash merge for feature branches.

For the signature cube mechanic, land the model/topology representation and solver tests before any edge-wrapping animation. Visual code must consume legal transitions from the model rather than creating them independently.
