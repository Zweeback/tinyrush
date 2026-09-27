class_name ParkingPanicWorld
extends Node3D

var bounds := Vector2i(6, 6)
var cell_size := 1.02
var board_offset := Vector3.ZERO
var static_cells: Array[Vector2i] = []
var landmark_cells: Array[Vector2i] = []
var theme := "paris"

var cube_width := 7.2
var cube_depth := 7.2
var cube_height := 5.4

func build(level: Dictionary, size: float) -> void:
	clear()
	cell_size = size
	bounds = _to_vec2i(level.get("bounds", [6, 6]))
	board_offset = Vector3(
		-float(bounds.x - 1) * cell_size * 0.5,
		0.0,
		-float(bounds.y - 1) * cell_size * 0.5
	)
	theme = str(level.get("theme", "paris")).to_lower()

	static_cells.clear()
	for raw_cell in level.get("static_cells", []):
		static_cells.append(_to_vec2i(raw_cell))

	landmark_cells.clear()
	for raw_cell in level.get("landmark_cells", level.get("static_cells", [])):
		landmark_cells.append(_to_vec2i(raw_cell))

	cube_width = float(bounds.x) * cell_size + 1.12
	cube_depth = float(bounds.y) * cell_size + 1.12
	cube_height = max(cube_width, cube_depth) * 0.78

	_build_cube_body()
	_build_top_roads()
	_build_static_blockers()
	_build_side_roads()
	_build_city_dressing()
	_build_exit_gate(level.get("exit", {}))

func clear() -> void:
	for child in get_children():
		child.free()

func _palette() -> Dictionary:
	match theme:
		"cairo":
			return {
				"road": Color(0.105, 0.115, 0.13, 1),
				"frame": Color(0.22, 0.24, 0.27, 1),
				"line": Color(0.95, 0.91, 0.80, 0.92),
				"accent": Color(1.0, 0.62, 0.12, 1),
				"ground": Color(0.68, 0.53, 0.30, 1)
			}
		"tokyo":
			return {
				"road": Color(0.075, 0.09, 0.13, 1),
				"frame": Color(0.18, 0.22, 0.28, 1),
				"line": Color(0.76, 0.90, 1.0, 0.94),
				"accent": Color(0.28, 0.92, 1.0, 1),
				"ground": Color(0.20, 0.42, 0.48, 1)
			}
		_:
			return {
				"road": Color(0.105, 0.115, 0.13, 1),
				"frame": Color(0.22, 0.24, 0.27, 1),
				"line": Color(0.96, 0.96, 0.93, 0.92),
				"accent": Color(0.18, 0.80, 1.0, 1),
				"ground": Color(0.30, 0.66, 0.43, 1)
			}

func _build_cube_body() -> void:
	var p: Dictionary = _palette()
	var core_size := Vector3(cube_width + 0.58, cube_height, cube_depth + 0.58)
	var core_pos := Vector3(0, -cube_height * 0.5 - 0.22, 0)
	_add_box(core_size, core_pos, Color(0.075, 0.085, 0.10, 1), 0.0, 0.48)

	# Top lip and toy-like raised frame.
	_add_box(
		Vector3(cube_width + 0.34, 0.22, cube_depth + 0.34),
		Vector3(0, -0.20, 0),
		p["frame"] as Color,
		0.0,
		0.38
	)

	# Bright edge rails make the object read as one large physical puzzle cube.
	for sx_value in [-1.0, 1.0]:
		var sx := float(sx_value)
		for sz_value in [-1.0, 1.0]:
			var sz := float(sz_value)
			_add_box(
				Vector3(0.15, cube_height + 0.08, 0.15),
				Vector3(
					sx * (cube_width * 0.5 + 0.26),
					-cube_height * 0.5 - 0.22,
					sz * (cube_depth * 0.5 + 0.26)
				),
				Color(0.40, 0.42, 0.45, 1),
				0.0,
				0.32
			)

	var rail_y := -0.08
	_add_box(Vector3(cube_width + 0.42, 0.14, 0.15), Vector3(0, rail_y, cube_depth * 0.5 + 0.26), Color(0.43, 0.45, 0.48, 1), 0.0, 0.32)
	_add_box(Vector3(cube_width + 0.42, 0.14, 0.15), Vector3(0, rail_y, -cube_depth * 0.5 - 0.26), Color(0.43, 0.45, 0.48, 1), 0.0, 0.32)
	_add_box(Vector3(0.15, 0.14, cube_depth + 0.42), Vector3(cube_width * 0.5 + 0.26, rail_y, 0), Color(0.43, 0.45, 0.48, 1), 0.0, 0.32)
	_add_box(Vector3(0.15, 0.14, cube_depth + 0.42), Vector3(-cube_width * 0.5 - 0.26, rail_y, 0), Color(0.43, 0.45, 0.48, 1), 0.0, 0.32)

func _build_top_roads() -> void:
	var p: Dictionary = _palette()
	_add_box(
		Vector3(float(bounds.x) * cell_size + 0.22, 0.12, float(bounds.y) * cell_size + 0.22),
		Vector3(0, -0.055, 0),
		p["road"] as Color,
		0.0,
		0.78
	)

	for i in range(1, bounds.x):
		var x := board_offset.x + float(i) * cell_size - cell_size * 0.5
		_add_box(
			Vector3(0.026, 0.014, float(bounds.y) * cell_size - 0.14),
			Vector3(x, 0.012, 0),
			p["line"] as Color,
			0.08,
			0.70,
			true
		)

	for j in range(1, bounds.y):
		var z := board_offset.z + float(j) * cell_size - cell_size * 0.5
		_add_box(
			Vector3(float(bounds.x) * cell_size - 0.14, 0.014, 0.026),
			Vector3(0, 0.012, z),
			p["line"] as Color,
			0.08,
			0.70,
			true
		)

	# Discrete recessed slots make the surface read as a puzzle board, not a road diorama.
	for x_index in range(bounds.x):
		for y_index in range(bounds.y):
			var cell_pos := board_offset + Vector3(float(x_index) * cell_size, 0.020, float(y_index) * cell_size)
			var slot_color := (p["road"] as Color).lightened(0.035 if (x_index + y_index) % 2 == 0 else 0.018)
			_add_box(
				Vector3(cell_size * 0.90, 0.018, cell_size * 0.90),
				cell_pos,
				slot_color,
				0.0,
				0.84
			)

	# Small center ticks keep orientation readable without turning the board into a street texture.
	for y_index in range(bounds.y):
		for x_index in range(bounds.x):
			var tick_pos := board_offset + Vector3(float(x_index) * cell_size, 0.034, float(y_index) * cell_size)
			_add_box(
				Vector3(cell_size * 0.18, 0.010, 0.035),
				tick_pos,
				Color(1, 1, 1, 0.36),
				0.02,
				0.76,
				true
			)

func _build_static_blockers() -> void:
	var p: Dictionary = _palette()
	var accent: Color = p["accent"] as Color
	for cell in static_cells:
		var pos := board_offset + Vector3(float(cell.x) * cell_size, 0.0, float(cell.y) * cell_size)
		_add_box(
			Vector3(cell_size * 0.74, 0.25, cell_size * 0.74),
			pos + Vector3(0, 0.14, 0),
			accent.darkened(0.42),
			0.08,
			0.42
		)
		_add_box(
			Vector3(cell_size * 0.52, 0.07, 0.12),
			pos + Vector3(0, 0.31, 0),
			Color(0.98, 0.82, 0.24, 1),
			0.4,
			0.34
		)

func _build_side_roads() -> void:
	var p: Dictionary = _palette()
	var panel_y := -cube_height * 0.5 - 0.22
	var front_z := cube_depth * 0.5 + 0.31
	var back_z := -cube_depth * 0.5 - 0.31
	var right_x := cube_width * 0.5 + 0.31
	var left_x := -cube_width * 0.5 - 0.31
	var face_h := cube_height - 0.34

	_add_box(Vector3(cube_width - 0.20, face_h, 0.08), Vector3(0, panel_y, front_z), p["road"] as Color, 0.0, 0.82)
	_add_box(Vector3(cube_width - 0.20, face_h, 0.08), Vector3(0, panel_y, back_z), p["road"] as Color, 0.0, 0.82)
	_add_box(Vector3(0.08, face_h, cube_depth - 0.20), Vector3(right_x, panel_y, 0), p["road"] as Color, 0.0, 0.82)
	_add_box(Vector3(0.08, face_h, cube_depth - 0.20), Vector3(left_x, panel_y, 0), p["road"] as Color, 0.0, 0.82)

	for i in range(1, bounds.x):
		var x := board_offset.x + float(i) * cell_size - cell_size * 0.5
		_add_box(Vector3(0.024, face_h - 0.16, 0.018), Vector3(x, panel_y, front_z + 0.05), p["line"] as Color, 0.04, 0.74, true)
		_add_box(Vector3(0.024, face_h - 0.16, 0.018), Vector3(x, panel_y, back_z - 0.05), p["line"] as Color, 0.04, 0.74, true)

	for j in range(1, bounds.y):
		var y := -0.42 - float(j) * (face_h - 0.16) / float(bounds.y)
		_add_box(Vector3(cube_width - 0.30, 0.024, 0.018), Vector3(0, y, front_z + 0.05), p["line"] as Color, 0.04, 0.74, true)
		_add_box(Vector3(cube_width - 0.30, 0.024, 0.018), Vector3(0, y, back_z - 0.05), p["line"] as Color, 0.04, 0.74, true)

	for i in range(1, bounds.y):
		var z := board_offset.z + float(i) * cell_size - cell_size * 0.5
		_add_box(Vector3(0.018, face_h - 0.16, 0.024), Vector3(right_x + 0.05, panel_y, z), p["line"] as Color, 0.04, 0.74, true)
		_add_box(Vector3(0.018, face_h - 0.16, 0.024), Vector3(left_x - 0.05, panel_y, z), p["line"] as Color, 0.04, 0.74, true)

	for j in range(1, bounds.y):
		var y := -0.42 - float(j) * (face_h - 0.16) / float(bounds.y)
		_add_box(Vector3(0.018, 0.024, cube_depth - 0.30), Vector3(right_x + 0.05, y, 0), p["line"] as Color, 0.04, 0.74, true)
		_add_box(Vector3(0.018, 0.024, cube_depth - 0.30), Vector3(left_x - 0.05, y, 0), p["line"] as Color, 0.04, 0.74, true)

	# Neon route arrows on the two camera-facing surfaces.
	var accent: Color = p["accent"] as Color
	for k in range(4):
		var x := -cube_width * 0.20 + float(k) * cube_width * 0.13
		var y := -cube_height * 0.73
		_add_box(Vector3(0.34, 0.08, 0.028), Vector3(x, y, front_z + 0.085), accent, 2.2, 0.28, true)
	for k in range(3):
		var z := cube_depth * 0.10 - float(k) * cube_depth * 0.14
		var y := -cube_height * 0.32
		_add_box(Vector3(0.028, 0.08, 0.34), Vector3(right_x + 0.085, y, z), Color(0.95, 0.72, 0.18, 0.95), 1.8, 0.30, true)

func _build_side_traffic() -> void:
	var colors: Array[Color] = [
		Color(0.05, 0.55, 1.0, 1),
		Color(0.18, 0.82, 0.22, 1),
		Color(0.96, 0.16, 0.20, 1),
		Color(0.98, 0.55, 0.06, 1),
		Color(0.55, 0.20, 0.90, 1),
		Color(1.0, 0.20, 0.67, 1),
		Color(0.10, 0.84, 0.92, 1)
	]
	var face_h: float = cube_height - 0.50
	var lane_count: int = maxi(1, bounds.y)

	for i in range(7):
		var lane: int = i % lane_count
		var y := -0.58 - float(lane) * face_h / float(lane_count)
		var u := -cube_width * 0.34 + float((i * 2) % 7) * cube_width * 0.11
		_build_wall_car("front", u, y, colors[i % colors.size()], i % 3 == 0, i % 2 == 1)

	for i in range(6):
		var lane: int = (i + 1) % lane_count
		var y := -0.62 - float(lane) * face_h / float(max(1, bounds.y))
		var u := -cube_depth * 0.33 + float((i * 3) % 6) * cube_depth * 0.13
		_build_wall_car("right", u, y, colors[(i + 2) % colors.size()], i % 2 == 0, i % 3 == 0)

	# A few silhouettes on the other faces make orbiting the cube still feel populated.
	for i in range(3):
		var y := -1.0 - float(i) * face_h * 0.25
		_build_wall_car("left", -cube_depth * 0.18 + float(i) * cube_depth * 0.18, y, colors[(i + 4) % colors.size()], i == 1, i % 2 == 0)
		_build_wall_car("back", -cube_width * 0.20 + float(i) * cube_width * 0.20, y - 0.25, colors[(i + 1) % colors.size()], i == 2, i % 2 == 1)

func _build_wall_car(face: String, u: float, y: float, color: Color, truck: bool, vertical: bool) -> void:
	var long_size := 1.28 if truck else 0.90
	var short_size := 0.58
	var thickness := 0.28
	var dark := Color(0.035, 0.045, 0.06, 1)
	var glass := Color(0.05, 0.23, 0.38, 1)

	match face:
		"front":
			var z := cube_depth * 0.5 + 0.41
			var body_size := Vector3(short_size, long_size, thickness) if vertical else Vector3(long_size, short_size, thickness)
			_add_box(body_size, Vector3(u, y, z), color, 0.06, 0.34)
			var window_size := Vector3(short_size * 0.64, long_size * 0.34, 0.035) if vertical else Vector3(long_size * 0.34, short_size * 0.64, 0.035)
			_add_box(window_size, Vector3(u, y + 0.02, z + thickness * 0.55), glass, 0.15, 0.24)
			_add_wall_wheels_front(u, y, z + thickness * 0.54, long_size, short_size, vertical, dark)
		"back":
			var z := -cube_depth * 0.5 - 0.41
			var body_size := Vector3(short_size, long_size, thickness) if vertical else Vector3(long_size, short_size, thickness)
			_add_box(body_size, Vector3(u, y, z), color, 0.04, 0.34)
			var window_size := Vector3(short_size * 0.64, long_size * 0.34, 0.035) if vertical else Vector3(long_size * 0.34, short_size * 0.64, 0.035)
			_add_box(window_size, Vector3(u, y + 0.02, z - thickness * 0.55), glass, 0.10, 0.24)
		"right":
			var x := cube_width * 0.5 + 0.41
			var body_size := Vector3(thickness, long_size, short_size) if vertical else Vector3(thickness, short_size, long_size)
			_add_box(body_size, Vector3(x, y, u), color, 0.06, 0.34)
			var window_size := Vector3(0.035, long_size * 0.34, short_size * 0.64) if vertical else Vector3(0.035, short_size * 0.64, long_size * 0.34)
			_add_box(window_size, Vector3(x + thickness * 0.55, y + 0.02, u), glass, 0.15, 0.24)
			_add_wall_wheels_right(x + thickness * 0.54, y, u, long_size, short_size, vertical, dark)
		"left":
			var x := -cube_width * 0.5 - 0.41
			var body_size := Vector3(thickness, long_size, short_size) if vertical else Vector3(thickness, short_size, long_size)
			_add_box(body_size, Vector3(x, y, u), color, 0.04, 0.34)
			var window_size := Vector3(0.035, long_size * 0.34, short_size * 0.64) if vertical else Vector3(0.035, short_size * 0.64, long_size * 0.34)
			_add_box(window_size, Vector3(x - thickness * 0.55, y + 0.02, u), glass, 0.10, 0.24)

func _add_wall_wheels_front(u: float, y: float, z: float, long_size: float, short_size: float, vertical: bool, color: Color) -> void:
	var a := long_size * 0.34
	var b := short_size * 0.43
	if vertical:
		for sy_value in [-1.0, 1.0]:
			for sx_value in [-1.0, 1.0]:
				_add_box(Vector3(0.14, 0.14, 0.04), Vector3(u + float(sx_value) * b, y + float(sy_value) * a, z + 0.03), color, 0.0, 0.76)
	else:
		for sx_value in [-1.0, 1.0]:
			for sy_value in [-1.0, 1.0]:
				_add_box(Vector3(0.14, 0.14, 0.04), Vector3(u + float(sx_value) * a, y + float(sy_value) * b, z + 0.03), color, 0.0, 0.76)

func _add_wall_wheels_right(x: float, y: float, u: float, long_size: float, short_size: float, vertical: bool, color: Color) -> void:
	var a := long_size * 0.34
	var b := short_size * 0.43
	if vertical:
		for sy_value in [-1.0, 1.0]:
			for sz_value in [-1.0, 1.0]:
				_add_box(Vector3(0.04, 0.14, 0.14), Vector3(x + 0.03, y + float(sy_value) * a, u + float(sz_value) * b), color, 0.0, 0.76)
	else:
		for sz_value in [-1.0, 1.0]:
			for sy_value in [-1.0, 1.0]:
				_add_box(Vector3(0.04, 0.14, 0.14), Vector3(x + 0.03, y + float(sy_value) * b, u + float(sz_value) * a), color, 0.0, 0.76)

func _build_city_dressing() -> void:
	var p: Dictionary = _palette()
	var base_y := -cube_height - 0.56
	_add_box(
		Vector3(cube_width + 9.0, 0.26, cube_depth + 9.0),
		Vector3(0, base_y, 0),
		p["ground"] as Color,
		0.0,
		0.92
	)

	var colors: Array[Color] = [
		Color(0.95, 0.34, 0.24, 1),
		Color(0.22, 0.56, 0.92, 1),
		Color(0.98, 0.72, 0.22, 1),
		Color(0.38, 0.76, 0.46, 1),
		Color(0.68, 0.38, 0.86, 1),
		Color(0.96, 0.46, 0.68, 1)
	]

	var radius: float = maxf(cube_width, cube_depth) * 0.5 + 2.3
	for i in range(18):
		var angle := TAU * float(i) / 18.0
		var ring: float = radius + float(i % 3) * 0.55
		var h := 0.90 + float(i % 5) * 0.34
		var w := 0.55 + float(i % 2) * 0.22
		var d := 0.55 + float((i + 1) % 2) * 0.18
		var pos := Vector3(cos(angle) * ring, base_y + 0.13 + h * 0.5, sin(angle) * ring)
		var building := _add_box(Vector3(w, h, d), pos, colors[i % colors.size()], 0.0, 0.58)
		building.rotation.y = -angle + 0.32

	for i in range(12):
		var angle := TAU * (float(i) + 0.5) / 12.0
		var ring: float = radius - 0.85 + float(i % 2) * 0.42
		var tree_pos := Vector3(cos(angle) * ring, base_y + 0.40, sin(angle) * ring)
		_add_box(Vector3(0.10, 0.46, 0.10), tree_pos, Color(0.34, 0.20, 0.10, 1), 0.0, 0.88)
		_add_sphere(0.30, tree_pos + Vector3(0, 0.36, 0), Color(0.30, 0.72, 0.28, 1))

func _build_exit_gate(exit_data: Dictionary) -> void:
	var row := int(exit_data.get("row", 2))
	var sign := int(exit_data.get("sign", 1))
	var axis := _to_vec2i(exit_data.get("axis", [1, 0]))
	var accent: Color = _palette()["accent"] as Color

	if axis == Vector2i(1, 0):
		var gate_x := board_offset.x + (float(bounds.x) * cell_size + 0.22 if sign > 0 else -0.22)
		var gate_z := board_offset.z + float(row) * cell_size
		_add_box(Vector3(0.14, 0.16, 0.88), Vector3(gate_x, 0.17, gate_z), accent, 2.8, 0.28)
	elif axis == Vector2i(0, 1):
		var gate_x := board_offset.x + float(row) * cell_size
		var gate_z := board_offset.z + (float(bounds.y) * cell_size + 0.22 if sign > 0 else -0.22)
		_add_box(Vector3(0.88, 0.16, 0.14), Vector3(gate_x, 0.17, gate_z), accent, 2.8, 0.28)

func _add_box(size: Vector3, pos: Vector3, color: Color, emission: float = 0.0, roughness: float = 0.55, transparent: bool = false) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.position = pos
	item.material_override = _mat(color, emission, roughness, transparent)
	add_child(item)
	return item

func _add_sphere(radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	item.mesh = mesh
	item.position = pos
	item.material_override = _mat(color, 0.0, 0.72)
	add_child(item)
	return item

func _mat(color: Color, emission_strength: float = 0.0, roughness: float = 0.55, transparent: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = 0.03
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission_strength > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_strength
	return mat

func _to_vec2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
