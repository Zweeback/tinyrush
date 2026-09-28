extends SceneTree

func _init() -> void:
	var failures := 0
	failures += _expect_wrap("top", Vector2i(2, 3), Vector2i(1, 0), Vector2i(1, 0), 2, "right", Vector2i(3, 0), Vector2i(0, 1))
	failures += _expect_wrap("top", Vector2i(4, 2), Vector2i(0, 1), Vector2i(0, 1), 3, "front", Vector2i(4, 0), Vector2i(0, 1))
	failures += _expect_wrap("front", Vector2i(1, 2), Vector2i(1, 0), Vector2i(1, 0), 3, "right", Vector2i(0, 2), Vector2i(1, 0))
	failures += _expect_wrap("front", Vector2i(3, 0), Vector2i(0, 1), Vector2i(0, -1), 2, "top", Vector2i(3, 5), Vector2i(0, -1))

	var file := FileAccess.open("res://data/levels/arrow_city_01.json", FileAccess.READ)
	var level: Dictionary = JSON.parse_string(file.get_as_text())
	var board := ArrowEscapeBoard.new()
	board.configure(level)
	board.active["top_blue"] = false
	var first := board.apply_move("top_red", 1)
	if not bool(first.get("transition", false)) or str(first.get("to_face", "")) != "right":
		printerr("FAIL top_red did not wrap to right")
		failures += 1
	elif board.get_car("top_red").grid_pos != Vector2i(3, 0):
		printerr("FAIL top_red wrapped to wrong cell")
		failures += 1
	elif board.can_escape("top_red"):
		printerr("FAIL wrapped top_red should be blocked by right_blue")
		failures += 1
	else:
		board.active["right_blue"] = false
		if not board.can_escape("top_red"):
			printerr("FAIL top_red route should open after right_blue exits")
			failures += 1

	if failures > 0:
		quit(1)
	else:
		print("PASS cube topology and cross-face board transitions")
		quit(0)

func _expect_wrap(face: String, pos: Vector2i, axis: Vector2i, direction: Vector2i, length_cells: int, expected_face: String, expected_pos: Vector2i, expected_direction: Vector2i) -> int:
	var wrapped := CubeFaceTopology.wrap_pose(face, pos, axis, direction, length_cells, Vector2i(7, 7))
	if str(wrapped.get("to_face", "")) != expected_face:
		printerr("FAIL %s expected face %s got %s" % [face, expected_face, wrapped.get("to_face", "")])
		return 1
	if wrapped.get("pos", Vector2i(-1, -1)) != expected_pos:
		printerr("FAIL %s expected pos %s got %s" % [face, expected_pos, wrapped.get("pos", Vector2i(-1, -1))])
		return 1
	if wrapped.get("escape_dir", Vector2i.ZERO) != expected_direction:
		printerr("FAIL %s expected dir %s got %s" % [face, expected_direction, wrapped.get("escape_dir", Vector2i.ZERO)])
		return 1
	return 0
