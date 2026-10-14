#!/usr/bin/env python3
import os, re, sys

ROOT = os.getcwd()

# Parse classKeys mapping from Database/QuestieDB.lua
questiedb = os.path.join(ROOT, 'Database', 'QuestieDB.lua')
if not os.path.isfile(questiedb):
    print('ERROR: QuestieDB.lua not found at', questiedb)
    sys.exit(1)

text = open(questiedb, 'r', encoding='utf-8').read()
start = text.find('QuestieDB.classKeys')
if start == -1:
    print('ERROR: classKeys block not found in QuestieDB.lua')
    sys.exit(1)

# Find the opening brace and collect lines until matching closing brace
brace_idx = text.find('{', start)
if brace_idx == -1:
    print('ERROR: opening brace for classKeys not found')
    sys.exit(1)

# Simple balanced-brace scan
i = brace_idx
depth = 0
end_idx = -1
while i < len(text):
    if text[i] == '{':
        depth += 1
    elif text[i] == '}':
        depth -= 1
        if depth == 0:
            end_idx = i
            break
    i += 1
if end_idx == -1:
    print('ERROR: could not find end of classKeys block')
    sys.exit(1)

block = text[brace_idx+1:end_idx]

mapping = {}
# Match lines like: NAME = 123,
for line in block.splitlines():
    m = re.match(r"\s*([A-Z0-9_]+)\s*=\s*([0-9]+)\s*,?", line)
    if m:
        name = m.group(1)
        val = int(m.group(2))
        mapping[name] = val

if not mapping:
    print('ERROR: no numeric class keys parsed')
    sys.exit(1)

# Prepare flags (only power-of-two values, excluding NONE=0)
flags = {k:v for k,v in mapping.items() if v and (v & (v-1)) == 0}
all_flags_sum = sum(flags.values())

# Files to scan: any .lua under ROOT containing 'local classIDs = QuestieDB.classKeys'
re_required = re.compile(r"\[questKeys\.requiredClasses\]\s*=\s*([0-9]+)")

modified_files = []

for dirpath, dirnames, filenames in os.walk(ROOT):
    for fname in filenames:
        if not fname.endswith('.lua'):
            continue
        path = os.path.join(dirpath, fname)
        try:
            with open(path, 'r', encoding='utf-8') as f:
                s = f.read()
        except Exception as e:
            print('SKIP', path, 'read error:', e)
            continue
        if 'local classIDs = QuestieDB.classKeys' not in s:
            continue
        # skip files already containing classIDs.* in requiredClasses lines (no numeric)
        matches = re_required.search(s)
        if not matches:
            continue
        new_s = s
        def repl(m):
            val = int(m.group(1))
            if val == 0:
                return '[questKeys.requiredClasses] = classIDs.NONE'
            # prefer ALL_CLASSES when all bits match
            if val == all_flags_sum:
                return '[questKeys.requiredClasses] = classIDs.ALL_CLASSES'
            parts = []
            rem = val
            # iterate flags descending for readability
            for name, fval in sorted(flags.items(), key=lambda x: -x[1]):
                if rem & fval:
                    parts.append('classIDs.' + name)
                    rem = rem & ~fval
            if rem != 0:
                # fallback to numeric literal if leftover bits
                return '[questKeys.requiredClasses] = %d' % val
            return '[questKeys.requiredClasses] = ' + ' + '.join(parts)

        new_s2 = re_required.sub(repl, new_s)
        if new_s2 != s:
            new_path = path + '.new'
            with open(new_path, 'w', encoding='utf-8') as f:
                f.write(new_s2)
            modified_files.append(new_path)
            print('WROTE', new_path)

print('\nDone. Modified %d file(s).' % len(modified_files))
if modified_files:
    for p in modified_files:
        print(' -', p)
else:
    print('No files changed.')
