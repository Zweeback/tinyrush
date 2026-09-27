extends SceneTree

const ARROW_LEVELS := [
	"res://data/levels/arrow_city_01.json",
	"res://data/levels/arrow_city_02.json",
	"res://data/levels/arrow_city_03.json"
]

func _init() -> void:
	var failures := 0
	var legacy_validator := ArrowEscapeLevelValidator.new()

	for path in ARROW_LEVELS:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			printerr("FAIL missing %s" % path)
			failures += 1
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			printerr("FAIL invalid JSON %s" % path)
			failures += 1
			continue

		var level: Dictionary = parsed
		if str(level.get("mode", "")) == "cube_arrow":
			var cube_errors := _validate_cube(level)
			if not cube_errors.is_empty():
				printerr("FAIL %s cube_validation=%s" % [path, cube_errors])
				failures += 1
				continue
			print("PASS %s cube_faces=3 vehicles=%d" % [str(level.get("id", path)), level.get("cars", []).size()])
			continue

		var errors := legacy_validator.validate(level)
		if not errors.is_empty():
			printerr("FAIL %s validation=%s" % [path, errors])
			failures += 1
			continue

		var board := ArrowEscapeBoard.new()
		board.configure(level)
		var solver := ArrowEscapeSolver.new()
		var solved := solver.solve(board)
		if not bool(solved.get("solved", false)):
			printerr("FAIL %s unsolved" % path)
			failures += 1
			continue

		var expected := int(level.get("optimal_moves", -1))
		var actual := int(solved.get("moves", -1))
		if actual != expected:
			printerr("FAIL %s expected=%d actual=%d" % [path, expected, actual])
			failures += 1
			continue
		print("PASS %s vehicles=%d states=%d" % [str(level.get("id", path)), board.car_ids().size(), int(solved.get("states_visited", 0))])

	if failures > 0:
		quit(1)
	else:
		print("PASS all arrow variants")
		quit(0)

func _validate_cube(level: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var bounds_value: Variant = level.get("bounds", [0, 0])
	if not bounds_value is Array or bounds_value.size() < 2:
		return ["missing bounds"]
	var bounds := Vector2i(int(bounds_value[0]), int(bounds_value[1]))
	var valid_faces := ["top", "front", "right", "back", "left"]
	var occupied := {}
	var ids := {}
	var faces := {}
	var target_count := 0

	for raw in level.get("cars", []):
		if not raw is Dictionary:
			errors.append("car entry must be an object")
			continue
		var car: Dictionary = raw
		var car_id := str(car.get("id", ""))
		var face := str(car.get("face", "top")).to_lower()
		var pos_value: Variant = car.get("pos", [0, 0])
		var axis_value: Variant = car.get("axis", [1, 0])
		var dir_value: Variant = car.get("escape_dir", [1, 0])
		var pos := Vector2i(int(pos_value[0]), int(pos_value[1]))
		var axis := Vector2i(int(axis_value[0]), int(axis_value[1]))
		var direction := Vector2i(int(dir_value[0]), int(dir_value[1]))
		var length_cells := int(car.get("len", 2))

		if car_id.is_empty() or ids.has(car_id):
			errors.append("duplicate or empty car id")
			continue
		ids[car_id] = true
		faces[face] = true
		if face not in valid_faces:
			errors.append("%s invalid face" % car_id)
		if axis not in [Vector2i(1, 0), Vector2i(0, 1)]:
			errors.append("%s invalid axis" % car_id)
		if direction != axis and direction != -axis:
			errors.append("%s arrow must follow its axis" % car_id)
		if bool(car.get("target", false)):
			target_count += 1

		for i in range(length_cells):
			var cell := pos + axis * i
			if cell.x < 0 or cell.x >= bounds.x or cell.y < 0 or cell.y >= bounds.y:
				errors.append("%s out of face bounds" % car_id)
				continue
			var key := "%s:%d:%d" % [face, cell.x, cell.y]
			if occupied.has(key):
				errors.append("%s overlaps %s" % [car_id, occupied[key]])
			else:
				occupied[key] = car_id

	if target_count != 1:
		errors.append("cube arrow level requires exactly one hero")
	if not faces.has("top") or not faces.has("front") or not faces.has("right"):
		errors.append("cube arrow level must populate top, front and right faces")
	var optimal_path: Variant = level.get("optimal_path", [])
	if not optimal_path is Array or optimal_path.size() != ids.size():
		errors.append("optimal_path must contain every cube vehicle exactly once")
	return errors
