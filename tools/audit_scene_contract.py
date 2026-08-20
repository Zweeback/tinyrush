#!/usr/bin/env python3
"""Static scene/script contract checks that do not require the Godot binary."""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SCENES = sorted((ROOT / "scenes").rglob("*.tscn"))

EXT_RE = re.compile(r'^\[ext_resource\s+type="Script"\s+path="([^"]+)"\s+id="([^"]+)"\]$')
NODE_RE = re.compile(r'^\[node\s+name="([^"]+)"\s+type="[^"]+"(?:\s+parent="([^"]+)")?\]$')
SCRIPT_RE = re.compile(r'^script\s*=\s*ExtResource\("([^"]+)"\)$')
DOLLAR_RE = re.compile(r'\$([A-Za-z0-9_./-]+)')


def res_path_to_file(res_path: str) -> Path:
    if not res_path.startswith("res://"):
        raise ValueError(res_path)
    return ROOT / res_path[6:]


def norm_join(base: str, child: str) -> str:
    parts = [p for p in (base + "/" + child).split("/") if p and p != "."]
    stack: list[str] = []
    for part in parts:
        if part == "..":
            if stack:
                stack.pop()
        else:
            stack.append(part)
    return "/".join(stack)


def audit_scene(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    scripts: dict[str, str] = {}
    nodes: set[str] = set()
    attached: list[tuple[str, str]] = []
    current_node: str | None = None
    root_name: str | None = None

    for raw in lines:
        line = raw.strip()
        ext = EXT_RE.match(line)
        if ext:
            scripts[ext.group(2)] = ext.group(1)
            continue
        node = NODE_RE.match(line)
        if node:
            name, parent = node.groups()
            if root_name is None:
                root_name = name
                current_node = ""
            else:
                parent_rel = "" if parent in (None, ".") else parent
                current_node = norm_join(parent_rel, name)
            nodes.add(current_node)
            continue
        script = SCRIPT_RE.match(line)
        if script and current_node is not None:
            attached.append((current_node, script.group(1)))

    errors: list[str] = []
    if root_name is None:
        return [f"{path.relative_to(ROOT)}: no root node"]

    for node_rel, script_id in attached:
        res_script = scripts.get(script_id)
        if not res_script:
            errors.append(f"{path.relative_to(ROOT)}: node {node_rel or root_name} references unknown script id {script_id}")
            continue
        script_file = res_path_to_file(res_script)
        if not script_file.is_file():
            errors.append(f"{path.relative_to(ROOT)}: missing attached script {res_script}")
            continue
        text = script_file.read_text(encoding="utf-8")
        for dollar_path in DOLLAR_RE.findall(text):
            target = norm_join(node_rel, dollar_path)
            if target not in nodes:
                errors.append(
                    f"{script_file.relative_to(ROOT)}: ${dollar_path} not found from scene node {node_rel or root_name} in {path.relative_to(ROOT)}"
                )
    return errors


def audit_class_names() -> list[str]:
    seen: dict[str, Path] = {}
    errors: list[str] = []
    pattern = re.compile(r'^class_name\s+([A-Za-z_][A-Za-z0-9_]*)\s*$', re.MULTILINE)
    for script in sorted((ROOT / "scripts").rglob("*.gd")):
        text = script.read_text(encoding="utf-8")
        for name in pattern.findall(text):
            if name in seen:
                errors.append(f"duplicate class_name {name}: {seen[name].relative_to(ROOT)} and {script.relative_to(ROOT)}")
            else:
                seen[name] = script
    return errors


def main() -> None:
    errors: list[str] = []
    for scene in SCENES:
        errors.extend(audit_scene(scene))
    errors.extend(audit_class_names())
    if errors:
        for error in errors:
            print("FAIL", error)
        raise SystemExit(1)
    print(f"PASS scene contracts: {len(SCENES)} scenes, node paths and class names")


if __name__ == "__main__":
    main()
