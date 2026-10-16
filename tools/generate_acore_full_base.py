#!/usr/bin/env python3
"""Stage complete Questie 3.3.5 static DBs from a verified effective-data snapshot.

Migration / provenance tool, NOT a replacement for independently regenerating
AzerothCore source data. The input snapshot includes inherited/manual Questie
values, and source confidence cannot be inferred from it. Never install the
output as a live addon without the correction-loader migration and full parity
checks. Only four STATIC data tables are converted, not dynamic overrides.

Usage:
 python tools/generate_acore_full_base.py --snapshot tools/reports/db-before.jsonl.gz \\
     --v5-zip tools/reports/acore-base-candidates-v5.zip \\
     --output tools/reports/acore-full-base
"""
from __future__ import annotations
import argparse
import collections
import gzip
import hashlib
import json
import math
from pathlib import Path
import re
import tempfile
import zipfile

KINDS = {"itemData": "item", "npcData": "npc", "objectData": "object", "questData": "quest"}
FILES = {"item": "acoreItemDB.lua", "npc": "acoreNpcDB.lua", "object": "acoreObjectDB.lua", "quest": "acoreQuestDB.lua"}
CONTEXTS = ["Alliance/isle-1", "Alliance/isle-9", "Horde/isle-1", "Horde/isle-9"]
BASELINE_CONTEXT = CONTEXTS[0]


def open_snapshot(path):
    return gzip.open(path, "rt", encoding="utf-8") if str(path).endswith(".gz") else open(path, "rt", encoding="utf-8")


def read_verified_snapshot(path, collect_schemas=False):
    """Validate the snapshot's checksum, sorted keys and complete contexts."""
    with open_snapshot(path) as stream:
        header = json.loads(next(stream))
        if (header.get("kind"), header.get("format"), header.get("version")) != ("header", "questie-db-snapshot", 1):
            raise ValueError("Not a supported Questie snapshot")
        metadata = header["metadata"]
        if metadata.get("contexts") != CONTEXTS or metadata.get("scope") != "post-corrections-pre-localization-v1":
            raise ValueError("Unsupported contexts/scope: cannot assume static-data equivalence")
        schemas = collections.defaultdict(dict)
        counts = collections.Counter()
        digest = hashlib.sha256()
        previous = None
        seen = set()
        for line in stream:
            record = json.loads(line)
            if record.get("kind") == "footer":
                if record.get("records") != sum(counts.values()) or record.get("sha256") != digest.hexdigest():
                    raise ValueError("Truncated or corrupted snapshot: footer mismatch")
                if seen != set(CONTEXTS) or next(stream, None) is not None:
                    raise ValueError("Missing context or trailing snapshot data")
                if collect_schemas:
                    for kind in KINDS.values():
                        item = schemas.get(kind, {}).get("keys")
                        if not item or not all(k.startswith("s:") and type(v) is int for k,v in item.items()):
                            raise ValueError(f"Missing or invalid {kind} schema")
                        slots = sorted(item.values())
                        if slots != list(range(1,len(item)+1)):
                            raise ValueError(f"Sparse or duplicate schema slots in {kind}")
                    return metadata, schemas
                return metadata, counts
            ctx, section, entity_id = record["context"], record["section"], record["id"]
            key = (ctx, section, 0 if type(entity_id) is int else 1, entity_id)
            if ctx not in CONTEXTS or (previous is not None and key <= previous):
                raise ValueError("Unsorted, duplicate or invalid snapshot record")
            previous = key
            seen.add(ctx)
            digest.update(line.encode("utf-8"))
            counts[ctx] += 1
            if collect_schemas and ctx == BASELINE_CONTEXT and section.startswith("schemas/"):
                schemas[section.split("/",1)[1]][entity_id] = record["value"]
        raise ValueError("Missing snapshot footer")


def lua_quote(value):
    """Encode all characters safely in Lua 5.1 and later."""
    out=['"']
    for c in value:
        i=ord(c)
        if c=='\\':out.append('\\\\')
        elif c=='"':out.append('\\"')
        elif c=='\n':out.append('\\n')
        elif c=='\r':out.append('\\r')
        elif c=='\t':out.append('\\t')
        elif i<32 or i==127:out.append('\\%03d'%i)
        else:out.append(c)
    out.append('"')
    return ''.join(out)


def lua_value(value):
    kind=type(value)
    if kind is str:return lua_quote(value)
    if kind is bool:return 'true' if value else 'false'
    if kind is int:return str(value)
    if kind is float:
        if not math.isfinite(value):raise ValueError("Non-finite numeric value")
        return repr(value)
    if kind is dict:
        entries=[]
        for key, val in value.items():
            if key.startswith('n:'):
                numeric=key[2:]
                if not re.fullmatch(r'-?(?:0|[1-9]\d*)',numeric):raise ValueError('Unsupported table number key '+key)
                real=int(numeric)
                if real==0 and numeric!='0':raise ValueError('Ambiguous numeric key')
                entries.append(((0,real),f'[{real}]='+lua_value(val)))
            elif key.startswith('s:'):
                name=key[2:]
                entries.append(((1,name),'['+lua_quote(name)+']='+lua_value(val)))
            else:raise ValueError('Unsupported snapshot table key '+str(key))
        entries.sort(key=lambda pair:pair[0])
        return '{'+','.join(part for _,part in entries)+'}'
    raise TypeError(f"Unexpected value type {kind}")


def row_to_lua(record, keys):
    if not isinstance(record,dict):raise ValueError('Invalid DB row')
    unknown=set(record)-set(keys)
    if unknown:raise ValueError('Unknown named fields: '+repr(unknown))
    top=max((keys[k] for k in record), default=0)
    values=['nil']*top
    for field, val in record.items():values[keys[field]-1]=lua_value(val)
    return '{'+','.join(values)+'}'


def read_v5_metadata(path):
    with zipfile.ZipFile(path) as archive:
        hits=[n for n in archive.namelist() if n.endswith('missing_record_migration_report.json')]
        if len(hits)!=1:raise ValueError('v5 migration report missing or ambiguous')
        report=json.loads(archive.read(hits[0]))
        if report.get('stage')!='AC-source-new-record-candidates-only' or not report.get('v4_source_revision_verified'):
            raise ValueError('v5 source verification metadata is invalid')
        staged_ids = {}
        for kind in FILES:
            matches=[n for n in archive.namelist() if n.endswith('/wotlk'+kind.capitalize()+'DB.lua')]
            if len(matches)!=1:raise ValueError('Missing staged '+kind+' base in v5')
            staged_ids[kind]={int(v) for v in re.findall(r'(?m)^\[(\d+)\]\s*=\s*\{',archive.read(matches[0]).decode('utf-8'))}
            if len(staged_ids[kind])<100:raise ValueError('Too few staged '+kind+' records in v5')
        return report, staged_ids


def generate(snapshot, v5zip, output):
    metadata,schemas=read_verified_snapshot(snapshot, True)
    v5, staged_ids=read_v5_metadata(v5zip)
    output.mkdir(parents=True,exist_ok=True)
    keys={kind:details['keys'] for kind,details in schemas.items()}
    counts=collections.Counter()
    digests={}
    final_paths={}
    records={}
    snapshot_ids=collections.defaultdict(set)
    # Use a fresh temporary directory and replace outputs only after ALL validation.
    with tempfile.TemporaryDirectory(prefix='acore-full-',dir=output) as temp:
        temp=Path(temp)
        handles={kind: (temp/FILES[kind]).open('w',encoding='utf-8',newline='\n') for kind in FILES}
        try:
            for kind, stream in handles.items():
                stream.write('-- GENERATED MIGRATION CANDIDATE: Questie effective static DB, not independent AC truth.\n')
                stream.write('-- DO NOT INSTALL until correction migration, source review and parity checks pass.\n')
                stream.write('local QuestieDB = QuestieLoader:ImportModule("QuestieDB")\n\n')
                stream.write(f'QuestieDB.{kind}Keys = {{\n')
                for field,index in sorted(keys[kind].items(),key=lambda pair: pair[1]):
                    stream.write(f'    [{lua_quote(field[2:])}] = {index},\n')
                stream.write('}\n\n')
                # Use explicit Lua long bracket delimiter that cannot collide with data.
                # The produced rows contain only JSON-derived typed scalars/tables.
                stream.write(f'QuestieDB.{kind}Data = [====[return {{\n')
            for context in CONTEXTS:
                with open_snapshot(snapshot) as stream:
                    next(stream)
                    for line in stream:
                        rec=json.loads(line)
                        if rec.get('kind')=='footer':break
                        if rec['context'] != context or rec['section'] not in KINDS:continue
                        section=rec['section'];kind=KINDS[section];id_=rec['id']
                        if type(id_) is not int:raise ValueError(f'Non-numeric {section} ID')
                        line_out=f'[{id_}]='+row_to_lua(rec['value'],keys[kind])+'\n'
                        if context==BASELINE_CONTEXT:
                            handles[kind].write(line_out[:-1]+',\n')
                            counts[kind]+=1
                            snapshot_ids[kind].add(id_)
                            digests[(kind,id_)]=hashlib.sha256(line_out.encode('utf-8')).digest()
                        elif digests.get((kind,id_)) != hashlib.sha256(line_out.encode('utf-8')).digest():
                            raise ValueError(f'Inconsistent static {kind} record {id_} across {context}')
                        if context==CONTEXTS[-1]:records[kind]=records.get(kind,0)+1
            for kind,stream in handles.items():
                if counts[kind]<100 or records.get(kind)!=counts[kind]:
                    raise ValueError(f'Incomplete {kind} data: {counts[kind]} / {records.get(kind)}')
                stream.write('}]====]\n')
        finally:
            for stream in handles.values():stream.close()
        for kind in FILES:
            content=(temp/FILES[kind]).read_text(encoding='utf-8')
            if ']====]' in content[:-7]:raise ValueError('Long-bracket delimiter collision!')
            final_paths[kind]=str(output/FILES[kind])
            (temp/FILES[kind]).replace(output/FILES[kind])
    for kind in FILES:
        missing=staged_ids[kind]-snapshot_ids[kind]
        if missing:raise ValueError(f'Staged v5 {kind} IDs missing from snapshot: {sorted(missing)[:20]}')
    new_ids={kind:sorted(snapshot_ids[kind]-staged_ids[kind]) for kind in FILES}
    report={
        'stage':'effective-snapshot-complete-base-staging',
        'warning':'NOT source-authoritative. Snapshot includes Questie inherited/manual corrections. Do not delete correction or runtime modules based solely on this result.',
        'snapshot_sha256':hashlib.sha256(snapshot.read_bytes()).hexdigest(),
        'snapshot_revision':metadata.get('git',{}),
        'source_revision_reference':v5['source_revision'],
        'v5_source_extraction_warnings':v5.get('source_extraction_warnings'),
        'v5_held_for_review':{kind:len(v5.get('review',{}).get(kind,[])) for kind in FILES},
        'v5_source_backed_new_records':{kind:len(v5.get('added',{}).get(kind,[])) for kind in FILES},
        'records':dict(counts),
        'v5_staged_records':{kind:len(staged_ids[kind]) for kind in FILES},
        'runtime_records_not_in_v5_stage':new_ids,
        'runtime_records_not_in_v5_stage_count':{kind:len(new_ids[kind]) for kind in FILES},
        'schemas':{kind:len(keys[kind]) for kind in FILES},
        'output_files':{kind:{'name':FILES[kind], 'sha256':hashlib.sha256((output/FILES[kind]).read_bytes()).hexdigest()} for kind in FILES},
    }
    (output/'migration_report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    return report


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--snapshot',required=True,type=Path)
    parser.add_argument('--v5-zip',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    report=generate(args.snapshot,args.v5_zip,args.output)
    print('Generated:',report['records'])
    print('V5 held for review:',report['v5_held_for_review'])
    print('STAGING ONLY. Preserve original base, all correction files and runtime loaders.')

if __name__=='__main__':main()
