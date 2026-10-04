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

	var cell_result: Dictionary = solver.solve(board)
	if not bool(cell_result.get("solved", false)) or int(cell_result.get("moves", -1)) != 9:
		printerr("FAIL: paris cell solver expected 9, got %s" % cell_result.get("moves", -1))
		quit(1)
		return

	var tap_result: Dictionary = solver.solve_slides(board)
	print(JSON.stringify(tap_result))
	if not bool(tap_result.get("solved", false)):
		printerr("FAIL: tap solver found no solution")
		quit(1)
		return
	if int(tap_result.get("moves", -1)) != 3:
		printerr("FAIL: expected 3 optimal taps, got %s" % tap_result.get("moves", -1))
		quit(1)
		return

	print("PASS: paris_01 = 9 classic cell moves / 3 Arrows-style taps")
	quit(0)
