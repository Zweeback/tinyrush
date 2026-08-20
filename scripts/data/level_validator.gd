class_name ParkingPanicLevelValidator
extends RefCounted

const VALID_AXES := [Vector2i(1, 0), Vector2i(0, 1)]

func validate(level: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var bounds := _to_vec2i(level.get("bounds", []))
	if bounds.x <= 0 or bounds.y <= 0:
		errors.append("bounds must be two positive integers")
		return errors

	var static_seen := {}
	for raw_cell in level.get("static_cells", []):
		var cell := _to_vec2i(raw_cell)
		var key := _cell_key(cell)
		if not _inside(cell, bounds):
			errors.append("static cell %s is out of bounds" % key)
		if static_seen.has(key):
			errors.append("duplicate static cell %s" % key)
		static_seen[key] = true

	var landmark_seen := {}
	for raw_cell in level.get("landmark_cells", []):
		var cell := _to_vec2i(raw_cell)
		var key := _cell_key(cell)
		if not _inside(cell, bounds):
			errors.append("landmark cell %s is out of bounds" % key)
		if not static_seen.has(key):
			errors.append("landmark cell %s must also be static" % key)
		if landmark_seen.has(key):
			errors.append("duplicate landmark cell %s" % key)
		landmark_seen[key] = true

	var raw_cars: Array = level.get("cars", [])
	if raw_cars.is_empty():
		errors.append("level has no cars")
		return errors

	var car_ids := {}
	var occupied := {}
	var target_flags: Array[String] = []
	var car_specs := {}
	for value in raw_cars:
		if not value is Dictionary:
			errors.append("car entry must be an object")
			continue
		var car: Dictionary = value
		var car_id := str(car.get("id", "")).strip_edges()
		if car_id.is_empty():
			errors.append("car id must not be empty")
			continue
		if car_ids.has(car_id):
			errors.append("duplicate car id %s" % car_id)
			continue
		car_ids[car_id] = true

		var axis := _to_vec2i(car.get("axis", []))
		var pos := _to_vec2i(car.get("pos", []))
		var length_cells := int(car.get("len", 0))
		if axis not in VALID_AXES:
			errors.append("%s has invalid axis %s" % [car_id, axis])
		if length_cells < 1:
			errors.append("%s length must be at least 1" % car_id)
		if bool(car.get("target", false)):
			target_flags.append(car_id)
		car_specs[car_id] = {"axis": axis, "pos": pos, "len": length_cells}

		if axis in VALID_AXES and length_cells >= 1:
			for i in range(length_cells):
				var cell := pos + axis * i
				var key := _cell_key(cell)
				if not _inside(cell, bounds):
					errors.append("%s is out of bounds at %s" % [car_id, key])
				if static_seen.has(key):
					errors.append("%s overlaps static cell %s" % [car_id, key])
				if occupied.has(key):
					errors.append("%s overlaps %s at %s" % [car_id, occupied[key], key])
				else:
					occupied[key] = car_id

	var exit_data: Dictionary = level.get("exit", {})
	var target_id := str(exit_data.get("target", "")).strip_edges()
	var exit_axis := _to_vec2i(exit_data.get("axis", []))
	var exit_sign := int(exit_data.get("sign", 0))
	var exit_row := int(exit_data.get("row", -1))

	if target_id.is_empty() or not car_ids.has(target_id):
		errors.append("exit target is missing")
	if exit_axis not in VALID_AXES:
		errors.append("exit axis must be [1,0] or [0,1]")
	if exit_sign != -1 and exit_sign != 1:
		errors.append("exit sign must be -1 or 1")
	if exit_axis == Vector2i(1, 0) and (exit_row < 0 or exit_row >= bounds.y):
		errors.append("exit row is outside board height")
	if exit_axis == Vector2i(0, 1) and (exit_row < 0 or exit_row >= bounds.x):
		errors.append("exit row is outside board width")

	if target_flags.size() != 1:
		errors.append("exactly one car must have target=true")
	elif not target_id.is_empty() and target_flags[0] != target_id:
		errors.append("target flag and exit target disagree")

	if car_specs.has(target_id) and exit_axis in VALID_AXES:
		var target_spec: Dictionary = car_specs[target_id]
		var target_axis: Vector2i = target_spec.get("axis", Vector2i.ZERO)
		var target_pos: Vector2i = target_spec.get("pos", Vector2i.ZERO)
		if target_axis != exit_axis:
			errors.append("target car axis does not match exit axis")
		elif exit_axis == Vector2i(1, 0) and target_pos.y != exit_row:
			errors.append("target car is not aligned with exit row")
		elif exit_axis == Vector2i(0, 1) and target_pos.x != exit_row:
			errors.append("target car is not aligned with exit row")

	return errors

func _inside(cell: Vector2i, bounds: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < bounds.x and cell.y >= 0 and cell.y < bounds.y

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _to_vec2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-999999, -999999)
