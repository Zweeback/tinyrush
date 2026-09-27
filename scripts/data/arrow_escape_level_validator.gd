class_name ArrowEscapeLevelValidator
extends RefCounted

const VALID_AXES := [Vector2i(1, 0), Vector2i(0, 1)]

func validate(level: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var bounds := _to_vec2i(level.get("bounds", []))
	if bounds.x <= 0 or bounds.y <= 0:
		return ["bounds must be two positive integers"]

	var occupied := {}
	var ids := {}
	var target_count := 0
	for raw_car in level.get("cars", []):
		if not raw_car is Dictionary:
			errors.append("car entry must be an object")
			continue
		var car: Dictionary = raw_car
		var car_id := str(car.get("id", "")).strip_edges()
		if car_id.is_empty() or ids.has(car_id):
			errors.append("car ids must be unique and non-empty")
			continue
		ids[car_id] = true
		var pos := _to_vec2i(car.get("pos", []))
		var axis := _to_vec2i(car.get("axis", []))
		var escape_dir := _to_vec2i(car.get("escape_dir", []))
		var length_cells := int(car.get("len", 0))
		if axis not in VALID_AXES:
			errors.append("%s has invalid axis" % car_id)
		if escape_dir != axis and escape_dir != -axis:
			errors.append("%s escape_dir must follow its vehicle axis" % car_id)
		if length_cells < 1:
			errors.append("%s length must be at least 1" % car_id)
		if bool(car.get("target", false)):
			target_count += 1
		if axis in VALID_AXES and length_cells > 0:
			for i in range(length_cells):
				var cell := pos + axis * i
				if not _inside(cell, bounds):
					errors.append("%s is out of bounds at %s" % [car_id, cell])
				var key := "%d,%d" % [cell.x, cell.y]
				if occupied.has(key):
					errors.append("%s overlaps %s at %s" % [car_id, occupied[key], key])
				else:
					occupied[key] = car_id

	if ids.is_empty():
		errors.append("level has no cars")
	if target_count != 1:
		errors.append("arrow level needs exactly one red target car")
	return errors

func _inside(cell: Vector2i, bounds: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < bounds.x and cell.y >= 0 and cell.y < bounds.y

func _to_vec2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-999999, -999999)
