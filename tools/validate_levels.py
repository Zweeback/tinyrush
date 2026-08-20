#!/usr/bin/env python3
"""Dependency-free structural validation + optimal BFS verification for Parking Panic levels."""
from __future__ import annotations

from collections import deque
from dataclasses import dataclass
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / "data/levels/index.json"
VALID_AXES = {(1, 0), (0, 1)}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def as_cell(value) -> tuple[int, int] | None:
    if not isinstance(value, list) or len(value) < 2:
        return None
    try:
        return int(value[0]), int(value[1])
    except (TypeError, ValueError):
        return None


def validate_structure(level: dict) -> list[str]:
    errors: list[str] = []
    bounds = as_cell(level.get("bounds"))
    if bounds is None or bounds[0] <= 0 or bounds[1] <= 0:
        return ["bounds must be two positive integers"]
    width, height = bounds

    def inside(cell: tuple[int, int]) -> bool:
        return 0 <= cell[0] < width and 0 <= cell[1] < height

    static: set[tuple[int, int]] = set()
    for raw in level.get("static_cells", []):
        cell = as_cell(raw)
        if cell is None:
            errors.append("static cell must contain two integers")
            continue
        if not inside(cell):
            errors.append(f"static cell {cell} out of bounds")
        if cell in static:
            errors.append(f"duplicate static cell {cell}")
        static.add(cell)

    landmark_seen: set[tuple[int, int]] = set()
    for raw in level.get("landmark_cells", []):
        cell = as_cell(raw)
        if cell is None:
            errors.append("landmark cell must contain two integers")
            continue
        if not inside(cell):
            errors.append(f"landmark cell {cell} out of bounds")
        if cell not in static:
            errors.append(f"landmark cell {cell} must also be static")
        if cell in landmark_seen:
            errors.append(f"duplicate landmark cell {cell}")
        landmark_seen.add(cell)

    cars_raw = level.get("cars", [])
    if not isinstance(cars_raw, list) or not cars_raw:
        return errors + ["level has no cars"]

    ids: set[str] = set()
    occupied: dict[tuple[int, int], str] = {}
    target_flags: list[str] = []
    specs: dict[str, dict] = {}
    for car in cars_raw:
        if not isinstance(car, dict):
            errors.append("car entry must be an object")
            continue
        cid = str(car.get("id", "")).strip()
        if not cid:
            errors.append("car id must not be empty")
            continue
        if cid in ids:
            errors.append(f"duplicate car id {cid}")
            continue
        ids.add(cid)

        pos = as_cell(car.get("pos"))
        axis = as_cell(car.get("axis"))
        try:
            length = int(car.get("len", 0))
        except (TypeError, ValueError):
            length = 0
        if pos is None:
            errors.append(f"{cid}: invalid pos")
            pos = (0, 0)
        if axis not in VALID_AXES:
            errors.append(f"{cid}: invalid axis {axis}")
        if length < 1:
            errors.append(f"{cid}: length must be at least 1")
        if bool(car.get("target", False)):
            target_flags.append(cid)
        specs[cid] = {"pos": pos, "axis": axis, "len": length}

        if axis in VALID_AXES and length >= 1:
            for i in range(length):
                cell = (pos[0] + axis[0] * i, pos[1] + axis[1] * i)
                if not inside(cell):
                    errors.append(f"{cid}: out of bounds {cell}")
                if cell in static:
                    errors.append(f"{cid}: overlaps static {cell}")
                if cell in occupied:
                    errors.append(f"{cid}: overlaps {occupied[cell]} at {cell}")
                else:
                    occupied[cell] = cid

    exit_data = level.get("exit", {})
    if not isinstance(exit_data, dict):
        errors.append("exit must be an object")
        return errors
    target = str(exit_data.get("target", "")).strip()
    axis = as_cell(exit_data.get("axis"))
    try:
        sign = int(exit_data.get("sign", 0))
        row = int(exit_data.get("row", -1))
    except (TypeError, ValueError):
        sign, row = 0, -1
    if not target or target not in ids:
        errors.append("exit target is missing")
    if axis not in VALID_AXES:
        errors.append("exit axis must be [1,0] or [0,1]")
    if sign not in {-1, 1}:
        errors.append("exit sign must be -1 or 1")
    if axis == (1, 0) and not 0 <= row < height:
        errors.append("exit row outside board height")
    if axis == (0, 1) and not 0 <= row < width:
        errors.append("exit row outside board width")
    if len(target_flags) != 1:
        errors.append("exactly one car must have target=true")
    elif target and target_flags[0] != target:
        errors.append("target flag and exit target disagree")

    if target in specs and axis in VALID_AXES:
        spec = specs[target]
        if spec["axis"] != axis:
            errors.append("target car axis does not match exit axis")
        elif axis == (1, 0) and spec["pos"][1] != row:
            errors.append("target car is not aligned with exit row")
        elif axis == (0, 1) and spec["pos"][0] != row:
            errors.append("target car is not aligned with exit row")
    return errors


@dataclass(frozen=True)
class Puzzle:
    width: int
    height: int
    static: frozenset[tuple[int, int]]
    ids: tuple[str, ...]
    cars: dict[str, dict]
    exit_data: dict

    @classmethod
    def from_level(cls, level: dict) -> "Puzzle":
        width, height = map(int, level["bounds"])
        cars = {str(c["id"]): c for c in level["cars"]}
        return cls(
            width,
            height,
            frozenset(tuple(map(int, v)) for v in level.get("static_cells", [])),
            tuple(sorted(cars)),
            cars,
            level["exit"],
        )

    def start(self) -> tuple[tuple[int, int], ...]:
        return tuple(tuple(map(int, self.cars[cid]["pos"])) for cid in self.ids)

    def occupied(self, cid: str, pos: tuple[int, int]) -> tuple[tuple[int, int], ...]:
        car = self.cars[cid]
        ax = tuple(map(int, car["axis"]))
        return tuple((pos[0] + ax[0] * i, pos[1] + ax[1] * i) for i in range(int(car["len"])))

    def inside(self, cell: tuple[int, int]) -> bool:
        return 0 <= cell[0] < self.width and 0 <= cell[1] < self.height

    def can_place(self, cid: str, pos: tuple[int, int], state: tuple[tuple[int, int], ...]) -> bool:
        occupied_other: set[tuple[int, int]] = set()
        for idx, oid in enumerate(self.ids):
            if oid != cid:
                occupied_other.update(self.occupied(oid, state[idx]))
        for cell in self.occupied(cid, pos):
            if not self.inside(cell) or cell in self.static or cell in occupied_other:
                return False
        return True

    def can_exit(self, cid: str, sign: int, state: tuple[tuple[int, int], ...]) -> bool:
        e = self.exit_data
        if cid != e["target"] or sign != int(e["sign"]):
            return False
        car = self.cars[cid]
        axis = tuple(map(int, car["axis"]))
        required = tuple(map(int, e["axis"]))
        if axis != required:
            return False
        pos = state[self.ids.index(cid)]
        length = int(car["len"])
        row = int(e["row"])
        if required == (1, 0):
            return pos[1] == row and (pos[0] + length >= self.width if sign > 0 else pos[0] <= 0)
        if required == (0, 1):
            return pos[0] == row and (pos[1] + length >= self.height if sign > 0 else pos[1] <= 0)
        return False


def solve(level: dict, max_states: int = 250_000):
    puzzle = Puzzle.from_level(level)
    start = puzzle.start()
    q = deque([start])
    parent: dict[tuple, tuple | None] = {start: None}
    parent_move: dict[tuple, dict] = {}

    while q:
        if len(parent) >= max_states:
            return None, len(parent), True
        state = q.popleft()
        for idx, cid in enumerate(puzzle.ids):
            car = puzzle.cars[cid]
            axis = tuple(map(int, car["axis"]))
            for sign in (-1, 1):
                if puzzle.can_exit(cid, sign, state):
                    path: list[dict] = [{"id": cid, "sign": sign}]
                    cursor = state
                    while parent[cursor] is not None:
                        path.append(parent_move[cursor])
                        cursor = parent[cursor]
                    path.reverse()
                    return path, len(parent), False
                current = state[idx]
                nxt = (current[0] + axis[0] * sign, current[1] + axis[1] * sign)
                if not puzzle.can_place(cid, nxt, state):
                    continue
                ns = list(state)
                ns[idx] = nxt
                ns_tuple = tuple(ns)
                if ns_tuple in parent:
                    continue
                parent[ns_tuple] = state
                parent_move[ns_tuple] = {"id": cid, "sign": sign}
                q.append(ns_tuple)
    return None, len(parent), False


def replay_path(level: dict, path: list[dict]) -> tuple[bool, str]:
    puzzle = Puzzle.from_level(level)
    state = list(puzzle.start())
    for step_index, step in enumerate(path, start=1):
        cid = str(step.get("id", ""))
        try:
            sign = int(step.get("sign", 0))
        except (TypeError, ValueError):
            return False, f"step {step_index}: invalid sign"
        if cid not in puzzle.ids or sign not in {-1, 1}:
            return False, f"step {step_index}: invalid move {cid}/{sign}"
        state_tuple = tuple(state)
        if puzzle.can_exit(cid, sign, state_tuple):
            if step_index != len(path):
                return False, f"step {step_index}: exit occurs before end of path"
            return True, "ok"
        idx = puzzle.ids.index(cid)
        axis = tuple(map(int, puzzle.cars[cid]["axis"]))
        nxt = (state[idx][0] + axis[0] * sign, state[idx][1] + axis[1] * sign)
        if not puzzle.can_place(cid, nxt, state_tuple):
            return False, f"step {step_index}: blocked move {cid}/{sign}"
        state[idx] = nxt
    return False, "path ended without exit"


def main() -> None:
    index = load(INDEX)
    levels = index.get("levels", [])
    failures = 0
    if not isinstance(levels, list) or not levels:
        raise SystemExit("FAIL level index contains no levels")
    if len(set(levels)) != len(levels):
        raise SystemExit("FAIL level index contains duplicate paths")

    for res_path in levels:
        rel = str(res_path).replace("res://", "")
        path = ROOT / rel
        if not path.is_file():
            failures += 1
            print(f"FAIL index entry missing: {res_path}")
            continue
        level = load(path)
        errors = validate_structure(level)
        solved_path, states, limit_hit = (None, 0, False) if errors else solve(level)
        expected = int(level.get("optimal_moves", -1))
        actual = -1 if solved_path is None else len(solved_path)
        declared_path = level.get("optimal_path", [])
        declared_ok, declared_reason = (False, "missing optimal_path")
        if isinstance(declared_path, list) and declared_path:
            declared_ok, declared_reason = replay_path(level, declared_path)

        level_failures: list[str] = list(errors)
        if limit_hit:
            level_failures.append("solver state limit reached")
        if actual != expected:
            level_failures.append(f"optimal_moves expected={expected} solver={actual}")
        if not declared_ok:
            level_failures.append(f"optimal_path invalid: {declared_reason}")
        elif len(declared_path) != expected:
            level_failures.append(f"optimal_path length={len(declared_path)} expected={expected}")

        if level_failures:
            failures += 1
            print(f"FAIL {level.get('id', rel)}: {'; '.join(level_failures)} states={states}")
        else:
            print(f"PASS {level['id']}: optimal={actual} states={states} path=replayed")

    if failures:
        raise SystemExit(1)
    print(f"PASS all {len(levels)} levels: schema + BFS + declared optimal paths")


if __name__ == "__main__":
    main()
