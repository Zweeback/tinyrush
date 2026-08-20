#!/usr/bin/env python3
"""Negative tests for the dependency-free level validator."""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path

from validate_levels import replay_path, validate_structure

ROOT = Path(__file__).resolve().parents[1]
BASE = json.loads((ROOT / "data/levels/paris_01.json").read_text(encoding="utf-8"))


def expect_error(mutator, needle: str) -> None:
    level = deepcopy(BASE)
    mutator(level)
    errors = validate_structure(level)
    if not any(needle in error for error in errors):
        raise AssertionError(f"expected error containing {needle!r}; got {errors!r}")


def main() -> None:
    expect_error(lambda level: level["cars"][0].update(axis=[1, 1]), "invalid axis")
    expect_error(lambda level: level["cars"][1].update(id="hero"), "duplicate car id")
    expect_error(lambda level: level["exit"].update(target="blue"), "target flag and exit target disagree")
    expect_error(lambda level: level.update(landmark_cells=[[0, 0]]), "must also be static")
    expect_error(lambda level: level["cars"][0].update(len=0), "length must be at least 1")

    broken_path = deepcopy(BASE["optimal_path"])
    broken_path[0] = {"id": "hero", "sign": -1}
    ok, reason = replay_path(BASE, broken_path)
    if ok:
        raise AssertionError("blocked declared path was accepted")
    if not reason:
        raise AssertionError("broken path did not return a diagnostic")

    print("PASS validator negative tests")


if __name__ == "__main__":
    main()
