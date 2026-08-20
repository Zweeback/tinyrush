extends SceneTree

func _init() -> void:
	var path := "res://data/levels/paris_01.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("FAIL: cannot open level")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		printerr("FAIL: invalid level JSON")
		quit(1)
		return
	var board := ParkingBoard.new()
	board.configure(parsed)
	var solver := ParkingPanicSolver.new()
	var result := solver.solve(board)
	print(JSON.stringify(result))
	if not bool(result.get("solved", false)):
		printerr("FAIL: solver found no solution")
		quit(1)
		return
	if int(result.get("moves", -1)) != 9:
		printerr("FAIL: expected 9 optimal cell moves, got %s" % result.get("moves", -1))
		quit(1)
		return
	print("PASS: paris_01 optimal solution = 9 cell moves")
	quit(0)
