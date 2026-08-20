extends SceneTree

func _init() -> void:
	var catalog := ParkingPanicLevelCatalog.new()
	var validator := ParkingPanicLevelValidator.new()
	if not catalog.load_index():
		printerr("FAIL: cannot load level index")
		quit(1)
		return

	for i in range(catalog.size()):
		var level := catalog.load_level(i)
		var errors := validator.validate(level)
		if not errors.is_empty():
			printerr("FAIL: valid level rejected: %s => %s" % [level.get("id", "?"), errors])
			quit(1)
			return

	var broken := catalog.load_level(0).duplicate(true)
	broken["cars"][0]["axis"] = [1, 1]
	var broken_errors := validator.validate(broken)
	if broken_errors.is_empty():
		printerr("FAIL: validator accepted invalid car axis")
		quit(1)
		return

	print("PASS: level validator accepts catalog and rejects malformed axis")
	quit(0)
