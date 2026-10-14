#!/usr/bin/env python3
import re
import sys
from pathlib import Path

src = Path(__file__).resolve().parents[1] / "Database/AzerothCore/AzerothCoreQuestCorrections.lua"
if not src.exists():
    print('ERROR: file not found:', src)
    raise SystemExit(1)

pattern = re.compile(r'\[questKeys\.specialFlags\]\s*=\s*(\d+)\s*,')
matches = []
counts = {}

with src.open(encoding='utf-8') as f:
    for i, line in enumerate(f, 1):
        m = pattern.search(line)
        if m:
            val = int(m.group(1))
            matches.append((i, val, line.rstrip()))
            counts[val] = counts.get(val, 0) + 1

print('Total numeric specialFlags matches in original file:', len(matches))
if counts:
    print('\nUnique numeric values and counts:')
    for val, cnt in sorted(counts.items()):
        print(f' {val}: {cnt}')

    print('\nFirst 20 matches:')
    for ln, val, txt in matches[:20]:
        print(f' {ln}: {val} -> {txt}')
else:
    print('No numeric specialFlags found in original file.')
