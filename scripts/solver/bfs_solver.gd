class_name ParkingPanicSolver
extends RefCounted

# One grid-cell slide counts as one move, matching the actual game input.
# The queue stores states only; parent/move maps reconstruct the path on success.
# This avoids copying the whole path into every queued state.
func solve(board: ParkingBoard, max_states: int = 250000) -> Dictionary:
	var start := board.clone_positions()
	var start_key := board.state_key(start)
	var queue: Array[Dictionary] = [start]
	var queue_keys: Array[String] = [start_key]
	var head := 0
	var visited := {start_key: true}
	var parents := {}
	var parent_moves := {}
	var peak_queue := 1

	while head < queue.size():
		if visited.size() >= max_states:
			return {
				"solved": false,
				"moves": -1,
				"states_visited": visited.size(),
				"peak_queue": peak_queue,
				"limit_reached": true,
				"path": []
			}

		var state: Dictionary = queue[head]
		var state_key: String = queue_keys[head]
		head += 1

		for step in board.legal_steps(state):
			var car_id := str(step.get("id", ""))
			var sign := int(step.get("sign", 0))
			if bool(step.get("exit", false)):
				var solved_path := _reconstruct_path(state_key, parents, parent_moves)
				solved_path.append({"id": car_id, "sign": sign, "exit": true})
				return {
					"solved": true,
					"moves": solved_path.size(),
					"states_visited": visited.size(),
					"peak_queue": peak_queue,
					"limit_reached": false,
					"path": solved_path
				}

			var next_state := state.duplicate(true)
			var next_pos: Vector2i = step.get("to", Vector2i.ZERO)
			next_state[car_id] = next_pos
			var next_key := board.state_key(next_state)
			if visited.has(next_key):
				continue
			visited[next_key] = true
			parents[next_key] = state_key
			parent_moves[next_key] = {"id": car_id, "sign": sign, "exit": false}
			queue.append(next_state)
			queue_keys.append(next_key)
			peak_queue = max(peak_queue, queue.size() - head)

	return {
		"solved": false,
		"moves": -1,
		"states_visited": visited.size(),
		"peak_queue": peak_queue,
		"limit_reached": false,
		"path": []
	}

func _reconstruct_path(end_key: String, parents: Dictionary, parent_moves: Dictionary) -> Array:
	var reversed_path: Array = []
	var cursor := end_key
	while parents.has(cursor):
		reversed_path.append(parent_moves[cursor])
		cursor = str(parents[cursor])
	reversed_path.reverse()
	return reversed_path
