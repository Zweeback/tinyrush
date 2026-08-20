class_name ParkingBoard
extends RefCounted

var bounds := Vector2i(6, 6)
var static_cells: Array[Vector2i] = []
var cars: Dictionary = {}
var target_id := ""
var exit_axis := Vector2i(1, 0)
var exit_sign := 1
var exit_row := 0

func configure(level: Dictionary) -> void:
	cars.clear()
	static_cells.clear()
	bounds = _to_vec2i(level.get("bounds", [6, 6]))
	for raw_cell in level.get("static_cells", []):
		static_cells.append(_to_vec2i(raw_cell))

	var exit_data: Dictionary = level.get("exit", {})
	target_id = str(exit_data.get("target", "hero"))
	exit_axis = _to_vec2i(exit_data.get("axis", [1, 0]))
	exit_sign = int(exit_data.get("sign", 1))
	exit_row = int(exit_data.get("row", 0))

	for raw_car in level.get("cars", []):
		if not raw_car is Dictionary:
			continue
		var car: ParkingCarState = ParkingCarState.from_dictionary(raw_car)
		cars[car.car_id] = car

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
	return {} if car == null else car.to_view_spec()

func get_position(car_id: String) -> Vector2i:
	var car: ParkingCarState = get_car(car_id)
	return Vector2i.ZERO if car == null else car.grid_pos

func set_position(car_id: String, value: Vector2i) -> void:
	var car: ParkingCarState = get_car(car_id)
	if car != null:
		car.grid_pos = value

func occupied_cells(car_id: String, at_pos: Variant = null, state: Dictionary = {}) -> Array[Vector2i]:
	var car: ParkingCarState = get_car(car_id)
	if car == null:
		return []
	if at_pos is Vector2i:
		return car.occupied_cells(at_pos)
	if not state.is_empty():
		var state_pos: Vector2i = state.get(car_id, car.grid_pos)
		return car.occupied_cells(state_pos)
	return car.occupied_cells()

func occupied_map(state: Dictionary = {}, exclude_id: String = "") -> Dictionary:
	var positions: Dictionary = clone_positions() if state.is_empty() else state
	var result: Dictionary = {}
	for car_id_value in car_ids():
		var car_id := str(car_id_value)
		if car_id == exclude_id:
			continue
		var car: ParkingCarState = get_car(car_id)
		if car == null:
			continue
		var pos: Vector2i = positions.get(car_id, car.grid_pos)
		for cell in car.occupied_cells(pos):
			result[cell] = car_id
	return result

func can_move(car_id: String, sign: int) -> bool:
	if sign != -1 and sign != 1:
		return false
	if can_exit(car_id, sign):
		return true
	var car: ParkingCarState = get_car(car_id)
	if car == null:
		return false
	return can_place(car_id, car.grid_pos + car.axis * sign)

func apply_move(car_id: String, sign: int) -> Dictionary:
	if sign != -1 and sign != 1:
		return {"ok": false, "exit": false, "reason": "invalid_sign"}
	var car: ParkingCarState = get_car(car_id)
	if car == null:
		return {"ok": false, "exit": false, "reason": "missing_car"}
	var from: Vector2i = car.grid_pos
	if can_exit(car_id, sign):
		return {"ok": true, "exit": true, "id": car_id, "sign": sign, "from": from, "to": from}
	var next_pos: Vector2i = from + car.axis * sign
	if not can_place(car_id, next_pos):
		return {"ok": false, "exit": false, "reason": "blocked"}
	car.grid_pos = next_pos
	return {"ok": true, "exit": false, "id": car_id, "sign": sign, "from": from, "to": next_pos}

func can_place(car_id: String, at_pos: Vector2i, state: Dictionary = {}) -> bool:
	var car: ParkingCarState = get_car(car_id)
	if car == null:
		return false
	var positions: Dictionary = clone_positions() if state.is_empty() else state
	var occupied_other: Dictionary = occupied_map(positions, car_id)
	for cell in car.occupied_cells(at_pos):
		if not inside(cell):
			return false
		if cell in static_cells:
			return false
		if occupied_other.has(cell):
			return false
	return true

func can_exit(car_id: String, sign: int, state: Dictionary = {}) -> bool:
	if car_id != target_id or sign != exit_sign:
		return false
	var car: ParkingCarState = get_car(car_id)
	if car == null or car.axis != exit_axis:
		return false
	var positions: Dictionary = clone_positions() if state.is_empty() else state
	var pos: Vector2i = positions.get(car_id, car.grid_pos)
	if exit_axis == Vector2i(1, 0):
		if pos.y != exit_row:
			return false
		return pos.x + car.length_cells >= bounds.x if exit_sign > 0 else pos.x <= 0
	if exit_axis == Vector2i(0, 1):
		if pos.x != exit_row:
			return false
		return pos.y + car.length_cells >= bounds.y if exit_sign > 0 else pos.y <= 0
	return false

func legal_steps(state: Dictionary = {}) -> Array[Dictionary]:
	var positions: Dictionary = clone_positions() if state.is_empty() else state
	var result: Array[Dictionary] = []
	for car_id_value in car_ids():
		var car_id := str(car_id_value)
		var car: ParkingCarState = get_car(car_id)
		if car == null:
			continue
		for sign_value in [-1, 1]:
			var sign := int(sign_value)
			if can_exit(car_id, sign, positions):
				result.append({"id": car_id, "sign": sign, "exit": true})
				continue
			var current: Vector2i = positions.get(car_id, car.grid_pos)
			var next_pos: Vector2i = current + car.axis * sign
			if can_place(car_id, next_pos, positions):
				result.append({"id": car_id, "sign": sign, "exit": false, "to": next_pos})
	return result

func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < bounds.x and cell.y >= 0 and cell.y < bounds.y

func clone_positions() -> Dictionary:
	var result: Dictionary = {}
	for car_id_value in cars.keys():
		var car_id := str(car_id_value)
		result[car_id] = get_position(car_id)
	return result

func state_key(state: Dictionary = {}) -> String:
	var positions: Dictionary = clone_positions() if state.is_empty() else state
	var parts: Array[String] = []
	for car_id_value in car_ids():
		var car_id := str(car_id_value)
		var p: Vector2i = positions.get(car_id, Vector2i.ZERO)
		parts.append("%s:%d,%d" % [car_id, p.x, p.y])
	return "|".join(parts)

func _to_vec2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
