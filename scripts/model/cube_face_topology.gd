class_name CubeFaceTopology
extends RefCounted

const FACES := ["top", "front", "right", "back", "left", "bottom"]
const CARDINAL_DIRECTIONS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static func wrap_pose(face: String, pos: Vector2i, axis: Vector2i, direction: Vector2i, length_cells: int, bounds: Vector2i) -> Dictionary:
	var old_frame := face_frame(face)
	if old_frame.is_empty() or direction not in CARDINAL_DIRECTIONS:
		return {}
	if bounds.x <= 0 or bounds.y <= 0 or length_cells < 1:
		return {}

	var expected_axis := Vector2i(absi(direction.x), absi(direction.y))
	if axis != expected_axis:
		return {}
	for i in range(length_cells):
		var source_cell := pos + axis * i
		if source_cell.x < 0 or source_cell.x >= bounds.x or source_cell.y < 0 or source_cell.y >= bounds.y:
			return {}

	var move_world: Vector3i = old_frame["u"] * direction.x + old_frame["v"] * direction.y
	var next_face := face_for_normal(move_world)
	var next_frame := face_frame(next_face)
	if next_frame.is_empty():
		return {}

	var next_world_direction: Vector3i = -old_frame["n"]
	var next_direction := Vector2i(
		_dot(next_world_direction, next_frame["u"]),
		_dot(next_world_direction, next_frame["v"])
	)
	var next_axis := Vector2i(absi(next_direction.x), absi(next_direction.y))

	var seam_index := pos.y if direction.x != 0 else pos.x
	var seam_world: Vector3i = old_frame["v"] if direction.x != 0 else old_frame["u"]
	var next_perpendicular: Vector3i = next_frame["v"] if next_direction.x != 0 else next_frame["u"]
	var target_span := bounds.y if next_direction.x != 0 else bounds.x
	var mapped_index := seam_index if _dot(seam_world, next_perpendicular) > 0 else target_span - 1 - seam_index

	var next_pos := Vector2i.ZERO
	if next_direction.x != 0:
		next_pos.x = 0 if next_direction.x > 0 else bounds.x - length_cells
		next_pos.y = mapped_index
	else:
		next_pos.x = mapped_index
		next_pos.y = 0 if next_direction.y > 0 else bounds.y - length_cells

	return {
		"from_face": face,
		"to_face": next_face,
		"pos": next_pos,
		"axis": next_axis,
		"escape_dir": next_direction,
	}

static func face_for_normal(normal: Vector3i) -> String:
	for face in FACES:
		if face_frame(face).get("n", Vector3i.ZERO) == normal:
			return face
	return ""

static func face_frame(face: String) -> Dictionary:
	match face:
		"top":
			return {"u": Vector3i(1, 0, 0), "v": Vector3i(0, 0, 1), "n": Vector3i(0, 1, 0)}
		"front":
			return {"u": Vector3i(1, 0, 0), "v": Vector3i(0, -1, 0), "n": Vector3i(0, 0, 1)}
		"right":
			return {"u": Vector3i(0, 0, -1), "v": Vector3i(0, -1, 0), "n": Vector3i(1, 0, 0)}
		"back":
			return {"u": Vector3i(-1, 0, 0), "v": Vector3i(0, -1, 0), "n": Vector3i(0, 0, -1)}
		"left":
			return {"u": Vector3i(0, 0, 1), "v": Vector3i(0, -1, 0), "n": Vector3i(-1, 0, 0)}
		"bottom":
			return {"u": Vector3i(1, 0, 0), "v": Vector3i(0, 0, -1), "n": Vector3i(0, -1, 0)}
	return {}

static func _dot(a: Vector3i, b: Vector3i) -> int:
	return a.x * b.x + a.y * b.y + a.z * b.z
