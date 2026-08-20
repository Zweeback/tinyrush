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

	print("PASS: board rules replay paris optimal path")
	quit(0)
