class_name ParkingPanicSolver
extends RefCounted

# Two metrics deliberately coexist:
# - solve(): classic Rush Hour, one grid cell per move (level-design audit)
# - solve_slides(): Arrows-style, one tap slides maximally until blocked/exit (actual gameplay)
func solve(board: ParkingBoard, max_states: int = 250000) -> Dictionary:
	return _solve(board, false, max_states)

func solve_slides(board: ParkingBoard, max_states: int = 250000) -> Dictionary:
	return _solve(board, true, max_states)

func _solve(board: ParkingBoard, maximal_slides: bool, max_states: int) -> Dictionary:
	var start: Dictionary = board.clone_positions()
	var start_key := board.state_key(start)
	var queue: Array[Dictionary] = [start]
	var queue_keys: Array[String] = [start_key]
	var head := 0
	var visited: Dictionary = {start_key: true}
	var parents: Dictionary = {}
	var parent_moves: Dictionary = {}
	var peak_queue := 1

	while head < queue.size():
		if visited.size() >= max_states:
			return {
				"solved": false,
				"moves": -1,
				"states_visited": visited.size(),
				"peak_queue": peak_queue,
				"limit_reached": true,
				"path": [],
				"mode": "tap" if maximal_slides else "cell"
			}

		var state: Dictionary = queue[head]
		var state_key: String = queue_keys[head]
		head += 1
		var steps: Array[Dictionary] = board.legal_slides(state) if maximal_slides else board.legal_steps(state)

		for step in steps:
			var car_id := str(step.get("id", ""))
			var sign := int(step.get("sign", 0))
			var action := {
				"id": car_id,
				"sign": sign,
				"exit": bool(step.get("exit", false)),
				"cell_steps": int(step.get("cell_steps", 1))
			}
			if bool(step.get("exit", false)):
				var solved_path := _reconstruct_path(state_key, parents, parent_moves)
				solved_path.append(action)
				return {
					"solved": true,
					"moves": solved_path.size(),
					"states_visited": visited.size(),
					"peak_queue": peak_queue,
					"limit_reached": false,
					"path": solved_path,
					"mode": "tap" if maximal_slides else "cell"
				}

			var next_state := state.duplicate(true)
			var next_pos: Vector2i = step.get("to", Vector2i.ZERO)
			next_state[car_id] = next_pos
			var next_key := board.state_key(next_state)
			if visited.has(next_key):
				continue
			visited[next_key] = true
			parents[next_key] = state_key
			parent_moves[next_key] = action
			queue.append(next_state)
			queue_keys.append(next_key)
			peak_queue = max(peak_queue, queue.size() - head)

	return {
		"solved": false,
		"moves": -1,
		"states_visited": visited.size(),
		"peak_queue": peak_queue,
		"limit_reached": false,
		"path": [],
		"mode": "tap" if maximal_slides else "cell"
	}

func _reconstruct_path(end_key: String, parents: Dictionary, parent_moves: Dictionary) -> Array:
	var reversed_path: Array = []
	var cursor := end_key
	while parents.has(cursor):
		reversed_path.append(parent_moves[cursor])
		cursor = str(parents[cursor])
	reversed_path.reverse()
	return reversed_path
