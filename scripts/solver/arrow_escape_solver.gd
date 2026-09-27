class_name ArrowEscapeSolver
extends RefCounted

func solve(board: ArrowEscapeBoard, max_states: int = 100000) -> Dictionary:
	var start: Dictionary = board.active_map()
	var start_key := board.state_key(start)
	var queue: Array[Dictionary] = [start]
	var queue_keys: Array[String] = [start_key]
	var head := 0
	var visited := {start_key: true}
	var parents := {}
	var parent_moves := {}

	while head < queue.size():
		if visited.size() >= max_states:
			return {"solved": false, "moves": -1, "path": [], "states_visited": visited.size(), "limit_reached": true}

		var state: Dictionary = queue[head]
		var key: String = queue_keys[head]
		head += 1

		if board.remaining_count(state) == 0:
			var path := _reconstruct_path(key, parents, parent_moves)
			return {"solved": true, "moves": path.size(), "path": path, "states_visited": visited.size(), "limit_reached": false}

		for step in board.legal_steps(state):
			var car_id := str(step.get("id", ""))
			var next_state := board.next_state_after_escape(state, car_id)
			var next_key := board.state_key(next_state)
			if visited.has(next_key):
				continue
			visited[next_key] = true
			parents[next_key] = key
			parent_moves[next_key] = {"id": car_id}
			queue.append(next_state)
			queue_keys.append(next_key)

	return {"solved": false, "moves": -1, "path": [], "states_visited": visited.size(), "limit_reached": false}

func _reconstruct_path(end_key: String, parents: Dictionary, parent_moves: Dictionary) -> Array:
	var reversed_path: Array = []
	var cursor := end_key
	while parents.has(cursor):
		reversed_path.append(parent_moves[cursor])
		cursor = str(parents[cursor])
	reversed_path.reverse()
	return reversed_path
