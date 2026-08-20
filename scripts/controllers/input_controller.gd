class_name ParkingPanicInputController
extends Node

signal move_requested(car_id: String, sign: int)
signal car_selected(car_id: String)

const TAP_DRAG_THRESHOLD := 12.0
const ENDCAP_LAYER := 1
const BODY_LAYER := 2

var camera: Camera3D
var orbit_rig: Node3D
var enabled := true
var camera_distance := 11.5
var orbit_velocity := Vector2.ZERO

var active_pointer := -999
var press_pos := Vector2.ZERO
var last_pointer_pos := Vector2.ZERO
var pending_hit: Dictionary = {}
var dragging := false
var touch_points: Dictionary = {}
var previous_pinch_distance := 0.0
var pinching := false

func configure(target_camera: Camera3D, target_orbit_rig: Node3D) -> void:
	camera = target_camera
	orbit_rig = target_orbit_rig

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_cancel_gesture()

func reset_camera() -> void:
	if orbit_rig == null or camera == null:
		return
	orbit_rig.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(-42.0), 0.0)
	camera_distance = 11.5
	camera.position = Vector3(0, 0, camera_distance)
	orbit_velocity = Vector2.ZERO
	_cancel_gesture()

func _process(delta: float) -> void:
	if not enabled or orbit_rig == null:
		return
	if active_pointer == -999 and not pinching and orbit_velocity.length() > 0.02:
		_apply_orbit_delta(orbit_velocity * delta * 4.2)
		orbit_velocity = orbit_velocity.lerp(Vector2.ZERO, min(1.0, delta * 7.0))

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or camera == null or orbit_rig == null:
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		if active_pointer == -1:
			_pointer_motion(event.position, event.relative)
	elif event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_set_zoom(camera_distance - 0.55)
		get_viewport().set_input_as_handled()
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_set_zoom(camera_distance + 0.55)
		get_viewport().set_input_as_handled()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_pointer_press(event.position, -1)
	else:
		_pointer_release(-1)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		touch_points[event.index] = event.position
		if touch_points.size() == 1:
			_pointer_press(event.position, event.index)
		elif touch_points.size() == 2:
			pinching = true
			pending_hit.clear()
			dragging = false
			active_pointer = -999
			previous_pinch_distance = _touch_distance()
	else:
		touch_points.erase(event.index)
		if not pinching:
			_pointer_release(event.index)
		if touch_points.size() < 2:
			pinching = false
			previous_pinch_distance = 0.0
			active_pointer = -999

func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	touch_points[event.index] = event.position
	if touch_points.size() >= 2:
		pinching = true
		pending_hit.clear()
		active_pointer = -999
		var distance: float = _touch_distance()
		if previous_pinch_distance > 0.0:
			_set_zoom(camera_distance - (distance - previous_pinch_distance) * 0.012)
		previous_pinch_distance = distance
		get_viewport().set_input_as_handled()
		return
	if not pinching and active_pointer == event.index:
		_pointer_motion(event.position, event.relative)

func _pointer_press(screen_pos: Vector2, pointer_id: int) -> void:
	active_pointer = pointer_id
	press_pos = screen_pos
	last_pointer_pos = screen_pos
	pending_hit = _raycast_picker(screen_pos)
	dragging = false
	orbit_velocity = Vector2.ZERO

func _pointer_motion(screen_pos: Vector2, relative: Vector2) -> void:
	if active_pointer == -999:
		return
	if not dragging and screen_pos.distance_to(press_pos) >= TAP_DRAG_THRESHOLD:
		dragging = true
		pending_hit.clear()
	if dragging:
		_apply_orbit_delta(relative)
		orbit_velocity = relative
		get_viewport().set_input_as_handled()
	last_pointer_pos = screen_pos

func _pointer_release(pointer_id: int) -> void:
	if active_pointer != pointer_id:
		return
	if not dragging and not pending_hit.is_empty():
		_emit_hit(pending_hit)
		get_viewport().set_input_as_handled()
	active_pointer = -999
	dragging = false
	pending_hit.clear()

func _emit_hit(hit: Dictionary) -> void:
	var collider: Area3D = hit.get("collider") as Area3D
	if collider == null or not collider.has_meta("car_id"):
		return
	var car_id := str(collider.get_meta("car_id"))
	if collider.has_meta("move_sign"):
		move_requested.emit(car_id, int(collider.get_meta("move_sign")))
	else:
		car_selected.emit(car_id)

func _raycast_picker(screen_pos: Vector2) -> Dictionary:
	# Endcaps win over the large body picker, eliminating overlap ambiguity.
	var endcap_hit: Dictionary = _raycast_layer(screen_pos, ENDCAP_LAYER)
	if not endcap_hit.is_empty():
		return endcap_hit
	return _raycast_layer(screen_pos, BODY_LAYER)

func _raycast_layer(screen_pos: Vector2, layer_mask: int) -> Dictionary:
	var ray_from: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_to: Vector3 = ray_from + camera.project_ray_normal(screen_pos) * 100.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = layer_mask
	return camera.get_world_3d().direct_space_state.intersect_ray(query)

func _touch_distance() -> float:
	var points: Array = touch_points.values()
	if points.size() < 2:
		return 0.0
	var a: Vector2 = points[0]
	var b: Vector2 = points[1]
	return a.distance_to(b)

func _apply_orbit_delta(delta_pixels: Vector2) -> void:
	orbit_rig.rotation.y -= delta_pixels.x * 0.006
	orbit_rig.rotation.x -= delta_pixels.y * 0.006
	orbit_rig.rotation.x = clamp(orbit_rig.rotation.x, deg_to_rad(-72.0), deg_to_rad(-16.0))

func _set_zoom(value: float) -> void:
	camera_distance = clamp(value, 8.0, 15.0)
	camera.position.z = camera_distance

func _cancel_gesture() -> void:
	active_pointer = -999
	dragging = false
	pinching = false
	pending_hit.clear()
	touch_points.clear()
	previous_pinch_distance = 0.0
