extends SceneTree

func _init() -> void:
	var catalog := ParkingPanicLevelCatalog.new()
	if not catalog.load_index():
		printerr("FAIL: cannot load level index")
		quit(1)
		return
	var level := catalog.load_level(0)
	var board := ParkingBoard.new()
	board.configure(level)

	if bool(board.apply_move("hero", 0).get("ok", true)):
		printerr("FAIL: invalid sign was accepted")
		quit(1)
		return

	var path: Array = level.get("optimal_path", [])
	var exited := false
	for i in range(path.size()):
		var step: Dictionary = path[i]
		var result := board.apply_move(str(step.get("id", "")), int(step.get("sign", 0)))
		if not bool(result.get("ok", false)):
			printerr("FAIL: optimal path blocked at step %d" % [i + 1])
			quit(1)
			return
		if bool(result.get("exit", false)):
			exited = true
			if i != path.size() - 1:
				printerr("FAIL: optimal path exits early")
				quit(1)
				return

	if not exited:
		printerr("FAIL: optimal path never exits")
		quit(1)
		return

	var tap_board := ParkingBoard.new()
	tap_board.configure(level)
	var first_slide: Dictionary = tap_board.apply_slide("blue", -1)
	if not bool(first_slide.get("ok", false)) or int(first_slide.get("cell_steps", 0)) != 1:
		printerr("FAIL: blue maximal slide did not stop at expected blocker")
		quit(1)
		return
	var second_slide: Dictionary = tap_board.apply_slide("yellow", 1)
	if not bool(second_slide.get("ok", false)) or int(second_slide.get("cell_steps", 0)) != 3:
		printerr("FAIL: yellow maximal slide did not travel three cells")
		quit(1)
		return
	var exit_slide: Dictionary = tap_board.apply_slide("hero", 1)
	if not bool(exit_slide.get("ok", false)) or not bool(exit_slide.get("exit", false)):
		printerr("FAIL: hero maximal slide did not exit")
		quit(1)
		return

	print("PASS: board rules replay classic path and 3-tap hybrid path")
	quit(0)
