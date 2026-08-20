#!/usr/bin/env python3
from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[1]
missing=[]
for p in root.rglob('*'):
    if not p.is_file() or '.git' in p.parts: continue
    if p.suffix not in {'.gd','.tscn','.godot','.cfg','.json','.md'}: continue
    try: text=p.read_text(encoding='utf-8')
    except UnicodeDecodeError: continue
    for ref in re.findall(r'res://[A-Za-z0-9_./-]+', text):
        rel=ref[6:].rstrip('"\')],};')
        if rel and not (root/rel).exists(): missing.append((p.relative_to(root),ref))
if missing:
    for src,ref in missing: print('MISSING',src,ref)
    raise SystemExit(1)
print('PASS res:// audit')
