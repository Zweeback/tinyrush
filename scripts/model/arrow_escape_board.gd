class_name ArrowEscapeBoard
extends RefCounted

var bounds := Vector2i(7, 7)
var static_cells: Array[Vector2i] = []
var cars: Dictionary = {}
var active: Dictionary = {}

func configure(level: Dictionary) -> void:
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
	return true

func apply_move(car_id: String, sign: int) -> Dictionary:
	if sign != 1:
		return {"ok": false, "exit": false, "reason": "wrong_direction"}
	if not is_active(car_id):
		return {"ok": false, "exit": false, "reason": "inactive"}
	if not can_escape(car_id):
		return {"ok": false, "exit": false, "reason": "blocked"}
	active[car_id] = false
	var car: ParkingCarState = get_car(car_id)
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

func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < bounds.x and cell.y >= 0 and cell.y < bounds.y

func _to_vec2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
