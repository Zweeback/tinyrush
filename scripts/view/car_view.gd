class_name ParkingPanicCarView
extends Node3D

const ENDCAP_LAYER := 1
const BODY_LAYER := 2

var car_id := ""
var axis := Vector2i(1, 0)
var length_cells := 2
var cell_size := 1.0
var is_target := false
var vehicle_type := "car"
var arrow_mode := false
var escape_dir := Vector2i.ZERO
var body_color := Color(0.2, 0.65, 1.0, 1.0)
var busy := false
var selected := false

var selection_marker: MeshInstance3D
var backward_hint_root: Node3D
var forward_hint_root: Node3D

@onready var visual_root: Node3D = $VisualRoot
@onready var picker_root: Node3D = $PickerRoot

func configure(spec: Dictionary, size: float) -> void:
	car_id = str(spec.get("id", "car"))
	axis = spec.get("axis", Vector2i(1, 0))
	length_cells = int(spec.get("len", 2))
	cell_size = size
	is_target = bool(spec.get("target", false))
	vehicle_type = str(spec.get("vehicle_type", "car")).to_lower()
	arrow_mode = bool(spec.get("arrow_mode", false))
	escape_dir = spec.get("escape_dir", Vector2i.ZERO)
	body_color = _color_from_array(spec.get("color", [0.2, 0.65, 1.0, 1.0]))
	_build_visuals()
	_build_pickers()
	_orient_to_axis()
	set_selected(false)
	if arrow_mode:
		set_arrow_escape_state(false)
	else:
		set_move_hints(false, false)

func set_selected(value: bool) -> void:
	selected = value
	if selection_marker != null:
		selection_marker.visible = selected or is_target
	var target_scale: Vector3 = Vector3(1.05, 1.05, 1.05) if selected else Vector3.ONE
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func set_move_hints(can_backward: bool, can_forward: bool) -> void:
	if backward_hint_root != null:
		backward_hint_root.visible = can_backward
	if forward_hint_root != null:
		forward_hint_root.visible = can_forward

func set_arrow_escape_state(can_escape: bool, combo_level: int = 0) -> void:
	if backward_hint_root == null or forward_hint_root == null:
		return
	var sign := _local_escape_sign()
	backward_hint_root.visible = sign < 0
	forward_hint_root.visible = sign > 0
	var color := _flow_arrow_color(combo_level) if can_escape else Color(1.0, 0.25, 0.10, 0.96)
	var root := forward_hint_root if sign > 0 else backward_hint_root
	_recolor_hint(root, color)

func _flow_arrow_color(combo_level: int) -> Color:
	if combo_level >= 10:
		return Color(1.0, 0.20, 0.72, 0.99)
	if combo_level >= 7:
		return Color(1.0, 0.76, 0.08, 0.99)
	if combo_level >= 4:
		return Color(0.48, 1.0, 0.12, 0.99)
	return Color(0.08, 1.0, 0.86, 0.98)

func _local_escape_sign() -> int:
	if escape_dir == -axis:
		return -1
	return 1

func _recolor_hint(root: Node3D, color: Color) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = _material(color, 2.8, 0.18, true)

func _build_visuals() -> void:
	_clear_children(visual_root)
	var full_length: float = float(length_cells) * cell_size * 0.82
	match vehicle_type:
		"truck":
			_build_truck(full_length)
		_:
			_build_compact(full_length)
	_build_common_details(full_length)
	_build_move_arrows(full_length)

func _build_compact(full_length: float) -> void:
	var glass := Color(0.08, 0.78, 1.0, 1)
	_box(Vector3(0.82, 0.29, full_length), Vector3(0, 0.22, 0), body_color, 0.04, 0.30)
	_box(Vector3(0.72, 0.12, full_length * 0.84), Vector3(0, 0.35, 0), body_color.lightened(0.05), 0.02, 0.27)
	var cabin_length: float = minf(0.90, full_length * 0.46)
	_box(Vector3(0.55, 0.27, cabin_length), Vector3(0, 0.49, -full_length * 0.04), body_color.lightened(0.13), 0.02, 0.25)
	_box(Vector3(0.45, 0.16, 0.04), Vector3(0, 0.51, cabin_length * 0.50 - full_length * 0.04), glass, 0.08, 0.18)
	_box(Vector3(0.45, 0.15, 0.04), Vector3(0, 0.49, -cabin_length * 0.50 - full_length * 0.04), glass.darkened(0.04), 0.06, 0.18)
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		_box(Vector3(0.03, 0.14, cabin_length * 0.54), Vector3(side * 0.29, 0.49, -full_length * 0.04), glass, 0.06, 0.18)

func _build_van(full_length: float) -> void:
	var glass := Color(0.035, 0.20, 0.35, 1)
	_box(Vector3(0.80, 0.34, full_length), Vector3(0, 0.25, 0), body_color, 0.03, 0.34)
	_box(Vector3(0.72, 0.34, full_length * 0.76), Vector3(0, 0.57, -full_length * 0.06), body_color.lightened(0.08), 0.02, 0.30)
	var windshield_z: float = full_length * 0.28
	_box(Vector3(0.56, 0.19, 0.045), Vector3(0, 0.60, windshield_z), glass, 0.08, 0.18)
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		_box(Vector3(0.035, 0.16, full_length * 0.24), Vector3(side * 0.36, 0.60, full_length * 0.12), glass, 0.06, 0.20)
		_box(Vector3(0.035, 0.14, full_length * 0.18), Vector3(side * 0.36, 0.58, -full_length * 0.16), glass.darkened(0.03), 0.04, 0.22)

func _build_truck(full_length: float) -> void:
	var glass := Color(0.08, 0.74, 1.0, 1)
	var cab_length: float = minf(cell_size * 0.82, full_length * 0.36)
	var cargo_length: float = maxf(cell_size * 1.15, full_length - cab_length - 0.12)
	var cab_z: float = full_length * 0.50 - cab_length * 0.50
	var cargo_z: float = -full_length * 0.50 + cargo_length * 0.50

	_box(Vector3(0.86, 0.36, cab_length), Vector3(0, 0.26, cab_z), body_color.lightened(0.04), 0.03, 0.31)
	_box(Vector3(0.68, 0.28, cab_length * 0.60), Vector3(0, 0.57, cab_z - cab_length * 0.08), body_color.lightened(0.12), 0.02, 0.28)
	_box(Vector3(0.52, 0.17, 0.04), Vector3(0, 0.59, cab_z + cab_length * 0.31), glass, 0.08, 0.18)

	_box(Vector3(0.90, 0.66, cargo_length), Vector3(0, 0.44, cargo_z), body_color.darkened(0.04), 0.02, 0.42)
	for rib in [-0.30, 0.0, 0.30]:
		_box(Vector3(0.87, 0.035, cargo_length * 0.92), Vector3(0, 0.44 + float(rib), cargo_z), body_color.lightened(0.05), 0.0, 0.40)

func _build_common_details(full_length: float) -> void:
	var tire := Color(0.022, 0.026, 0.034, 1)
	var hub := Color(0.58, 0.63, 0.68, 1)
	var wheel_z: float = maxf(0.30, full_length * 0.34)
	if vehicle_type == "truck":
		wheel_z = full_length * 0.36

	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		for z_value in [-wheel_z, wheel_z]:
			var z_pos: float = float(z_value)
			_add_wheel(Vector3(side * 0.43, 0.08, z_pos), tire, hub)
		if vehicle_type == "truck":
			_add_wheel(Vector3(side * 0.43, 0.08, -full_length * 0.08), tire, hub)

	_box(Vector3(0.63, 0.09, 0.07), Vector3(0, 0.19, full_length * 0.50 + 0.025), Color(0.72, 0.74, 0.76, 1), 0.0, 0.28)
	_box(Vector3(0.63, 0.09, 0.07), Vector3(0, 0.19, -full_length * 0.50 - 0.025), Color(0.56, 0.58, 0.61, 1), 0.0, 0.32)

	for x_value in [-0.22, 0.22]:
		var x_pos: float = float(x_value)
		_box(Vector3(0.13, 0.09, 0.045), Vector3(x_pos, 0.23, full_length * 0.50 + 0.06), Color(1.0, 0.90, 0.54, 1), 2.2, 0.18)
		_box(Vector3(0.12, 0.08, 0.045), Vector3(x_pos, 0.22, -full_length * 0.50 - 0.06), Color(1.0, 0.10, 0.18, 1), 1.8, 0.18)

	selection_marker = MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.96, 0.028, full_length + 0.16)
	selection_marker.mesh = marker_mesh
	selection_marker.position = Vector3(0, 0.012, 0)
	selection_marker.material_override = _material(Color(1.0, 0.35, 0.78, 0.88), 2.8, 0.18, true)
	selection_marker.visible = is_target
	visual_root.add_child(selection_marker)

	if is_target:
		_box(Vector3(0.26, 0.055, 0.26), Vector3(0, 0.72, 0), Color(1.0, 0.77, 0.16, 1), 2.5, 0.22)

func _add_wheel(pos: Vector3, tire: Color, hub: Color) -> void:
	var wheel := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.155
	cylinder.bottom_radius = 0.155
	cylinder.height = 0.135
	cylinder.radial_segments = 14
	wheel.mesh = cylinder
	wheel.rotation_degrees = Vector3(0, 0, 90)
	wheel.position = pos
	wheel.material_override = _material(tire, 0.0, 0.82)
	visual_root.add_child(wheel)

	var wheel_hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.075
	hub_mesh.bottom_radius = 0.075
	hub_mesh.height = 0.142
	hub_mesh.radial_segments = 12
	wheel_hub.mesh = hub_mesh
	wheel_hub.rotation_degrees = Vector3(0, 0, 90)
	wheel_hub.position = Vector3(pos.x * 1.005, pos.y, pos.z)
	wheel_hub.material_override = _material(hub, 0.0, 0.30)
	visual_root.add_child(wheel_hub)

func _build_move_arrows(full_length: float) -> void:
	backward_hint_root = Node3D.new()
	forward_hint_root = Node3D.new()
	visual_root.add_child(backward_hint_root)
	visual_root.add_child(forward_hint_root)

	var hint_color := Color(0.08, 1.0, 0.86, 0.98)
	if arrow_mode:
		_build_roof_arrow(backward_hint_root, -1, full_length, hint_color)
		_build_roof_arrow(forward_hint_root, 1, full_length, hint_color)
	else:
		_build_chevron(backward_hint_root, -1, -full_length * 0.50 - 0.18, hint_color)
		_build_chevron(forward_hint_root, 1, full_length * 0.50 + 0.18, hint_color)

func _build_roof_arrow(parent: Node3D, sign: int, full_length: float, color: Color) -> void:
	var row_count := 3 if length_cells >= 3 else 2
	var arrow_y := 1.06 if vehicle_type == "truck" else 0.73
	var spacing := minf(0.34, full_length / float(row_count + 2))
	for row in range(row_count):
		var row_center := (float(row) - float(row_count - 1) * 0.5) * spacing
		for side_value in [-1.0, 1.0]:
			var side := float(side_value)
			var arm := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.13, 0.055, 0.42)
			arm.mesh = mesh
			arm.position = Vector3(side * 0.15, arrow_y + float(row) * 0.004, row_center + float(sign) * 0.05)
			arm.rotation_degrees.y = side * float(sign) * 41.0
			arm.material_override = _material(color, 4.2, 0.10, true)
			parent.add_child(arm)

func _build_chevron(parent: Node3D, sign: int, local_z: float, color: Color) -> void:
	var arm_length := 0.34
	var x_offset := 0.115
	for row in range(2):
		var row_z := local_z - float(sign) * float(row) * 0.20
		for side_value in [-1.0, 1.0]:
			var side: float = float(side_value)
			var arm := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.095, 0.045, arm_length)
			arm.mesh = mesh
			var arrow_y := 0.84 if vehicle_type == "truck" else 0.70
			arm.position = Vector3(side * x_offset, arrow_y + float(row) * 0.006, row_z - float(sign) * 0.055)
			arm.rotation_degrees.y = side * float(sign) * 38.0
			arm.material_override = _material(color, 3.4, 0.14, true)
			parent.add_child(arm)

func _build_pickers() -> void:
	_clear_children(picker_root)
	var full_length: float = float(length_cells) * cell_size * 0.82

	var body_area := Area3D.new()
	body_area.collision_layer = BODY_LAYER
	body_area.collision_mask = 0
	body_area.input_ray_pickable = true
	body_area.set_meta("car_id", car_id)
	body_area.position = Vector3(0, 0.32, 0)

	var body_shape_node := CollisionShape3D.new()
	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(0.98, 1.10, maxf(0.72, full_length * 0.74))
	body_shape_node.shape = body_shape
	body_area.add_child(body_shape_node)
	picker_root.add_child(body_area)

	var picker_depth: float = minf(cell_size * 0.42, full_length * 0.28)
	var picker_center: float = maxf(0.16, full_length * 0.50 - picker_depth * 0.50)
	_add_picker(1, picker_center, picker_depth)
	_add_picker(-1, -picker_center, picker_depth)

func _add_picker(sign: int, local_z: float, picker_depth: float) -> void:
	var area := Area3D.new()
	area.collision_layer = ENDCAP_LAYER
	area.collision_mask = 0
	area.input_ray_pickable = true
	area.set_meta("car_id", car_id)
	area.set_meta("move_sign", sign)
	area.position = Vector3(0, 0.34, local_z)

	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.10, maxf(0.22, picker_depth))
	shape_node.shape = shape
	area.add_child(shape_node)
	picker_root.add_child(area)

func _orient_to_axis() -> void:
	rotation = Vector3.ZERO
	if axis.x != 0:
		rotation_degrees.y = 90.0

func animate_spawn(delay: float = 0.0) -> void:
	busy = true
	var rest_position := position
	var rest_scale := scale
	position = rest_position + Vector3(0, 1.25, 0)
	scale = Vector3(0.36, 0.36, 0.36)
	visual_root.rotation.y -= PI * 0.45
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(self, "position", rest_position, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", rest_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visual_root, "rotation:y", 0.0, 0.24).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_move)

func animate_to(world_position: Vector3, duration: float = 0.15) -> void:
	busy = true
	var rest_scale: Vector3 = Vector3(1.05, 1.05, 1.05) if selected else Vector3.ONE
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", world_position, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector3(1.08, 0.96, 1.08), duration * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", rest_scale, duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_move)

func blocked_feedback(sign: int) -> void:
	var start := position
	var local_direction := Vector3(0, 0, float(sign))
	var world_direction := global_transform.basis * local_direction
	var nudge := world_direction.normalized() * 0.055
	var tween := create_tween()
	tween.tween_property(self, "position", start + nudge, 0.035)
	tween.tween_property(self, "position", start - nudge, 0.045)
	tween.tween_property(self, "position", start, 0.035)

func animate_exit(world_direction: Vector3, distance: float, duration: float = 0.34) -> void:
	busy = true
	set_move_hints(false, false)
	var direction := world_direction.normalized()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.18, 0.88, 1.18), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position", position + direction * 0.18, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", position + direction * distance, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", Vector3(0.12, 0.12, 0.12), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_hide_after_exit)

func animate_wrap(target_transform: Transform3D, duration: float = 0.34) -> void:
	busy = true
	set_move_hints(false, false)
	var start_transform := transform
	var edge_transform := start_transform.interpolate_with(target_transform, 0.5)
	var outward := (start_transform.basis.y + target_transform.basis.y).normalized()
	edge_transform.origin += outward * 0.34
	var tween := create_tween()
	tween.tween_property(self, "transform", edge_transform, duration * 0.48).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "transform", target_transform, duration * 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_move)

func _finish_move() -> void:
	busy = false

func _hide_after_exit() -> void:
	visible = false
	busy = false

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.free()

func _box(
	box_size: Vector3,
	local_pos: Vector3,
	color: Color,
	emission: float = 0.0,
	roughness: float = 0.30,
	transparent: bool = false
) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	item.mesh = mesh
	item.position = local_pos
	item.material_override = _material(color, emission, roughness, transparent)
	visual_root.add_child(item)
	return item

func _material(
	color: Color,
	emission_strength: float = 0.0,
	roughness: float = 0.30,
	transparent: bool = false
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = 0.04
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission_strength > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_strength
	return mat

func _color_from_array(value: Variant) -> Color:
	if value is Array and value.size() >= 4:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	return Color(0.2, 0.65, 1.0, 1.0)
