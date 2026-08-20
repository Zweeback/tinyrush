#!/usr/bin/env python3
"""Run every dependency-free Parking Panic preflight check."""
from __future__ import annotations

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CHECKS = [
    [sys.executable, "tools/validate_levels.py"],
    [sys.executable, "tools/test_validate_levels.py"],
    [sys.executable, "tools/audit_res_paths.py"],
    [sys.executable, "tools/audit_scene_contract.py"],
]


def main() -> None:
    for cmd in CHECKS:
        print("+", " ".join(cmd), flush=True)
        subprocess.run(cmd, cwd=ROOT, check=True)
    print("PASS: all dependency-free preflight checks")


if __name__ == "__main__":
    main()
