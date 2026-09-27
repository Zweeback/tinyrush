extends Node3D

const CAR_SCENE := preload("res://scenes/tiny_car.tscn")
const LEVEL_PATH := "res://data/levels/arrow_city_01.json"
const BASE_CAMERA_FOV := 38.0

@export var cell_size := 1.02

var level: Dictionary = {}
var board := ArrowEscapeBoard.new()
var car_views: Dictionary = {}
var moves := 0
var is_busy := false
var level_cleared := false
var juice_chain := 0
var best_juice_chain := 0

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
	next_button.pressed.connect(restart_level)

	undo_button.visible = false
	auto_button.visible = false
	backward_button.visible = false
	forward_button.visible = false
	selected_label.visible = false

	_load_arrow_cube()

func _load_arrow_cube() -> void:
	var file := FileAccess.open(LEVEL_PATH, FileAccess.READ)
	if file == null:
		_fail_boot("LEVEL LOAD ERROR")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail_boot("LEVEL JSON ERROR")
		return

	level = parsed
	var errors := _validate_cube_level(level)
	if not errors.is_empty():
		_fail_boot("LEVEL INVALID: %s" % errors[0])
		return

	board.configure(level)
	world_builder.build(level, cell_size)

	title_label.text = "TINY RUSH · ARROWS"
	world_name_label.text = "ARROWS · 3D CUBE"
	progress_label.text = "TOP · FRONT · RIGHT"
	self_test_label.text = "ARROWS · 3 FACES · %d VEHICLES" % board.car_ids().size()

	restart_level()

func restart_level() -> void:
	is_busy = false
	level_cleared = false
	moves = 0
	juice_chain = 0
	best_juice_chain = 0
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
			view.animate_spawn(float(spawn_index) * 0.02)
			spawn_index += 1

	status_label.modulate = Color.WHITE
	optimal_label.modulate = Color.WHITE
	status_label.text = "TAP A CAR"
	hint_label.text = "Arrow = driving direction · blocked path = no move"
	camera.fov = BASE_CAMERA_FOV
	input_controller.set_enabled(true)
	input_controller.reset_camera()
	next_button.visible = false

	_refresh_arrows()
	_update_ui()

func _on_car_selected(car_id: String) -> void:
	_try_arrow_move(car_id)

func _on_move_requested(car_id: String, _sign: int) -> void:
	_try_arrow_move(car_id)

func _try_arrow_move(car_id: String) -> void:
	if is_busy or level_cleared or not board.is_active(car_id):
		return

	var view: ParkingPanicCarView = car_views.get(car_id)
	if view == null or view.busy:
		return

	var spec: Dictionary = board.get_spec(car_id)
	var axis: Vector2i = spec.get("axis", Vector2i(1, 0))
	var direction: Vector2i = spec.get("escape_dir", axis)
	var face := str(spec.get("face", "top"))
	var local_sign := 1 if direction == axis else -1

	if not _route_clear(car_id):
		juice_chain = 0
		view.blocked_feedback(local_sign)
		audio.blocked_sound()
		Input.vibrate_handheld(14)
		status_label.text = "BLOCKED"
		await get_tree().create_timer(0.22).timeout
		if not level_cleared:
			status_label.text = "TAP A CAR"
		return

	board.active[car_id] = false
	moves += 1
	juice_chain += 1
	best_juice_chain = maxi(best_juice_chain, juice_chain)
	is_busy = true
	view.set_move_hints(false, false)

	var world_direction := _face_direction_to_world(face, direction)
	var normal := _face_basis(face).y

	var reward_color := _reward_color(juice_chain)
	fx.burst(view.position + normal * 0.22, view.body_color, mini(16, 7 + juice_chain), 0.24 + minf(0.18, float(juice_chain) * 0.02))
	fx.reward_pulse(view.position + normal * 0.12, reward_color, juice_chain)
	if juice_chain in [3, 6, 9]:
		fx.milestone_burst(view.position + normal * 0.16, reward_color, juice_chain / 3)
		_reward_camera_punch(juice_chain)
	audio.move_sound(moves)
	Input.vibrate_handheld(7 + mini(12, juice_chain))
	view.animate_exit(world_direction, cell_size * 9.0, maxf(0.16, 0.24 - float(juice_chain) * 0.006))

	status_label.modulate = reward_color
	status_label.text = "CHAIN x%d · %d LEFT" % [juice_chain, board.remaining_count()]
	_update_ui()

	await get_tree().create_timer(0.32).timeout
	is_busy = false

	if board.remaining_count() == 0:
		_complete_level()
		return

	_refresh_arrows()
	_update_ui()

func _route_clear(car_id: String) -> bool:
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

func _refresh_arrows() -> void:
	for id_value in car_views.keys():
		var car_id := str(id_value)
		var view: ParkingPanicCarView = car_views[car_id]
		if level_cleared or not board.is_active(car_id):
			view.set_move_hints(false, false)
		else:
			view.set_arrow_escape_state(_route_clear(car_id), 0)

func _complete_level() -> void:
	level_cleared = true
	input_controller.set_enabled(false)
	var clear_color := _reward_color(maxi(best_juice_chain, 9))
	status_label.modulate = clear_color
	status_label.text = "CLEARED · BEST CHAIN x%d" % best_juice_chain
	hint_label.text = "ALL ARROWS OUT"
	fx.milestone_burst(Vector3(0, 0.5, 0), clear_color, 4)
	_reward_camera_punch(9)
	audio.play_win_chime()
	Input.vibrate_handheld(38)
	next_button.visible = true
	next_button.text = "REPLAY ▶"
	_update_ui()

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
	var faces := {}

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
		faces[face] = true

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

	if not faces.has("top") or not faces.has("front") or not faces.has("right"):
		errors.append("top, front and right must contain cars")

	return errors

func _update_ui() -> void:
	move_label.text = "LEFT %02d" % board.remaining_count()
	optimal_label.text = "CHAIN x%d" % juice_chain
	restart_button.disabled = is_busy

func _reward_color(chain: int) -> Color:
	if chain >= 9:
		return Color(1.0, 0.24, 0.70, 1)
	if chain >= 6:
		return Color(1.0, 0.76, 0.10, 1)
	if chain >= 3:
		return Color(0.42, 1.0, 0.18, 1)
	return Color(0.10, 0.92, 1.0, 1)

func _reward_camera_punch(chain: int) -> void:
	var target_fov := BASE_CAMERA_FOV - minf(5.0, float(chain) * 0.35)
	var tween := create_tween()
	tween.tween_property(camera, "fov", target_fov, 0.07).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "fov", BASE_CAMERA_FOV, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fail_boot(message: String) -> void:
	status_label.text = message
	hint_label.text = "Startup validation failed."
	self_test_label.text = "SELF TEST · FAIL"
	push_error("TinyRush: %s" % message)
