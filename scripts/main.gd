extends Node3D

const CAR_SCENE := preload("res://scenes/tiny_car.tscn")

@export var cell_size := 1.02

var catalog := ParkingPanicLevelCatalog.new()
var level_validator := ParkingPanicLevelValidator.new()
var level: Dictionary = {}
var level_cursor := 0
var board := ParkingBoard.new()
var car_views: Dictionary = {}
var history: Array[Dictionary] = []
var board_offset := Vector3.ZERO
var moves := 0
var is_busy := false
var optimal_moves := -1
var selected_car_id := ""
var auto_path: Array = []
var level_cleared := false

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
	_load_level_at(0)

func _load_level_at(index: int) -> void:
	if catalog.size() == 0:
		_fail_boot("NO LEVELS")
		return
	level_cursor = posmod(index, catalog.size())
	level = catalog.load_level(level_cursor)
	if level.is_empty():
		_fail_boot("LEVEL LOAD ERROR")
		return
	var validation := level_validator.validate(level)
	if not validation.is_empty():
		_fail_boot("LEVEL INVALID: %s" % validation[0])
		return
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
	_load_level_at(level_cursor + 1)

func restart_level() -> void:
	is_busy = false
	level_cleared = false
	moves = 0
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
	status_label.text = "FREE THE RED CAR"
	hint_label.text = "Tap an end to move · tap center + ◀ ▶ as fallback · drag anywhere to orbit"
	input_controller.set_enabled(true)
	input_controller.reset_camera()
	next_button.visible = false
	_update_ui()

func undo_move() -> void:
	if is_busy or level_cleared or history.is_empty():
		return
	var step: Dictionary = history.pop_back()
	var car_id := str(step.get("id", ""))
	var previous_position: Vector2i = step.get("from", Vector2i.ZERO)
	board.set_position(car_id, previous_position)
	moves = max(0, moves - 1)
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
	_update_ui()

func _move_selected(sign: int) -> void:
	if selected_car_id.is_empty():
		status_label.text = "TAP A CAR FIRST"
		_reset_status_later()
		return
	_on_move_requested(selected_car_id, sign)

func _select_car(car_id: String) -> void:
	if is_busy or level_cleared or not car_views.has(car_id):
		return
	selected_car_id = car_id
	for id_value in car_views.keys():
		var id := str(id_value)
		var view: ParkingPanicCarView = car_views[id]
		view.set_selected(id == selected_car_id)
	status_label.text = "%s SELECTED" % selected_car_id.to_upper()
	_update_ui()

func _on_move_requested(car_id: String, sign: int) -> void:
	if is_busy or level_cleared:
		return
	_select_car(car_id)
	var view: ParkingPanicCarView = car_views.get(car_id)
	if view == null or view.busy:
		return
	var result := board.apply_move(car_id, sign)
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
	view.animate_to(_world_position(car_id), 0.14)
	fx.burst(view.position + Vector3.UP * 0.30, view.body_color, 7, 0.34)
	fx.camera_kick()
	audio.move_sound(moves)
	Input.vibrate_handheld(8)
	_update_ui()
	await get_tree().create_timer(0.15).timeout
	is_busy = false
	_update_ui()

func _complete_level(hero: ParkingPanicCarView, sign: int) -> void:
	is_busy = true
	level_cleared = true
	input_controller.set_enabled(false)
	moves += 1
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
		var result := board.apply_move(car_id, sign)
		if not bool(result.get("ok", false)):
			_fail_auto("AUTO PATH FAILED")
			return
		if bool(result.get("exit", false)):
			is_busy = false
			_complete_level(view, sign)
			return
		moves += 1
		view.animate_to(_world_position(car_id), 0.18)
		fx.burst(view.position + Vector3.UP * 0.30, view.body_color, 6, 0.30)
		audio.move_sound(moves)
		_update_ui()
		await get_tree().create_timer(0.28).timeout
	_fail_auto("AUTO PATH DID NOT EXIT")

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
	push_error("Parking Panic: %s" % message)

func _world_position(car_id: String) -> Vector3:
	var spec := board.get_spec(car_id)
	var pos := board.get_position(car_id)
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
		status_label.text = "FREE THE RED CAR" if selected_car_id.is_empty() else "%s SELECTED" % selected_car_id.to_upper()

func _update_level_labels() -> void:
	var world := str(level.get("world", "WORLD"))
	var title := str(level.get("title", "TRAFFIC JAM"))
	title_label.text = "PARKING PANIC · %s" % world
	world_name_label.text = "WORLD %02d · %s · %s" % [level_cursor + 1, world, title]
	progress_label.text = "%d / %d" % [level_cursor + 1, catalog.size()]

func _update_ui() -> void:
	move_label.text = "MOVES %02d" % moves
	optimal_label.text = "OPT %02d" % optimal_moves if optimal_moves >= 0 else "OPT --"
	selected_label.text = "SELECTED: NONE" if selected_car_id.is_empty() else "SELECTED: %s" % selected_car_id.to_upper()
	undo_button.disabled = history.is_empty() or is_busy or level_cleared
	auto_button.disabled = is_busy
	backward_button.disabled = selected_car_id.is_empty() or is_busy or level_cleared
	forward_button.disabled = selected_car_id.is_empty() or is_busy or level_cleared
	restart_button.disabled = is_busy
