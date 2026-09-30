extends SceneTree

const BOUNDS := Vector2i(7, 7)
const DIRECTIONS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func _init() -> void:
	var failures := 0
	failures += _expect_all_edges_round_trip()
	failures += _expect_invalid_inputs()
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
		print("PASS all 24 directed cube edges, round trips, input guards and cross-face board transitions")
		quit(0)

func _expect_all_edges_round_trip() -> int:
	var failures := 0
	var length_cells := 2
	var seam_index := 2
	for face in CubeFaceTopology.FACES:
		for direction in DIRECTIONS:
			var axis := Vector2i(absi(direction.x), absi(direction.y))
			var pos := _edge_position(direction, length_cells, seam_index)
			var wrapped := CubeFaceTopology.wrap_pose(face, pos, axis, direction, length_cells, BOUNDS)
			if wrapped.is_empty():
				printerr("FAIL %s %s did not wrap" % [face, direction])
				failures += 1
				continue
			var returned := CubeFaceTopology.wrap_pose(
				str(wrapped["to_face"]),
				wrapped["pos"],
				wrapped["axis"],
				-wrapped["escape_dir"],
				length_cells,
				BOUNDS
			)
			if str(returned.get("to_face", "")) != face:
				printerr("FAIL %s %s round trip returned to %s" % [face, direction, returned.get("to_face", "")])
				failures += 1
			elif returned.get("pos", Vector2i(-1, -1)) != pos:
				printerr("FAIL %s %s round trip position %s != %s" % [face, direction, returned.get("pos"), pos])
				failures += 1
			elif returned.get("escape_dir", Vector2i.ZERO) != -direction:
				printerr("FAIL %s %s round trip direction %s" % [face, direction, returned.get("escape_dir")])
				failures += 1
	return failures

func _expect_invalid_inputs() -> int:
	var failures := 0
	var invalid_results := [
		CubeFaceTopology.wrap_pose("unknown", Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 0), 2, BOUNDS),
		CubeFaceTopology.wrap_pose("top", Vector2i.ZERO, Vector2i(1, 0), Vector2i.ZERO, 2, BOUNDS),
		CubeFaceTopology.wrap_pose("top", Vector2i.ZERO, Vector2i(0, 1), Vector2i(1, 0), 2, BOUNDS),
		CubeFaceTopology.wrap_pose("top", Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 0), 0, BOUNDS),
		CubeFaceTopology.wrap_pose("top", Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 0), 2, Vector2i.ZERO),
		CubeFaceTopology.wrap_pose("top", Vector2i(6, 0), Vector2i(1, 0), Vector2i(1, 0), 2, BOUNDS),
	]
	for result in invalid_results:
		if not result.is_empty():
			printerr("FAIL invalid topology input was accepted: %s" % result)
			failures += 1
	return failures

func _edge_position(direction: Vector2i, length_cells: int, seam_index: int) -> Vector2i:
	if direction.x != 0:
		return Vector2i(BOUNDS.x - length_cells if direction.x > 0 else 0, seam_index)
	return Vector2i(seam_index, BOUNDS.y - length_cells if direction.y > 0 else 0)

func _expect_wrap(face: String, pos: Vector2i, axis: Vector2i, direction: Vector2i, length_cells: int, expected_face: String, expected_pos: Vector2i, expected_direction: Vector2i) -> int:
	var wrapped := CubeFaceTopology.wrap_pose(face, pos, axis, direction, length_cells, BOUNDS)
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
