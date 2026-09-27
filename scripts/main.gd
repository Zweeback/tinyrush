extends Node3D

const CAR_SCENE := preload("res://scenes/tiny_car.tscn")
const LEVEL_PATH := "res://data/levels/arrow_city_01.json"
const BASE_CAMERA_FOV := 42.0

@export var cell_size := 1.02

var level: Dictionary = {}
var board := ArrowEscapeBoard.new()
var car_views: Dictionary = {}
var history: Array[Dictionary] = []
var moves := 0
var score := 0
var combo := 0
var best_combo := 0
var flow_remaining := 0.0
var flow_window := 1.35
var is_busy := false
var level_cleared := false
var selected_car_id := ""

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
	input_controller.configure(camera, orbit_rig)
	input_controller.move_requested.connect(_on_move_requested)
	input_controller.car_selected.connect(_on_car_selected)
	fx.configure(fx_root, orbit_rig)
	restart_button.pressed.connect(restart_level)
	undo_button.pressed.connect(undo_move)
	auto_button.pressed.connect(_start_auto_demo)
	next_button.pressed.connect(restart_level)
	backward_button.visible = false
	forward_button.visible = false
	auto_button.visible = false
	_load_cube_arrow_level()

func _load_cube_arrow_level() -> void:
	var file := FileAccess.open(LEVEL_PATH, FileAccess.READ)
	if file == null:
		_fail_boot("CUBE LEVEL LOAD ERROR")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail_boot("CUBE LEVEL JSON ERROR")
		return
	level = parsed

	var errors := _validate_cube_level(level)
	if not errors.is_empty():
		_fail_boot("CUBE LEVEL INVALID: %s" % errors[0])
		return

	board.configure(level)
	world_builder.build(level, cell_size)
	title_label.text = "TINY RUSH · CUBE ARROWS"
	world_name_label.text = "PARKING PANIC · INVERTED"
	progress_label.text = "3 PLAYABLE FACES"
	self_test_label.text = "CUBE ARROWS · FACE COLLISIONS OK · %d CARS" % board.car_ids().size()
	restart_level()

func restart_level() -> void:
	is_busy = false
	level_cleared = false
	moves = 0
	combo = 0
	best_combo = 0
	flow_remaining = 0.0
	score = 0
	history.clear()
	selected_car_id = ""
	board.reset_from_level(level)

	for child in cars_root.get_children():
		child.free()
	car_views.clear()

	var spawn_index := 0
	for car_id_value in board.car_ids():
		var car_id := str(car_id_value)
		var view: ParkingPanicCarView = CAR_SCENE.instantiate()
		cars_root.add_child(view)
		view.configure(board.get_spec(car_id), cell_size)
		view.transform = _world_transform(car_id)
		car_views[car_id] = view
		if str(board.get_spec(car_id).get("face", "top")) == "top":
			view.animate_spawn(float(spawn_index) * 0.025)
		spawn_index += 1

	status_label.text = "CLEAR THE WHOLE CUBE"
	hint_label.text = "Tap a roof arrow · clear path = launch · occupied path = bounce"
	status_label.modulate = Color.WHITE
	optimal_label.modulate = Color.WHITE
	camera.fov = BASE_CAMERA_FOV
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
	board.restore_car(car_id)
	moves = maxi(0, moves - 1)
	combo = 0
	flow_remaining = 0.0
	var view: ParkingPanicCarView = car_views.get(car_id)
	if view != null:
		view.visible = true
		view.busy = false
		view.scale = Vector3.ONE
		view.transform = _world_transform(car_id)
	status_label.modulate = Color.WHITE
	optimal_label.modulate = Color.WHITE
	audio.undo_sound()
	_refresh_move_hints()
	_update_ui()

func _on_car_selected(car_id: String) -> void:
	_tap_car(car_id)

func _on_move_requested(car_id: String, _sign: int) -> void:
	_tap_car(car_id)

func _tap_car(car_id: String) -> void:
	if is_busy or level_cleared or not board.is_active(car_id):
		return
	var view: ParkingPanicCarView = car_views.get(car_id)
	if view == null or view.busy:
		return

	selected_car_id = car_id
	var spec: Dictionary = board.get_spec(car_id)
	var axis: Vector2i = spec.get("axis", Vector2i(1, 0))
	var direction: Vector2i = spec.get("escape_dir", axis)
	var face := str(spec.get("face", "top"))
	var local_sign := 1 if direction == axis else -1

	if not _cube_route_clear(car_id):
		combo = 0
		flow_remaining = 0.0
		score = maxi(0, score - 25)
		var fail_color := Color(1.0, 0.25, 0.10, 1)
		status_label.modulate = fail_color
		optimal_label.modulate = Color.WHITE
		view.blocked_feedback(local_sign)
		var normal := _face_basis(face).y
		fx.impact_star(view.position + normal * 0.20, fail_color, 2)
		fx.burst(view.position + normal * 0.30, fail_color, 7, 0.30)
		audio.blocked_sound()
		Input.vibrate_handheld(18)
		status_label.text = "%s · PATH OCCUPIED" % car_id.to_upper()
		_refresh_move_hints()
		_update_ui()
		_reset_status_later()
		return

	board.active[car_id] = false
	history.append({"id": car_id})
	moves += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	flow_remaining = maxf(0.62, flow_window - float(combo - 1) * 0.035)
	score += 100 + combo * 30
	is_busy = true

	var flow_color := _flow_color(combo)
	status_label.modulate = flow_color
	optimal_label.modulate = flow_color
	_refresh_move_hints()
	view.set_move_hints(false, false)

	var world_direction := _face_direction_to_world(face, direction)
	var normal := _face_basis(face).y
	var burst_count := mini(24, 10 + combo * 2)
	fx.burst(view.position + normal * 0.30, view.body_color, burst_count, 0.44 + minf(0.34, float(combo) * 0.03))
	fx.impact_star(view.position + normal * 0.16, flow_color, combo)
	fx.speed_trail(view.position + normal * 0.24, world_direction, flow_color, combo)
	fx.combo_camera_kick(combo)
	_combo_camera_punch(combo)
	audio.move_sound(moves)
	Input.vibrate_handheld(7 + mini(18, combo * 2))

	var exit_duration := maxf(0.13, 0.30 - float(combo - 1) * 0.015)
	view.animate_exit(world_direction, cell_size * 10.0, exit_duration)
	status_label.text = "FLOW x%d · %d LEFT" % [combo, board.remaining_count()]
	_update_ui()

	await get_tree().create_timer(exit_duration + 0.12).timeout
	is_busy = false
	selected_car_id = ""
	if board.remaining_count() == 0:
		_complete_level()
		return
	_refresh_move_hints()
	_update_ui()

func _cube_route_clear(car_id: String) -> bool:
	var car: ParkingCarState = board.get_car(car_id)
	if car == null or not board.is_active(car_id):
		return false
	var direction := car.escape_dir
	if direction == Vector2i.ZERO:
		return false

	var occupied := {}
	for other_value in board.car_ids():
		var other_id := str(other_value)
		if other_id == car_id or not board.is_active(other_id):
			continue
		var other: ParkingCarState = board.get_car(other_id)
		if other.face != car.face:
			continue
		for cell in other.occupied_cells():
			occupied[cell] = other_id

	var cells := car.occupied_cells()
	var lead: Vector2i = cells[0]
	var best_dot := lead.x * direction.x + lead.y * direction.y
	for cell in cells:
		var dot := cell.x * direction.x + cell.y * direction.y
		if dot > best_dot:
			best_dot = dot
			lead = cell

	var cursor := lead + direction
	while board.inside(cursor):
		if occupied.has(cursor):
			return false
		cursor += direction
	return true

func _complete_level() -> void:
	level_cleared = true
	input_controller.set_enabled(false)
	selected_car_id = ""
	score += 750 + best_combo * 60
	var clear_color := _flow_color(maxi(best_combo, 10))
	status_label.modulate = clear_color
	optimal_label.modulate = clear_color
	status_label.text = "CUBE CLEARED · FLOW x%d" % best_combo
	hint_label.text = "RUSH HOUR REVERSED · ALL TRAFFIC OUT"
	fx.burst(Vector3(0, 0.8, 0), clear_color, 46, 1.42)
	fx.impact_star(Vector3(0, 0.3, 0), clear_color, 10)
	_combo_camera_punch(10)
	Input.vibrate_handheld(42)
	audio.play_win_chime()
	next_button.visible = true
	next_button.text = "RUN AGAIN ▶"
	_update_ui()

func _refresh_move_hints() -> void:
	for id_value in car_views.keys():
		var car_id := str(id_value)
		var view: ParkingPanicCarView = car_views[car_id]
		if level_cleared or not board.is_active(car_id):
			view.set_move_hints(false, false)
		else:
			view.set_arrow_escape_state(_cube_route_clear(car_id), combo)

func _world_transform(car_id: String) -> Transform3D:
	var spec: Dictionary = board.get_spec(car_id)
	var car: ParkingCarState = board.get_car(car_id)
	var axis: Vector2i = spec.get("axis", Vector2i(1, 0))
	var length_cells := int(spec.get("len", 2))
	var face := str(spec.get("face", "top"))

	var center_u := float(car.grid_pos.x) + float(axis.x) * float(length_cells - 1) * 0.5
	var center_v := float(car.grid_pos.y) + float(axis.y) * float(length_cells - 1) * 0.5
	var local_x := (center_u - float(board.bounds.x - 1) * 0.5) * cell_size
	var local_z := (center_v - float(board.bounds.y - 1) * 0.5) * cell_size

	var face_basis := _face_basis(face)
	var origin := _face_center(face) + face_basis.x * local_x + face_basis.z * local_z
	var yaw := PI * 0.5 if axis.x != 0 else 0.0
	var car_basis := face_basis * Basis(Vector3.UP, yaw)
	return Transform3D(car_basis, origin)

func _face_center(face: String) -> Vector3:
	var panel_y := -world_builder.cube_height * 0.5 - 0.22
	match face:
		"front":
			return Vector3(0, panel_y, world_builder.cube_depth * 0.5 + 0.48)
		"right":
			return Vector3(world_builder.cube_width * 0.5 + 0.48, panel_y, 0)
		"back":
			return Vector3(0, panel_y, -world_builder.cube_depth * 0.5 - 0.48)
		"left":
			return Vector3(-world_builder.cube_width * 0.5 - 0.48, panel_y, 0)
		_:
			return Vector3(0, 0.14, 0)

func _face_basis(face: String) -> Basis:
	match face:
		"front":
			return Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
		"right":
			return Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0))
		"back":
			return Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0))
		"left":
			return Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
		_:
			return Basis.IDENTITY

func _face_direction_to_world(face: String, direction: Vector2i) -> Vector3:
	var basis := _face_basis(face)
	return (basis.x * float(direction.x) + basis.z * float(direction.y)).normalized()

func _validate_cube_level(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var bounds_value: Variant = data.get("bounds", [0, 0])
	if not bounds_value is Array or bounds_value.size() < 2:
		return ["missing bounds"]
	var bounds := Vector2i(int(bounds_value[0]), int(bounds_value[1]))
	if bounds.x <= 0 or bounds.y <= 0:
		return ["invalid bounds"]

	var valid_faces := ["top", "front", "right", "back", "left"]
	var occupied := {}
	var ids := {}
	var targets := 0
	for raw in data.get("cars", []):
		if not raw is Dictionary:
			errors.append("car entry must be an object")
			continue
		var car: Dictionary = raw
		var car_id := str(car.get("id", ""))
		var face := str(car.get("face", "top")).to_lower()
		var pos_value: Variant = car.get("pos", [0, 0])
		var axis_value: Variant = car.get("axis", [1, 0])
		var dir_value: Variant = car.get("escape_dir", [1, 0])
		var length_cells := int(car.get("len", 2))
		if car_id.is_empty() or ids.has(car_id):
			errors.append("car ids must be unique")
			continue
		ids[car_id] = true
		if face not in valid_faces:
			errors.append("%s has invalid face" % car_id)
			continue
		var pos := Vector2i(int(pos_value[0]), int(pos_value[1]))
		var axis := Vector2i(int(axis_value[0]), int(axis_value[1]))
		var direction := Vector2i(int(dir_value[0]), int(dir_value[1]))
		if axis not in [Vector2i(1, 0), Vector2i(0, 1)]:
			errors.append("%s has invalid axis" % car_id)
		if direction != axis and direction != -axis:
			errors.append("%s arrow must follow vehicle axis" % car_id)
		if bool(car.get("target", false)):
			targets += 1
		for i in range(length_cells):
			var cell := pos + axis * i
			if cell.x < 0 or cell.x >= bounds.x or cell.y < 0 or cell.y >= bounds.y:
				errors.append("%s is outside face grid" % car_id)
				continue
			var key := "%s:%d:%d" % [face, cell.x, cell.y]
			if occupied.has(key):
				errors.append("%s overlaps %s" % [car_id, occupied[key]])
			else:
				occupied[key] = car_id
	if targets != 1:
		errors.append("cube level needs exactly one red hero car")
	return errors

func _start_auto_demo() -> void:
	pass

func _reset_status_later() -> void:
	await get_tree().create_timer(0.35).timeout
	if not is_busy and not level_cleared:
		status_label.modulate = Color.WHITE
		status_label.text = "CLEAR THE WHOLE CUBE"

func _update_ui() -> void:
	move_label.text = "SCORE %05d" % score
	optimal_label.text = "FLOW x%d" % combo
	undo_button.disabled = history.is_empty() or is_busy or level_cleared
	restart_button.disabled = is_busy

	var open_routes := 0
	if not level_cleared:
		for id_value in board.car_ids():
			var car_id := str(id_value)
			if board.is_active(car_id) and _cube_route_clear(car_id):
				open_routes += 1
	selected_label.text = "OPEN %d · LEFT %d" % [open_routes, board.remaining_count()]

func _process(delta: float) -> void:
	if level_cleared or combo <= 0 or is_busy:
		return
	flow_remaining = maxf(0.0, flow_remaining - delta)
	if flow_remaining <= 0.0:
		combo = 0
		status_label.modulate = Color.WHITE
		optimal_label.modulate = Color.WHITE
		_refresh_move_hints()
		_update_ui()

func _flow_color(level_value: int) -> Color:
	if level_value >= 10:
		return Color(1.0, 0.20, 0.72, 1)
	if level_value >= 7:
		return Color(1.0, 0.76, 0.08, 1)
	if level_value >= 4:
		return Color(0.48, 1.0, 0.12, 1)
	return Color(0.08, 1.0, 0.86, 1)

func _combo_camera_punch(level_value: int) -> void:
	if level_value != 5 and level_value != 10:
		return
	var target_fov := 35.5 if level_value == 5 else 31.0
	var tween := create_tween()
	tween.tween_property(camera, "fov", target_fov, 0.075).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "fov", BASE_CAMERA_FOV, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fail_boot(message: String) -> void:
	status_label.text = message
	hint_label.text = "Startup validation failed."
	self_test_label.text = "SELF TEST · FAIL"
	push_error("TinyRush: %s" % message)
