#!/usr/bin/env python3
"""Round-trip generated Lua base tables against the complete baseline snapshot."""
import argparse
import gzip
import json
from pathlib import Path
import subprocess
import sys

DATA_SECTIONS={'itemData','npcData','objectData','questData'}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--snapshot',required=True,type=Path)
    p.add_argument('--base-dir',required=True,type=Path)
    p.add_argument('--lua',required=True,help='Lua interpreter; LuaTeX users may pass luatex with --luaonly flag')
    p.add_argument('--luaonly',action='store_true',help='Pass --luaonly (for LuaTeX)')
    args=p.parse_args()
    root=Path(__file__).resolve().parent
    source=gzip.open if str(args.snapshot).endswith('.gz') else open
    baseline={}
    with source(args.snapshot,'rt',encoding='utf-8') as stream:
        next(stream)
        for line in stream:
            record=json.loads(line)
            if record.get('context')=='Alliance/isle-1' and record.get('section') in DATA_SECTIONS:
                baseline[(record['section'], record['id'])]=record['value']
    cmd=[args.lua]+(['--luaonly'] if args.luaonly else [])+[str(root/'verify_generated.lua'),str(args.base_dir)]
    n=0
    with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,text=True,encoding='utf-8') as child:
        for line in child.stdout:
            record=json.loads(line)
            key=record['section'],record['id']
            if key not in baseline:
                child.kill()
                raise ValueError(f'Unexpected base record {key}')
            if record['value'] != baseline.pop(key):
                child.kill()
                raise ValueError(f'Field mismatch in {key}')
            n+=1
        stderr=child.stderr.read()
        code=child.wait()
        if code:raise RuntimeError(f'Lua exited with status {code}: {stderr}')
    if baseline:raise ValueError(f'Missing {len(baseline)} baseline records, e.g. {next(iter(baseline))}')
    print(f'PASS: {n} records exactly match the baseline, including nested typed keys')

if __name__=='__main__':
    try:main()
    except (ValueError,RuntimeError) as e:
        print('FAIL: '+str(e),file=sys.stderr)
        raise SystemExit(1)
