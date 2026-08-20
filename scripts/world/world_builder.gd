class_name ParkingPanicWorld
extends Node3D

var bounds := Vector2i(6, 6)
var cell_size := 1.02
var board_offset := Vector3.ZERO
var static_cells: Array[Vector2i] = []
var landmark_cells: Array[Vector2i] = []
var theme := "paris"

func build(level: Dictionary, size: float) -> void:
	clear()
	cell_size = size
	bounds = _to_vec2i(level.get("bounds", [6, 6]))
	board_offset = Vector3(-float(bounds.x - 1) * cell_size * 0.5, 0.0, -float(bounds.y - 1) * cell_size * 0.5)
	theme = str(level.get("theme", "paris")).to_lower()
	static_cells.clear()
	for raw_cell in level.get("static_cells", []):
		static_cells.append(_to_vec2i(raw_cell))
	landmark_cells.clear()
	for raw_cell in level.get("landmark_cells", level.get("static_cells", [])):
		landmark_cells.append(_to_vec2i(raw_cell))
	_build_island()
	_build_roads()
	_build_static_blockers()
	_build_landmark(str(level.get("landmark", "eiffel")))
	_build_city_dressing()
	_build_exit_gate(level.get("exit", {}))

func clear() -> void:
	for child in get_children():
		child.free()

func _palette() -> Dictionary:
	match theme:
		"cairo":
			return {"ground": Color(0.76,0.57,0.28,1), "soil": Color(0.42,0.27,0.12,1), "road": Color(0.20,0.18,0.16,1), "line": Color(1.0,0.88,0.50,0.72), "accent": Color(1.0,0.63,0.16,1)}
		"tokyo":
			return {"ground": Color(0.23,0.39,0.43,1), "soil": Color(0.12,0.16,0.22,1), "road": Color(0.09,0.11,0.16,1), "line": Color(0.35,0.88,1.0,0.78), "accent": Color(1.0,0.18,0.52,1)}
		_:
			return {"ground": Color(0.31,0.66,0.42,1), "soil": Color(0.38,0.22,0.12,1), "road": Color(0.16,0.18,0.21,1), "line": Color(0.95,0.86,0.55,0.62), "accent": Color(1.0,0.76,0.16,1)}

func _build_island() -> void:
	var p := _palette()
	var width := float(bounds.x) * cell_size + 1.35
	var depth := float(bounds.y) * cell_size + 1.35
	_add_box(Vector3(width, 1.55, depth), Vector3(0, -0.98, 0), p["ground"], 0.0, 0.70)
	_add_box(Vector3(max(0.5, width - 0.5), 0.45, max(0.5, depth - 0.5)), Vector3(0, -1.72, 0), p["soil"], 0.0, 0.86)

func _build_roads() -> void:
	var p := _palette()
	_add_box(Vector3(float(bounds.x) * cell_size + 0.22, 0.13, float(bounds.y) * cell_size + 0.22), Vector3(0, -0.10, 0), p["road"], 0.0, 0.90)
	for i in range(1, bounds.x):
		_add_box(Vector3(0.025, 0.012, float(bounds.y) * cell_size - 0.18), Vector3(board_offset.x + float(i) * cell_size - cell_size * 0.5, 0.0, 0), p["line"], 0.10, 0.75, true)
	for j in range(1, bounds.y):
		_add_box(Vector3(float(bounds.x) * cell_size - 0.18, 0.012, 0.025), Vector3(0, 0.0, board_offset.z + float(j) * cell_size - cell_size * 0.5), p["line"], 0.10, 0.75, true)
	for cell in static_cells:
		var pos := board_offset + Vector3(float(cell.x) * cell_size, 0.035, float(cell.y) * cell_size)
		_add_box(Vector3(cell_size * 0.94, 0.05, cell_size * 0.94), pos, p["accent"].darkened(0.25), 0.0, 0.76)

func _build_static_blockers() -> void:
	var p := _palette()
	for cell in static_cells:
		if cell in landmark_cells:
			continue
		var pos := board_offset + Vector3(float(cell.x) * cell_size, 0.0, float(cell.y) * cell_size)
		_add_box(Vector3(cell_size * 0.72, 0.24, cell_size * 0.72), pos + Vector3(0, 0.13, 0), p["accent"].darkened(0.18), 0.18, 0.72)
		_add_box(Vector3(cell_size * 0.56, 0.08, 0.10), pos + Vector3(0, 0.31, 0), Color(0.96, 0.96, 0.94, 1), 0.10, 0.58)

func _build_landmark(kind: String) -> void:
	match kind:
		"pyramid": _build_pyramid()
		"tokyo_tower": _build_tokyo_tower()
		_: _build_eiffel_tower()

func _landmark_center() -> Vector3:
	var cells := landmark_cells if not landmark_cells.is_empty() else static_cells
	if cells.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for cell in cells:
		sum += board_offset + Vector3(float(cell.x) * cell_size, 0.10, float(cell.y) * cell_size)
	return sum / float(cells.size())

func _build_eiffel_tower() -> void:
	var center := _landmark_center()
	var bronze := Color(0.39, 0.26, 0.18, 1)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_beam(center + Vector3(sx * 0.82, 0.15, sz * 0.82), center + Vector3(sx * 0.44, 1.75, sz * 0.44), 0.12, bronze)
			_add_beam(center + Vector3(sx * 0.44, 1.75, sz * 0.44), center + Vector3(sx * 0.10, 3.45, sz * 0.10), 0.085, bronze)
	_add_box(Vector3(1.42, 0.10, 1.42), center + Vector3(0, 1.12, 0), bronze, 0.0, 0.48)
	_add_box(Vector3(0.84, 0.08, 0.84), center + Vector3(0, 2.26, 0), bronze, 0.0, 0.48)
	_add_box(Vector3(0.24, 0.08, 0.24), center + Vector3(0, 3.50, 0), Color(1.0, 0.72, 0.28, 1), 1.5, 0.48)
	_add_beam(center + Vector3(0, 3.50, 0), center + Vector3(0, 4.08, 0), 0.055, bronze)

func _build_pyramid() -> void:
	var center := _landmark_center()
	var sand := Color(0.88, 0.66, 0.30, 1)
	for layer in range(6):
		var t := float(layer) / 5.0
		var width := lerp(1.95, 0.24, t)
		_add_box(Vector3(width, 0.32, width), center + Vector3(0, 0.16 + float(layer) * 0.30, 0), sand.lightened(t * 0.10), 0.0, 0.88)

func _build_tokyo_tower() -> void:
	var center := _landmark_center()
	var red := Color(0.92, 0.16, 0.18, 1)
	var white := Color(0.94, 0.95, 0.98, 1)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_beam(center + Vector3(sx * 0.58, 0.10, sz * 0.58), center + Vector3(sx * 0.16, 2.45, sz * 0.16), 0.09, red)
	_add_box(Vector3(1.05,0.10,1.05), center + Vector3(0,1.0,0), white, 0.2, 0.42)
	_add_box(Vector3(0.58,0.08,0.58), center + Vector3(0,2.0,0), red, 0.3, 0.42)
	_add_beam(center + Vector3(0,2.35,0), center + Vector3(0,3.55,0), 0.06, white)
	_add_box(Vector3(0.14,0.14,0.14), center + Vector3(0,3.58,0), Color(1.0,0.20,0.60,1), 2.8, 0.32)

func _build_city_dressing() -> void:
	var colors: Array[Color]
	match theme:
		"cairo": colors = [Color(0.86,0.68,0.42,1),Color(0.94,0.79,0.53,1),Color(0.72,0.50,0.28,1)]
		"tokyo": colors = [Color(0.26,0.38,0.62,1),Color(0.66,0.32,0.58,1),Color(0.20,0.64,0.70,1),Color(0.78,0.78,0.88,1)]
		_: colors = [Color(0.96,0.72,0.56,1),Color(0.86,0.89,0.94,1),Color(0.98,0.85,0.50,1),Color(0.77,0.88,0.78,1),Color(0.92,0.68,0.76,1)]
	var edge_radius := max(float(bounds.x), float(bounds.y)) * cell_size * 0.5 + 1.25
	for i in range(14):
		var angle := TAU * float(i) / 14.0
		var radius := edge_radius + float(i % 3) * 0.28
		var h := 0.65 + float(i % 4) * 0.24
		var building := _add_box(Vector3(0.48 + float(i % 2) * 0.18, h, 0.48 + float((i + 1) % 2) * 0.16), Vector3(cos(angle) * radius, -0.05 + h * 0.5, sin(angle) * radius), colors[i % colors.size()], 0.0, 0.76)
		building.rotation.y = -angle + 0.3

func _build_exit_gate(exit_data: Dictionary) -> void:
	var row := int(exit_data.get("row", 2))
	var sign := int(exit_data.get("sign", 1))
	var axis := _to_vec2i(exit_data.get("axis", [1, 0]))
	if axis == Vector2i(1, 0):
		var gate_x := board_offset.x + (float(bounds.x) * cell_size + 0.22 if sign > 0 else -0.22)
		var gate_z := board_offset.z + float(row) * cell_size
		_add_box(Vector3(0.12, 0.15, 0.86), Vector3(gate_x, 0.16, gate_z), _palette()["accent"], 2.6, 0.36)
	elif axis == Vector2i(0, 1):
		var gate_x := board_offset.x + float(row) * cell_size
		var gate_z := board_offset.z + (float(bounds.y) * cell_size + 0.22 if sign > 0 else -0.22)
		_add_box(Vector3(0.86, 0.15, 0.12), Vector3(gate_x, 0.16, gate_z), _palette()["accent"], 2.6, 0.36)

func _add_box(size: Vector3, pos: Vector3, color: Color, emission: float = 0.0, roughness: float = 0.55, transparent: bool = false) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.position = pos
	item.material_override = _mat(color, emission, roughness, transparent)
	add_child(item)
	return item

func _add_beam(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var beam := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var direction := b - a
	mesh.size = Vector3(width, direction.length(), width)
	beam.mesh = mesh
	beam.position = (a + b) * 0.5
	beam.quaternion = Quaternion(Vector3.UP, direction.normalized())
	beam.material_override = _mat(color, 0.0, 0.52)
	add_child(beam)

func _mat(color: Color, emission_strength: float = 0.0, roughness: float = 0.55, transparent: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
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
