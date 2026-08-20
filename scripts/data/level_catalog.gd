class_name ParkingPanicLevelCatalog
extends RefCounted

const INDEX_PATH := "res://data/levels/index.json"

var level_paths: Array[String] = []

func load_index(path: String = INDEX_PATH) -> bool:
	level_paths.clear()
	var data := _load_json(path)
	if data.is_empty():
		return false
	for value in data.get("levels", []):
		var level_path := str(value)
		if not level_path.is_empty():
			level_paths.append(level_path)
	return not level_paths.is_empty()

func size() -> int:
	return level_paths.size()

func load_level(index: int) -> Dictionary:
	if index < 0 or index >= level_paths.size():
		return {}
	return _load_json(level_paths[index])

func path_at(index: int) -> String:
	return "" if index < 0 or index >= level_paths.size() else level_paths[index]

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
