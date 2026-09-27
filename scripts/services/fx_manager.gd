class_name ParkingPanicFX
extends Node

var fx_root: Node3D
var orbit_rig: Node3D

func configure(target_fx_root: Node3D, target_orbit_rig: Node3D) -> void:
	fx_root = target_fx_root
	orbit_rig = target_orbit_rig

func burst(origin: Vector3, color: Color, count: int, radius: float) -> void:
	if fx_root == null:
		return
	for i in range(count):
		var bit := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.022 + float(i % 3) * 0.009
		mesh.height = mesh.radius * 2.0
		bit.mesh = mesh
		bit.position = origin
		bit.material_override = _material(color.lightened(float(i % 4) * 0.06), 1.6, 0.42)
		fx_root.add_child(bit)
		var theta: float = TAU * float(i) / float(max(1.0, float(count)))
		var direction: Vector3 = Vector3(cos(theta), 0.45 + float(i % 4) * 0.12, sin(theta)).normalized()
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(bit, "position", origin + direction * radius * (0.72 + float(i % 3) * 0.14), 0.25)
		tween.parallel().tween_property(bit, "scale", Vector3.ZERO, 0.28)
		tween.tween_callback(bit.queue_free)

func speed_trail(origin: Vector3, direction: Vector3, color: Color, strength: int = 1) -> void:
	if fx_root == null:
		return
	var dir := direction.normalized()
	var side := Vector3(-dir.z, 0.0, dir.x)
	var streak_count := mini(12, 4 + strength * 2)
	for i in range(streak_count):
		var streak := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.055, 0.028, 0.44 + float(i % 3) * 0.16)
		streak.mesh = mesh
		var lateral := (float(i % 5) - 2.0) * 0.10
		streak.position = origin - dir * (0.22 + float(i) * 0.055) + side * lateral + Vector3.UP * (0.13 + float(i % 2) * 0.05)
		streak.rotation.y = atan2(dir.x, dir.z)
		streak.material_override = _material(color.lightened(float(i % 3) * 0.08), 2.0, 0.22)
		fx_root.add_child(streak)
		var tween := create_tween()
		tween.tween_property(streak, "position", streak.position - dir * (0.70 + float(strength) * 0.10), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(streak, "scale", Vector3(0.25, 0.25, 1.8), 0.18)
		tween.tween_property(streak, "scale", Vector3.ZERO, 0.10)
		tween.tween_callback(streak.queue_free)

func impact_star(origin: Vector3, color: Color, strength: int = 1) -> void:
	if fx_root == null:
		return
	var spoke_count := mini(14, 8 + strength)
	for i in range(spoke_count):
		var spoke := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.045, 0.028, 0.42 + float(strength) * 0.035)
		spoke.mesh = mesh
		var angle := TAU * float(i) / float(spoke_count)
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		spoke.position = origin + Vector3.UP * 0.06
		spoke.rotation.y = angle
		spoke.scale = Vector3(0.35, 0.35, 0.35)
		spoke.material_override = _material(color.lightened(float(i % 3) * 0.08), 2.8, 0.18)
		fx_root.add_child(spoke)
		var tween := create_tween()
		tween.tween_property(spoke, "position", spoke.position + dir * (0.46 + float(strength) * 0.055), 0.16).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(spoke, "scale", Vector3(1.0, 0.35, 1.8), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(spoke, "scale", Vector3.ZERO, 0.10)
		tween.tween_callback(spoke.queue_free)

func combo_camera_kick(power: int) -> void:
	if orbit_rig == null:
		return
	var base := orbit_rig.position
	var amount := minf(0.08, 0.025 + float(power) * 0.004)
	var tween := create_tween()
	tween.tween_property(orbit_rig, "position", base + Vector3(amount, amount * 0.65, 0), 0.028)
	tween.tween_property(orbit_rig, "position", base - Vector3(amount * 0.55, amount * 0.35, 0), 0.036)
	tween.tween_property(orbit_rig, "position", base, 0.055)

func camera_kick() -> void:
	if orbit_rig == null:
		return
	var base: Vector3 = orbit_rig.position
	var tween: Tween = create_tween()
	tween.tween_property(orbit_rig, "position", base + Vector3(0.025, 0.018, 0), 0.035)
	tween.tween_property(orbit_rig, "position", base, 0.060)

func _material(color: Color, emission_strength: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if emission_strength > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_strength
	return mat
