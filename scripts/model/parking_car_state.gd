class_name ParkingCarState
extends RefCounted

var car_id := ""
var grid_pos := Vector2i.ZERO
var axis := Vector2i(1, 0)
var length_cells := 2
var is_target := false
var color := Color(0.2, 0.65, 1.0, 1.0)

static func from_dictionary(data: Dictionary) -> ParkingCarState:
	var car := ParkingCarState.new()
	car.car_id = str(data.get("id", "car"))
	car.grid_pos = _vec2i(data.get("pos", [0, 0]))
	car.axis = _vec2i(data.get("axis", [1, 0]))
	car.length_cells = int(data.get("len", 2))
	car.is_target = bool(data.get("target", false))
	car.color = _color(data.get("color", [0.2, 0.65, 1.0, 1.0]))
	return car

func occupied_cells(at_pos: Variant = null) -> Array[Vector2i]:
	var origin := grid_pos
	if at_pos is Vector2i:
		origin = at_pos
	var result: Array[Vector2i] = []
	for i in range(length_cells):
		result.append(origin + axis * i)
	return result

func to_view_spec() -> Dictionary:
	return {
		"id": car_id,
		"axis": axis,
		"len": length_cells,
		"target": is_target,
		"color": [color.r, color.g, color.b, color.a]
	}

static func _vec2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO

static func _color(value: Variant) -> Color:
	if value is Array and value.size() >= 4:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	return Color(0.2, 0.65, 1.0, 1.0)
