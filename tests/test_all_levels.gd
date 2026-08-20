extends SceneTree

func _init() -> void:
	var catalog := ParkingPanicLevelCatalog.new()
	var validator := ParkingPanicLevelValidator.new()
	if not catalog.load_index():
		printerr("FAIL: cannot load level index")
		quit(1)
		return

	var failures := 0
	for i in range(catalog.size()):
		var level := catalog.load_level(i)
		var level_id := str(level.get("id", "?"))
		var validation := validator.validate(level)
		if not validation.is_empty():
			printerr("FAIL: %s validation=%s" % [level_id, validation])
			failures += 1
			continue

		var board := ParkingBoard.new()
		board.configure(level)
		var solver := ParkingPanicSolver.new()
		var result := solver.solve(board)
		var expected := int(level.get("optimal_moves", -1))
		var actual := int(result.get("moves", -1))
		if not bool(result.get("solved", false)) or actual != expected:
			printerr("FAIL: %s expected=%d actual=%d" % [level_id, expected, actual])
			failures += 1
			continue

		var replay_board := ParkingBoard.new()
		replay_board.configure(level)
		var declared_path: Array = level.get("optimal_path", [])
		var replay_ok := declared_path.size() == expected
		var exited := false
		for step_index in range(declared_path.size()):
			var step: Dictionary = declared_path[step_index]
			var move := replay_board.apply_move(str(step.get("id", "")), int(step.get("sign", 0)))
			if not bool(move.get("ok", false)):
				replay_ok = false
				break
			if bool(move.get("exit", false)):
				exited = true
				if step_index != declared_path.size() - 1:
					replay_ok = false
				break
		if not exited:
			replay_ok = false
		if not replay_ok:
			printerr("FAIL: %s declared optimal_path does not replay" % level_id)
			failures += 1
			continue

		print("PASS: %s optimal=%d states=%d peak_queue=%d" % [level_id, actual, int(result.get("states_visited", 0)), int(result.get("peak_queue", 0))])

	if failures > 0:
		quit(1)
	else:
		print("PASS: all %d levels validated, solved and replayed" % catalog.size())
		quit(0)
