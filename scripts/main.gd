extends Node3D

const CAR_SCENE := preload("res://scenes/tiny_car.tscn")
const ARROW_LEVEL_PATH := "res://data/levels/arrow_city_01.json"

@export var cell_size := 1.02

var catalog := ParkingPanicLevelCatalog.new()
var level_validator := ParkingPanicLevelValidator.new()
var arrow_validator := ArrowEscapeLevelValidator.new()
var level: Dictionary = {}
var level_cursor := 0
var game_mode := "arrow_escape"
var board: Variant = ParkingBoard.new()
var car_views: Dictionary = {}
var history: Array[Dictionary] = []
var board_offset := Vector3.ZERO
var moves := 0
var is_busy := false
var optimal_moves := -1
var selected_car_id := ""
var auto_path: Array = []
var level_cleared := false
var combo := 0
var best_combo := 0

@onready var world_builder: ParkingPanicWorld = $WorldRoot/BoardRoot
@onready var cars_root: Node3D = $WorldRoot/CarsRoot
@onready var fx_root: Node3D = $WorldRoot/FXRoot
@onready var orbit_rig: Node3D = $OrbitRig
@onready var camera: Camera3D = $OrbitRig/Camera3D
@onready var input_controller: ParkingPanicInputController = $InputController
@onready var audio: ParkingPanicAudio = $AudioManager
@onready var fx: ParkingPanicFX = $FXManager
@onready var title_label: Label = $UI/Top/Title
@onready var move_label: Label = $UI/Top/Moves
@onready var optimal_label: Label = $UI/Top/Optimal
@onready var status_label: Label = $UI/Status
@onready var undo_button: Button = $UI/Top/Undo
@onready var restart_button: Button = $UI/Top/Restart
@onready var auto_button: Button = $UI/Top/Auto
@onready var hint_label: Label = $UI/Hint
@onready var selected_label: Label = $UI/Controls/Selected
@onready var backward_button: Button = $UI/Controls/Backward
@onready var forward_button: Button = $UI/Controls/Forward
@onready var self_test_label: Label = $UI/SelfTest
@onready var world_name_label: Label = $UI/WorldName
@onready var progress_label: Label = $UI/Progress
@onready var next_button: Button = $UI/Next

func _ready() -> void:
	if not catalog.load_index():
		_fail_boot("LEVEL INDEX ERROR")
		return
	input_controller.configure(camera, orbit_rig)
	input_controller.move_requested.connect(_on_move_requested)
	input_controller.car_selected.connect(_select_car)
	fx.configure(fx_root, orbit_rig)
	restart_button.pressed.connect(restart_level)
	undo_button.pressed.connect(undo_move)
	auto_button.pressed.connect(_start_auto_solve)
	backward_button.pressed.connect(_move_selected.bind(-1))
	forward_button.pressed.connect(_move_selected.bind(1))
	next_button.pressed.connect(next_level)
	_load_arrow_level()

func _load_arrow_level() -> void:
	var file := FileAccess.open(ARROW_LEVEL_PATH, FileAccess.READ)
	if file == null:
		_fail_boot("ARROW LEVEL LOAD ERROR")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail_boot("ARROW LEVEL JSON ERROR")
		return
	level = parsed
	game_mode = "arrow_escape"
	level_cursor = 0

	var validation := arrow_validator.validate(level)
	if not validation.is_empty():
		_fail_boot("ARROW LEVEL INVALID: %s" % validation[0])
		return

	board = ArrowEscapeBoard.new()
	board.configure(level)
	var solver := ArrowEscapeSolver.new()
	var solved := solver.solve(board)
	if not bool(solved.get("solved", false)):
		_fail_boot("ARROW LEVEL UNSOLVABLE")
		return

	optimal_moves = int(solved.get("moves", -1))
	var declared_optimal := int(level.get("optimal_moves", -1))
	if declared_optimal >= 0 and declared_optimal != optimal_moves:
		_fail_boot("ARROW OPTIMAL MISMATCH: DATA %d / SOLVER %d" % [declared_optimal, optimal_moves])
		return
	auto_path = solved.get("path", []).duplicate(true)
	board_offset = _calculate_board_offset()
	world_builder.build(level, cell_size)
	_update_level_labels()
	self_test_label.text = "ARROW LOGIC · SOLVER OK · %d VEHICLES · %d DEPENDENCIES" % [board.car_ids().size(), int(solved.get("states_visited", 0))]
	restart_level()

func _load_level_at(index: int) -> void:
	if catalog.size() == 0:
		_fail_boot("NO LEVELS")
		return
	game_mode = "rush_hour"
	level_cursor = posmod(index, catalog.size())
	level = catalog.load_level(level_cursor)
	if level.is_empty():
		_fail_boot("LEVEL LOAD ERROR")
		return
	var validation := level_validator.validate(level)
	if not validation.is_empty():
		_fail_boot("LEVEL INVALID: %s" % validation[0])
		return

	board = ParkingBoard.new()
	board.configure(level)
	var solver := ParkingPanicSolver.new()
	var solved := solver.solve(board)
	if not bool(solved.get("solved", false)):
		_fail_boot("LEVEL UNSOLVABLE")
		return
	optimal_moves = int(solved.get("moves", -1))
	var declared_optimal := int(level.get("optimal_moves", -1))
	if declared_optimal >= 0 and declared_optimal != optimal_moves:
		_fail_boot("OPTIMAL MISMATCH: DATA %d / SOLVER %d" % [declared_optimal, optimal_moves])
		return
	auto_path = solved.get("path", []).duplicate(true)
	board_offset = _calculate_board_offset()
	world_builder.build(level, cell_size)
	_update_level_labels()
	self_test_label.text = "SELF TEST · DATA + SOLVER OK · %d CARS · OPT %d" % [board.car_ids().size(), optimal_moves]
	restart_level()

func next_level() -> void:
	if is_busy:
		return
	if game_mode == "arrow_escape":
		restart_level()
	else:
		_load_level_at(level_cursor + 1)

func restart_level() -> void:
	is_busy = false
	level_cleared = false
	moves = 0
	combo = 0
	history.clear()
	selected_car_id = ""
	board.reset_from_level(level)

	for child in cars_root.get_children():
		child.free()
	car_views.clear()

	for car_id_value in board.car_ids():
		var car_id := str(car_id_value)
		var view: ParkingPanicCarView = CAR_SCENE.instantiate()
		cars_root.add_child(view)
		view.configure(board.get_spec(car_id), cell_size)
		view.position = _world_position(car_id)
		car_views[car_id] = view

	if game_mode == "arrow_escape":
		status_label.text = "CLEAR ALL TRAFFIC"
		hint_label.text = "Tap a vehicle · cyan arrow = open route · orange arrow = blocked"
	else:
		status_label.text = "FREE THE RED CAR"
		hint_label.text = "Tap an end to move · tap center + ◀ ▶ as fallback · drag anywhere to orbit"

	input_controller.set_enabled(true)
	input_controller.reset_camera()
	next_button.visible = false
	_refresh_move_hints()
	_update_ui()

func undo_move() -> void:
	if is_busy or level_cleared or history.is_empty():
		return
	var step: Dictionary = history.pop_back()
	var car_id := str(step.get("id", ""))

	if game_mode == "arrow_escape":
		board.restore_car(car_id)
		moves = maxi(0, moves - 1)
		var arrow_view: ParkingPanicCarView = car_views.get(car_id)
		if arrow_view != null:
			arrow_view.visible = true
			arrow_view.busy = false
			arrow_view.scale = Vector3.ONE
			arrow_view.position = _world_position(car_id)
		_select_car_force(car_id)
		audio.undo_sound()
		_refresh_move_hints()
		_update_ui()
		return

	var previous_position: Vector2i = step.get("from", Vector2i.ZERO)
	board.set_position(car_id, previous_position)
	moves = maxi(0, moves - 1)
	_select_car(car_id)
	var view: ParkingPanicCarView = car_views.get(car_id)
	is_busy = true
	if view != null:
		view.visible = true
		view.animate_to(_world_position(car_id), 0.12)
	audio.undo_sound()
	_update_ui()
	await get_tree().create_timer(0.13).timeout
	is_busy = false
	_refresh_move_hints()
	_update_ui()

func _move_selected(sign: int) -> void:
	if game_mode == "arrow_escape":
		if selected_car_id.is_empty():
			status_label.text = "TAP A VEHICLE"
			_reset_status_later()
			return
		_on_arrow_tap(selected_car_id)
		return
	if selected_car_id.is_empty():
		status_label.text = "TAP A CAR FIRST"
		_reset_status_later()
		return
	_on_move_requested(selected_car_id, sign)

func _select_car(car_id: String) -> void:
	if is_busy or level_cleared or not car_views.has(car_id):
		return
	if game_mode == "arrow_escape":
		_on_arrow_tap(car_id)
		return
	_select_car_force(car_id)
	status_label.text = "%s SELECTED" % selected_car_id.to_upper()
	_refresh_move_hints()
	_update_ui()

func _on_move_requested(car_id: String, sign: int) -> void:
	if is_busy or level_cleared:
		return
	if game_mode == "arrow_escape":
		_on_arrow_tap(car_id)
		return

	_select_car_force(car_id)
	var view: ParkingPanicCarView = car_views.get(car_id)
	if view == null or view.busy:
		return
	var result: Dictionary = board.apply_move(car_id, sign)
	if not bool(result.get("ok", false)):
		view.blocked_feedback(sign)
		fx.burst(view.position + Vector3.UP * 0.35, Color(1.0, 0.22, 0.28, 1), 5, 0.26)
		audio.blocked_sound()
		Input.vibrate_handheld(16)
		status_label.text = "BLOCKED!"
		_reset_status_later()
		return
	if bool(result.get("exit", false)):
		_complete_level(view, sign)
		return

	history.append({"id": car_id, "from": result.get("from", Vector2i.ZERO)})
	moves += 1
	is_busy = true
	_refresh_move_hints()
	view.animate_to(_world_position(car_id), 0.14)
	fx.burst(view.position + Vector3.UP * 0.30, view.body_color, 7, 0.34)
	fx.camera_kick()
	audio.move_sound(moves)
	Input.vibrate_handheld(8)
	_update_ui()
	await get_tree().create_timer(0.15).timeout
	is_busy = false
	_refresh_move_hints()
	_update_ui()

func _on_arrow_tap(car_id: String) -> void:
	if is_busy or level_cleared or not board.is_active(car_id):
		return
	var view: ParkingPanicCarView = car_views.get(car_id)
	if view == null or view.busy:
		return

	_select_car_force(car_id)
	var spec: Dictionary = board.get_spec(car_id)
	var axis: Vector2i = spec.get("axis", Vector2i(1, 0))
	var escape_dir: Vector2i = spec.get("escape_dir", axis)
	var local_sign := 1 if escape_dir == axis else -1
	var result: Dictionary = board.apply_move(car_id, 1)

	if not bool(result.get("ok", false)):
		combo = 0
		view.blocked_feedback(local_sign)
		fx.burst(view.position + Vector3.UP * 0.42, Color(1.0, 0.28, 0.12, 1), 7, 0.30)
		audio.blocked_sound()
		Input.vibrate_handheld(18)
		status_label.text = "%s BLOCKED" % car_id.to_upper()
		_refresh_move_hints()
		_reset_status_later()
		return

	history.append({"id": car_id, "arrow_escape": true})
	moves += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	is_busy = true
	view.set_move_hints(false, false)
	var world_direction := Vector3(float(escape_dir.x), 0, float(escape_dir.y))
	var burst_count := mini(22, 9 + combo * 2)
	fx.burst(view.position + Vector3.UP * 0.34, view.body_color, burst_count, 0.42 + minf(0.35, float(combo) * 0.035))
	fx.speed_trail(view.position + Vector3.UP * 0.30, world_direction, view.body_color, combo)
	fx.camera_kick()
	audio.move_sound(moves)
	Input.vibrate_handheld(7 + mini(18, combo * 2))
	var exit_duration := maxf(0.14, 0.31 - float(combo - 1) * 0.018)
	view.animate_exit(world_direction, cell_size * 10.5, exit_duration)
	status_label.text = "COMBO x%d · %s OUT · %d LEFT" % [combo, car_id.to_upper(), board.remaining_count()]
	_update_ui()

	await get_tree().create_timer(0.50).timeout
	is_busy = false
	if board.remaining_count() == 0:
		_complete_arrow_level()
		return
	selected_car_id = ""
	_refresh_move_hints()
	_update_ui()

func _complete_arrow_level() -> void:
	level_cleared = true
	input_controller.set_enabled(false)
	selected_car_id = ""
	status_label.text = "RUN CLEARED · COMBO x%d!" % best_combo
	hint_label.text = "FAST CLEAR · %d VEHICLES · KEEP THE FLOW" % moves
	fx.burst(Vector3.ZERO + Vector3.UP * 0.8, Color(0.24, 0.95, 1.0, 1), 34, 1.25)
	Input.vibrate_handheld(42)
	audio.play_win_chime()
	next_button.visible = true
	next_button.text = "REPLAY JAM ▶"
	_update_ui()

func _complete_level(hero: ParkingPanicCarView, sign: int) -> void:
	is_busy = true
	level_cleared = true
	input_controller.set_enabled(false)
	moves += 1
	for id_value in car_views.keys():
		var id := str(id_value)
		var parked_view: ParkingPanicCarView = car_views[id]
		parked_view.set_move_hints(false, false)
	_update_ui()
	status_label.text = "%s CLEARED!" % str(level.get("world", "WORLD"))
	hint_label.text = "PERFECT CLEAR" if moves == optimal_moves else "CLEAR · OPTIMAL IS %d" % optimal_moves
	fx.burst(hero.position + Vector3.UP * 0.4, Color(1.0, 0.78, 0.18, 1), 28, 1.15)
	fx.burst(hero.position + Vector3.UP * 0.4, hero.body_color, 18, 0.82)
	var axis: Vector2i = board.get_spec(board.target_id).get("axis", Vector2i(1, 0))
	var world_direction := Vector3(float(axis.x * sign), 0, float(axis.y * sign))
	hero.animate_exit(world_direction, cell_size * 7.0)
	Input.vibrate_handheld(42)
	audio.play_win_chime()
	await get_tree().create_timer(0.9).timeout
	is_busy = false
	next_button.visible = true
	next_button.text = "NEXT WORLD ▶" if level_cursor + 1 < catalog.size() else "PLAY AGAIN ▶"
	_update_ui()

func _start_auto_solve() -> void:
	if is_busy:
		return
	if game_mode == "arrow_escape":
		await _auto_solve_arrow()
		return

	restart_level()
	is_busy = true
	status_label.text = "AUTO SOLVE · %d MOVES" % optimal_moves
	input_controller.set_enabled(false)
	for step_value in auto_path:
		var step: Dictionary = step_value
		var car_id := str(step.get("id", ""))
		var sign := int(step.get("sign", 1))
		_select_car_force(car_id)
		var view: ParkingPanicCarView = car_views.get(car_id)
		var result: Dictionary = board.apply_move(car_id, sign)
		if not bool(result.get("ok", false)):
			_fail_auto("AUTO PATH FAILED")
			return
		if bool(result.get("exit", false)):
			is_busy = false
			_complete_level(view, sign)
			return
		moves += 1
		_refresh_move_hints()
		view.animate_to(_world_position(car_id), 0.18)
		fx.burst(view.position + Vector3.UP * 0.30, view.body_color, 6, 0.30)
		audio.move_sound(moves)
		_update_ui()
		await get_tree().create_timer(0.28).timeout
	_fail_auto("AUTO PATH DID NOT EXIT")

func _auto_solve_arrow() -> void:
	restart_level()
	is_busy = true
	input_controller.set_enabled(false)
	status_label.text = "AUTO CLEAR · %d VEHICLES" % optimal_moves
	for step_value in auto_path:
		var step: Dictionary = step_value
		var car_id := str(step.get("id", ""))
		var view: ParkingPanicCarView = car_views.get(car_id)
		if view == null:
			_fail_auto("ARROW AUTO VIEW MISSING")
			return
		var spec: Dictionary = board.get_spec(car_id)
		var escape_dir: Vector2i = spec.get("escape_dir", Vector2i(1, 0))
		var result: Dictionary = board.apply_move(car_id, 1)
		if not bool(result.get("ok", false)):
			_fail_auto("ARROW AUTO PATH FAILED")
			return
		moves += 1
		combo += 1
		best_combo = maxi(best_combo, combo)
		view.set_move_hints(false, false)
		var auto_direction := Vector3(float(escape_dir.x), 0, float(escape_dir.y))
		fx.speed_trail(view.position + Vector3.UP * 0.30, auto_direction, view.body_color, combo)
		var exit_duration := maxf(0.14, 0.29 - float(combo - 1) * 0.016)
		view.animate_exit(auto_direction, cell_size * 10.5, exit_duration)
		audio.move_sound(moves)
		_update_ui()
		await get_tree().create_timer(0.34).timeout
	is_busy = false
	_complete_arrow_level()

func _select_car_force(car_id: String) -> void:
	selected_car_id = car_id
	for id_value in car_views.keys():
		var id := str(id_value)
		var view: ParkingPanicCarView = car_views[id]
		view.set_selected(id == selected_car_id)
	_update_ui()

func _fail_auto(message: String) -> void:
	is_busy = false
	level_cleared = false
	input_controller.set_enabled(true)
	status_label.text = message
	self_test_label.text = "SELF TEST · FAIL"
	_update_ui()

func _fail_boot(message: String) -> void:
	status_label.text = message
	hint_label.text = "Project started, but startup validation failed."
	self_test_label.text = "SELF TEST · FAIL"
	push_error("TinyRush: %s" % message)

func _world_position(car_id: String) -> Vector3:
	var spec: Dictionary = board.get_spec(car_id)
	var pos: Vector2i = board.get_position(car_id)
	var axis: Vector2i = spec.get("axis", Vector2i(1, 0))
	var length_cells := int(spec.get("len", 2))
	var center_x := float(pos.x) * cell_size + float(axis.x) * float(length_cells - 1) * cell_size * 0.5
	var center_z := float(pos.y) * cell_size + float(axis.y) * float(length_cells - 1) * cell_size * 0.5
	return board_offset + Vector3(center_x, 0.14, center_z)

func _calculate_board_offset() -> Vector3:
	return Vector3(-float(board.bounds.x - 1) * cell_size * 0.5, 0.0, -float(board.bounds.y - 1) * cell_size * 0.5)

func _reset_status_later() -> void:
	await get_tree().create_timer(0.35).timeout
	if not is_busy and not level_cleared:
		if game_mode == "arrow_escape":
			status_label.text = "CLEAR ALL TRAFFIC · %d LEFT" % board.remaining_count()
		else:
			status_label.text = "FREE THE RED CAR" if selected_car_id.is_empty() else "%s SELECTED" % selected_car_id.to_upper()

func _update_level_labels() -> void:
	var world := str(level.get("world", "WORLD"))
	var title := str(level.get("title", "TRAFFIC JAM"))
	title_label.text = "TINY RUSH · %s" % world
	if game_mode == "arrow_escape":
		world_name_label.text = "ARROW MODE · %s" % title
		progress_label.text = "%d VEHICLES" % board.car_ids().size()
	else:
		world_name_label.text = "WORLD %02d · %s · %s" % [level_cursor + 1, world, title]
		progress_label.text = "%d / %d" % [level_cursor + 1, catalog.size()]

func _refresh_move_hints() -> void:
	for id_value in car_views.keys():
		var id := str(id_value)
		var view: ParkingPanicCarView = car_views[id]
		if game_mode == "arrow_escape":
			if level_cleared or not board.is_active(id):
				view.set_move_hints(false, false)
			else:
				view.set_arrow_escape_state(board.can_escape(id))
			continue
		var can_backward := false
		var can_forward := false
		if not level_cleared:
			can_backward = board.can_move(id, -1)
			can_forward = board.can_move(id, 1)
		view.set_move_hints(can_backward, can_forward)

func _update_ui() -> void:
	move_label.text = "MOVES %02d" % moves
	optimal_label.text = "CLEAR %02d" % optimal_moves if game_mode == "arrow_escape" else ("OPT %02d" % optimal_moves if optimal_moves >= 0 else "OPT --")
	undo_button.disabled = history.is_empty() or is_busy or level_cleared
	auto_button.disabled = is_busy
	restart_button.disabled = is_busy

	if game_mode == "arrow_escape":
		var open_routes := 0
		if not level_cleared:
			for id_value in board.car_ids():
				var id := str(id_value)
				if board.is_active(id) and board.can_escape(id):
					open_routes += 1
		selected_label.text = "FLOW x%d · OPEN %d · LEFT %d" % [combo, open_routes, board.remaining_count()]
		backward_button.visible = false
		forward_button.visible = false
	else:
		selected_label.text = "SELECTED: NONE" if selected_car_id.is_empty() else "SELECTED: %s" % selected_car_id.to_upper()
		backward_button.visible = true
		forward_button.visible = true
		var no_selection := selected_car_id.is_empty()
		backward_button.disabled = no_selection or is_busy or level_cleared or not board.can_move(selected_car_id, -1)
		forward_button.disabled = no_selection or is_busy or level_cleared or not board.can_move(selected_car_id, 1)
