class_name ArrowEscapeBoard
extends RefCounted

var bounds := Vector2i(7, 7)
var static_cells: Array[Vector2i] = []
var cars: Dictionary = {}
var active: Dictionary = {}
var level_source: Dictionary = {}

func configure(level: Dictionary) -> void:
	level_source = level.duplicate(true)
	cars.clear()
	active.clear()
	static_cells.clear()
	bounds = _to_vec2i(level.get("bounds", [7, 7]))
	for raw_cell in level.get("static_cells", []):
		static_cells.append(_to_vec2i(raw_cell))
	for raw_car in level.get("cars", []):
		if not raw_car is Dictionary:
			continue
		var car: ParkingCarState = ParkingCarState.from_dictionary(raw_car)
		cars[car.car_id] = car
		active[car.car_id] = true

func reset_from_level(level: Dictionary) -> void:
	configure(level)

func car_ids() -> Array:
	var ids: Array = cars.keys()
	ids.sort()
	return ids

func get_car(car_id: String) -> ParkingCarState:
	return cars.get(car_id) as ParkingCarState

func get_spec(car_id: String) -> Dictionary:
	var car: ParkingCarState = get_car(car_id)
	if car == null:
		return {}
	var spec := car.to_view_spec()
	spec["arrow_mode"] = true
	spec["escape_dir"] = car.escape_dir
	return spec

func source_level() -> Dictionary:
	return level_source.duplicate(true)

func get_position(car_id: String) -> Vector2i:
	var car: ParkingCarState = get_car(car_id)
	return Vector2i.ZERO if car == null else car.grid_pos

func set_position(car_id: String, value: Vector2i) -> void:
	var car: ParkingCarState = get_car(car_id)
	if car != null:
		car.grid_pos = value

func is_active(car_id: String, state: Dictionary = {}) -> bool:
	var source: Dictionary = active if state.is_empty() else state
	return bool(source.get(car_id, false))

func active_map() -> Dictionary:
	return active.duplicate(true)

func remaining_count(state: Dictionary = {}) -> int:
	var source: Dictionary = active if state.is_empty() else state
	var count := 0
	for value in source.values():
		if bool(value):
			count += 1
	return count

func restore_car(car_id: String) -> void:
	if cars.has(car_id):
		active[car_id] = true

func can_move(car_id: String, sign: int) -> bool:
	if sign != 1:
		return false
	return can_escape(car_id)

func can_escape(car_id: String, state: Dictionary = {}) -> bool:
	var car: ParkingCarState = get_car(car_id)
	if car == null:
		return false
	var source: Dictionary = active if state.is_empty() else state
	if not bool(source.get(car_id, false)):
		return false
	var direction: Vector2i = car.escape_dir
	if direction == Vector2i.ZERO:
		return false

	var occupied_other := {}
	for other_value in car_ids():
		var other_id := str(other_value)
		if other_id == car_id or not bool(source.get(other_id, false)):
			continue
		var other: ParkingCarState = get_car(other_id)
		if other.face != car.face:
			continue
		for cell in other.occupied_cells():
			occupied_other[cell] = other_id

	var cells: Array[Vector2i] = car.occupied_cells()
	var lead := cells[0]
	var best_dot := lead.x * direction.x + lead.y * direction.y
	for cell in cells:
		var score := cell.x * direction.x + cell.y * direction.y
		if score > best_dot:
			best_dot = score
			lead = cell

	var cursor := lead + direction
	while inside(cursor):
		if cursor in static_cells or occupied_other.has(cursor):
			return false
		cursor += direction

	if car.edge_hops_remaining > 0:
		var transition := CubeFaceTopology.wrap_pose(car.face, car.grid_pos, car.axis, car.escape_dir, car.length_cells, bounds)
		if transition.is_empty() or _pose_blocked(car_id, transition, source):
			return false
	return true

func apply_move(car_id: String, sign: int) -> Dictionary:
	if sign != 1:
		return {"ok": false, "exit": false, "reason": "wrong_direction"}
	if not is_active(car_id):
		return {"ok": false, "exit": false, "reason": "inactive"}
	if not can_escape(car_id):
		return {"ok": false, "exit": false, "reason": "blocked"}
	var car: ParkingCarState = get_car(car_id)
	if car.edge_hops_remaining > 0:
		var transition := CubeFaceTopology.wrap_pose(car.face, car.grid_pos, car.axis, car.escape_dir, car.length_cells, bounds)
		if transition.is_empty() or _pose_blocked(car_id, transition, active):
			return {"ok": false, "exit": false, "reason": "destination_blocked"}
		var from_face := car.face
		car.face = str(transition["to_face"])
		car.grid_pos = transition["pos"]
		car.axis = transition["axis"]
		car.escape_dir = transition["escape_dir"]
		car.edge_hops_remaining -= 1
		return {
			"ok": true,
			"exit": false,
			"transition": true,
			"id": car_id,
			"from_face": from_face,
			"to_face": car.face,
			"remaining": remaining_count(),
		}

	active[car_id] = false
	return {
		"ok": true,
		"exit": true,
		"id": car_id,
		"sign": 1,
		"escape_dir": car.escape_dir,
		"remaining": remaining_count()
	}

func legal_steps(state: Dictionary = {}) -> Array[Dictionary]:
	var source: Dictionary = active_map() if state.is_empty() else state
	var result: Array[Dictionary] = []
	for car_id_value in car_ids():
		var car_id := str(car_id_value)
		if bool(source.get(car_id, false)) and can_escape(car_id, source):
			result.append({"id": car_id})
	return result

func next_state_after_escape(state: Dictionary, car_id: String) -> Dictionary:
	var next := state.duplicate(true)
	next[car_id] = false
	return next

func state_key(state: Dictionary = {}) -> String:
	var source: Dictionary = active if state.is_empty() else state
	var bits: Array[String] = []
	for car_id_value in car_ids():
		var car_id := str(car_id_value)
		bits.append("1" if bool(source.get(car_id, false)) else "0")
	return "".join(bits)

func requires_topology_state() -> bool:
	for car_id_value in car_ids():
		if get_car(str(car_id_value)).edge_hops_remaining > 0:
			return true
	return false

func export_state() -> Dictionary:
	var result := {}
	for car_id_value in car_ids():
		var car_id := str(car_id_value)
		var car := get_car(car_id)
		result[car_id] = {
			"active": is_active(car_id),
			"face": car.face,
			"pos": [car.grid_pos.x, car.grid_pos.y],
			"axis": [car.axis.x, car.axis.y],
			"escape_dir": [car.escape_dir.x, car.escape_dir.y],
			"edge_hops": car.edge_hops_remaining,
		}
	return result

func import_state(state: Dictionary) -> void:
	for car_id_value in car_ids():
		var car_id := str(car_id_value)
		var saved: Dictionary = state.get(car_id, {})
		if saved.is_empty():
			continue
		var car := get_car(car_id)
		active[car_id] = bool(saved.get("active", true))
		car.face = str(saved.get("face", car.face))
		car.grid_pos = _to_vec2i(saved.get("pos", [car.grid_pos.x, car.grid_pos.y]))
		car.axis = _to_vec2i(saved.get("axis", [car.axis.x, car.axis.y]))
		car.escape_dir = _to_vec2i(saved.get("escape_dir", [car.escape_dir.x, car.escape_dir.y]))
		car.edge_hops_remaining = int(saved.get("edge_hops", car.edge_hops_remaining))

func topology_state_key() -> String:
	var parts: Array[String] = []
	for car_id_value in car_ids():
		var car_id := str(car_id_value)
		var car := get_car(car_id)
		parts.append("%s:%d:%s:%d,%d:%d,%d:%d,%d:%d" % [
			car_id, int(is_active(car_id)), car.face,
			car.grid_pos.x, car.grid_pos.y, car.axis.x, car.axis.y,
			car.escape_dir.x, car.escape_dir.y, car.edge_hops_remaining,
		])
	return "|".join(parts)

func _pose_blocked(car_id: String, pose: Dictionary, state: Dictionary) -> bool:
	var target_face := str(pose.get("to_face", ""))
	var target_pos: Vector2i = pose.get("pos", Vector2i.ZERO)
	var target_axis: Vector2i = pose.get("axis", Vector2i.ZERO)
	var car := get_car(car_id)
	for i in range(car.length_cells):
		var cell := target_pos + target_axis * i
		if not inside(cell):
			return true
		for other_value in car_ids():
			var other_id := str(other_value)
			if other_id == car_id or not bool(state.get(other_id, false)):
				continue
			var other := get_car(other_id)
			if other.face == target_face and cell in other.occupied_cells():
				return true
	return false

func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < bounds.x and cell.y >= 0 and cell.y < bounds.y

func _to_vec2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
