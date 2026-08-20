class_name ParkingPanicCarView
extends Node3D

const ENDCAP_LAYER := 1
const BODY_LAYER := 2

var car_id := ""
var axis := Vector2i(1, 0)
var length_cells := 2
var cell_size := 1.0
var is_target := false
var body_color := Color(0.2, 0.65, 1.0, 1.0)
var busy := false
var selected := false
var selection_marker: MeshInstance3D

@onready var visual_root: Node3D = $VisualRoot
@onready var picker_root: Node3D = $PickerRoot

func configure(spec: Dictionary, size: float) -> void:
	car_id = str(spec.get("id", "car"))
	axis = spec.get("axis", Vector2i(1, 0))
	length_cells = int(spec.get("len", 2))
	cell_size = size
	is_target = bool(spec.get("target", false))
	body_color = _color_from_array(spec.get("color", [0.2, 0.65, 1.0, 1.0]))
	_build_visuals()
	_build_pickers()
	_orient_to_axis()
	set_selected(false)

func set_selected(value: bool) -> void:
	selected = value
	if selection_marker != null:
		selection_marker.visible = selected
	var target_scale: Vector3 = Vector3(1.045, 1.045, 1.045) if selected else Vector3.ONE
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _build_visuals() -> void:
	_clear_children(visual_root)
	var full_length: float = float(length_cells) * cell_size * 0.84
	_box(Vector3(0.78, 0.30, full_length), Vector3(0, 0.20, 0), body_color, 0.06)
	_box(Vector3(0.58, 0.28, float(min(0.86, full_length * 0.44))), Vector3(0, 0.47, -full_length * 0.03), body_color.lightened(0.14), 0.03)
	_box(Vector3(0.48, 0.17, 0.05), Vector3(0, 0.50, float(min(0.42, full_length * 0.23))), Color(0.04, 0.10, 0.16, 1), 0.04)
	_box(Vector3(0.48, 0.16, 0.05), Vector3(0, 0.47, -float(min(0.42, full_length * 0.23))), Color(0.04, 0.10, 0.16, 1), 0.02)

	var wheel_z: float = float(max(0.28, full_length * 0.33))
	for side_value in [-1.0, 1.0]:
		var side := float(side_value)
		for z_value in [-wheel_z, wheel_z]:
			var z_pos := float(z_value)
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.15
			cylinder.bottom_radius = 0.15
			cylinder.height = 0.13
			cylinder.radial_segments = 12
			wheel.mesh = cylinder
			wheel.rotation_degrees = Vector3(0, 0, 90)
			wheel.position = Vector3(side * 0.44, 0.02, z_pos)
			wheel.material_override = _material(Color(0.025, 0.03, 0.04, 1), 0.0, 0.78)
			visual_root.add_child(wheel)

	for x_value in [-0.22, 0.22]:
		var x_pos := float(x_value)
		_box(Vector3(0.13, 0.09, 0.045), Vector3(x_pos, 0.22, full_length * 0.5 + 0.02), Color(1.0, 0.90, 0.56, 1), 2.0)
		_box(Vector3(0.12, 0.09, 0.045), Vector3(x_pos, 0.22, -full_length * 0.5 - 0.02), Color(1.0, 0.10, 0.22, 1), 1.7)

	selection_marker = MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.92, 0.035, full_length + 0.12)
	selection_marker.mesh = marker_mesh
	selection_marker.position = Vector3(0, 0.015, 0)
	selection_marker.material_override = _material(Color(1.0, 0.82, 0.20, 0.82), 1.8, 0.30, true)
	selection_marker.visible = false
	visual_root.add_child(selection_marker)

	if is_target:
		_box(Vector3(0.34, 0.08, 0.34), Vector3(0, 0.69, 0), Color(1.0, 0.76, 0.18, 1), 2.6)

func _build_pickers() -> void:
	_clear_children(picker_root)
	var full_length: float = float(length_cells) * cell_size * 0.84
	var body_area := Area3D.new()
	body_area.collision_layer = BODY_LAYER
	body_area.collision_mask = 0
	body_area.input_ray_pickable = true
	body_area.set_meta("car_id", car_id)
	body_area.position = Vector3(0, 0.30, 0)
	var body_shape_node := CollisionShape3D.new()
	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(0.96, 1.00, float(max(0.72, full_length * 0.72)))
	body_shape_node.shape = body_shape
	body_area.add_child(body_shape_node)
	picker_root.add_child(body_area)

	var picker_depth: float = float(min(cell_size * 0.42, full_length * 0.28))
	var picker_center: float = float(max(0.16, full_length * 0.5 - picker_depth * 0.5))
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
	shape.size = Vector3(1.00, 1.08, float(max(0.22, picker_depth)))
	shape_node.shape = shape
	area.add_child(shape_node)
	picker_root.add_child(area)

func _orient_to_axis() -> void:
	rotation = Vector3.ZERO
	if axis.x != 0:
		rotation_degrees.y = 90.0

func animate_to(world_position: Vector3, duration: float = 0.15) -> void:
	busy = true
	var rest_scale: Vector3 = Vector3(1.045, 1.045, 1.045) if selected else Vector3.ONE
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", world_position, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector3(1.08, 0.96, 1.08), duration * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", rest_scale, duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_move)

func blocked_feedback(sign: int) -> void:
	var start: Vector3 = position
	var local_direction := Vector3(0, 0, float(sign))
	var world_direction: Vector3 = global_transform.basis * local_direction
	var nudge: Vector3 = world_direction.normalized() * 0.055
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", start + nudge, 0.035)
	tween.tween_property(self, "position", start - nudge, 0.045)
	tween.tween_property(self, "position", start, 0.035)

func animate_exit(world_direction: Vector3, distance: float) -> void:
	busy = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", position + world_direction.normalized() * distance, 0.48).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", Vector3(0.18, 0.18, 0.18), 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_hide_after_exit)

func _finish_move() -> void:
	busy = false

func _hide_after_exit() -> void:
	visible = false
	busy = false

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.free()

func _box(box_size: Vector3, local_pos: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	item.mesh = mesh
	item.position = local_pos
	item.material_override = _material(color, emission)
	visual_root.add_child(item)
	return item

func _material(color: Color, emission_strength: float = 0.0, roughness: float = 0.38, transparent: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = 0.05
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
