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
		var theta := TAU * float(i) / max(1.0, float(count))
		var direction := Vector3(cos(theta), 0.45 + float(i % 4) * 0.12, sin(theta)).normalized()
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(bit, "position", origin + direction * radius * (0.72 + float(i % 3) * 0.14), 0.25)
		tween.parallel().tween_property(bit, "scale", Vector3.ZERO, 0.28)
		tween.tween_callback(bit.queue_free)

func camera_kick() -> void:
	if orbit_rig == null:
		return
	var base := orbit_rig.position
	var tween := create_tween()
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
