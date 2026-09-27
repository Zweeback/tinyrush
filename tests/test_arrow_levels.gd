extends SceneTree

const ARROW_LEVELS := [
	"res://data/levels/arrow_city_01.json",
	"res://data/levels/arrow_city_02.json",
	"res://data/levels/arrow_city_03.json"
]

func _init() -> void:
	var failures := 0
	var validator := ArrowEscapeLevelValidator.new()

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
		var errors := validator.validate(level)
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

		print("PASS %s vehicles=%d states=%d" % [
			str(level.get("id", path)),
			board.car_ids().size(),
			int(solved.get("states_visited", 0))
		])

	if failures > 0:
		quit(1)
	else:
		print("PASS all arrow-run levels")
		quit(0)
