"""Bounded C++ proofs linking quest events to registered NPC/object actors.

These relationships provide event tooltips, never map coordinates. Unsupported
expressions remain review gaps rather than guessed quest or actor identities.
"""
from collections import defaultdict
from pathlib import Path
import re


def source_files(source_root):
    directory = Path(source_root) / "src/server/scripts"
    if not directory.is_dir():
        raise ValueError("Missing AC scripts directory for C++ quest event evidence")
    return sorted((path for path in directory.rglob("*")
                   if path.is_file() and path.suffix.lower() in (".cpp", ".h", ".hpp")),
                  key=lambda path: path.as_posix().lower())


def _mask(text, strings=True):
    """Preserve offsets while hiding comments and optionally quoted literals."""
    pattern = r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\''
    def replace(match):
        value = match.group()
        if not strings and value[0] in ('"', "'"):
            return value
        return ''.join('\n' if char == '\n' else ' ' for char in value)
    return re.sub(pattern, replace, text, flags=re.S)


def _close(masked, start, opening='{', closing='}'):
    depth = 0
    for index in range(start, len(masked)):
        depth += (masked[index] == opening) - (masked[index] == closing)
        if depth == 0:
            return index
    raise ValueError("Unbalanced C++ event source")


def _classes(masked):
    result = []
    pattern = r'\b(?:class|struct)\s+(\w+)\s*(?:final\s*)?(?::[^;{}]+)?\s*\{'
    for match in re.finditer(pattern, masked):
        if re.search(r'\benum\s*$', masked[max(0, match.start()-12):match.start()]):
            continue
        start = match.end()-1
        result.append({'name': match[1], 'start': match.start(), 'open': start,
                       'end': _close(masked, start), 'declaration': match.group()})
    return result


def _constants(masked, classes):
    definitions = defaultdict(list)
    enum_pattern = r'\benum\s+(?:(?:class|struct)\s+)?(?:(\w+)\s*)?(?::[^;{}]+)?\s*\{'
    for match in re.finditer(enum_pattern, masked):
        start, end = match.end(), _close(masked, match.end()-1)
        parents = [row for row in classes if row['open'] < match.start() < row['end']]
        parent = min(parents, key=lambda row: row['end']-row['open']) if parents else None
        for value in masked[start:end].split(','):
            literal = re.fullmatch(r'\s*(\w+)\s*=\s*(\d+)[uUlL]*\s*', value)
            if not literal:
                continue
            name, number = literal[1], int(literal[2])
            definitions[name].append(number)
            if match[1]:
                definitions[match[1]+'::'+name].append(number)
            if parent:
                definitions[parent['name']+'::'+name].append(number)
    pattern = r'\bconstexpr\s+(?:std::)?(?:uint\d+(?:_t)?|int|unsigned(?:\s+int)?|auto)\s+(\w+)\s*=\s*(\d+)[uUlL]*\s*;'
    for match in re.finditer(pattern, masked):
        definitions[match[1]].append(int(match[2]))
    return definitions


def _quest_id(expression, constants, class_body):
    expression = re.sub(r'\s+', '', expression)
    if re.fullmatch(r'\d+[uUlL]*', expression):
        return int(expression.rstrip('uUlL')) or None
    if not re.fullmatch(r'\w+(?:::\w+)*', expression):
        return None
    values = constants.get(expression, [])
    if len(values) != 1 or values[0] < 1:
        return None
    if '::' not in expression:
        declarations = re.finditer(r'\b(?:uint\d+(?:_t)?|int|unsigned|auto)\s+(?:const\s+)?'
                                   + re.escape(expression) + r'\b', class_body)
        for declaration in declarations:
            prefix = class_body[max(0, declaration.start()-20):declaration.start()]
            if not re.search(r'\bconstexpr\s*$', prefix):
                return None
    return values[0]


def _factory_ais(masked, row):
    body = masked[row['open']+1:row['end']]
    result = set()
    for method in re.finditer(r'\bGetAI\s*\(', body):
        close = _close(body, method.end()-1, '(', ')')
        suffix = re.match(r'[^;{}]*\{', body[close+1:])
        if not suffix:
            continue
        start = close+1+suffix.end()-1
        method_body = body[start+1:_close(body, start)]
        result.update(re.findall(r'\breturn\s+new\s+(\w+)\s*\(', method_body))
        result.update(re.findall(r'\breturn\s+Get\w*AI\s*<\s*(\w+)\s*>\s*\(', method_body))
    return result


def _template_bindings(rows, kind):
    if isinstance(rows, dict):
        rows = ({'entry': key, **value} for key, value in rows.items())
    bindings = defaultdict(set)
    for row in rows:
        script = row.get('ScriptName')
        if script:
            bindings[script].add((kind, int(row['entry'])))
    return bindings


def _player_receiver(masked, owner, call_start):
    """Resolve a direct Player pointer in the active method/block scopes."""
    receiver = re.search(r'\b(\w+)\s*->\s*$', masked[owner['open']+1:call_start])
    if not receiver:
        return None
    name = receiver[1]
    blocks = []
    for match in re.finditer(r'\{', masked[owner['open']+1:call_start]):
        start = owner['open']+1+match.start()
        if _close(masked, start) >= call_start:
            blocks.append(start)
    if not blocks:
        return None
    method_open = blocks[0]
    start = max(masked.rfind(';', owner['open']+1, method_open),
                masked.rfind('}', owner['open']+1, method_open), owner['open'])+1
    declarations = []
    pattern = r'\b(Player|Creature|Unit|WorldObject|auto)\s*(?:const\s*)?\*?\s*' + re.escape(name) + r'\b'
    for declaration in re.finditer(pattern, masked[start:call_start]):
        position = start+declaration.start()
        closed_scope = any(block < position < _close(masked, block) < call_start
                           for block in range(start, position) if masked[block] == '{')
        if not closed_scope:
            declarations.append(declaration[1])
    return name if declarations and declarations[-1] == 'Player' else None


def collect(source_root, creature_templates, object_templates):
    root = Path(source_root)
    bindings = _template_bindings(creature_templates, 'monster')
    for script, actors in _template_bindings(object_templates, 'object').items():
        bindings[script].update(actors)
    events, evidence, unsupported = defaultdict(set), defaultdict(list), []
    if not bindings:
        return {'events': {}, 'evidence': {}, 'unsupported': []}
    for path in source_files(root):
        text = path.read_text(encoding='utf-8')
        if not any(call in text for call in ('GroupEventHappens', 'AreaExploredOrEventHappens', 'CompleteQuest')):
            continue
        masked, comments_removed = _mask(text), _mask(text, strings=False)
        relative = path.relative_to(root).as_posix()
        try:
            classes = _classes(masked)
            constants = _constants(masked, classes)
        except ValueError as error:
            unsupported.append({'file': relative, 'reason': str(error)})
            continue
        by_name = defaultdict(list)
        for row in classes:
            by_name[row['name']].append(row)
        owners = defaultdict(list)
        for row in classes:
            registrations = []
            for base, kind in (('CreatureScript', 'monster'), ('GameObjectScript', 'object')):
                if not re.search(r'\b'+base+r'\b', row['declaration']):
                    continue
                body = comments_removed[row['open']+1:row['end']]
                pattern = r'\b'+re.escape(row['name'])+r'\s*\([^;{}]*\)\s*:\s*'+base+r'\s*\(\s*"([^"\\]+)"\s*\)'
                registrations.extend((match[1], kind) for match in re.finditer(pattern, body))
            for macro, kind in (('RegisterCreatureAI', 'monster'), ('RegisterGameObjectAI', 'object')):
                if re.search(r'\b'+macro+r'\s*\(\s*'+re.escape(row['name'])+r'\s*\)', masked):
                    registrations.append((row['name'], kind))
            if len(by_name[row['name']]) != 1:
                continue
            owned = [row]
            for name in _factory_ais(masked, row):
                if len(by_name[name]) == 1:
                    owned.append(by_name[name][0])
            for script, kind in registrations:
                actors = [actor for actor in bindings.get(script, ()) if actor[0] == kind]
                for owner in owned:
                    for actor in actors:
                        owners[owner['start']].append((actor, script))
        calls = re.finditer(r'\b(GroupEventHappens|AreaExploredOrEventHappens|CompleteQuest)\s*\(', masked)
        for call in calls:
            parents = [row for row in classes if row['open'] < call.start() < row['end']]
            if not parents:
                continue
            owner = min(parents, key=lambda row: row['end']-row['open'])
            actual_owners = owners.get(owner['start'], [])
            if not actual_owners:
                continue
            try:
                end = _close(masked, call.end()-1, '(', ')')
            except ValueError:
                continue
            arguments = masked[call.end():end].split(',')
            quest = _quest_id(arguments[0], constants, masked[owner['open']+1:owner['end']]) if arguments else None
            valid_actor = ((call[1] == 'GroupEventHappens' and len(arguments) == 2
                            and arguments[1].strip() in ('me', 'm_creature'))
                           or (call[1] == 'AreaExploredOrEventHappens' and len(arguments) == 1))
            recipient = _player_receiver(masked, owner, call.start())
            if recipient:
                valid_actor |= (call[1] == 'CompleteQuest' and len(arguments) == 1)
                valid_actor |= (call[1] == 'GroupEventHappens' and len(arguments) == 2
                                and arguments[1].strip() == recipient)
            line = text.count('\n', 0, call.start())+1
            if quest is None or not valid_actor:
                unsupported.append({'file': relative, 'line': line, 'class': owner['name'],
                                    'reason': 'Dynamic/ambiguous quest or unrelated event actor',
                                    'expression': masked[call.end():end].strip()})
                continue
            for actor, script in actual_owners:
                events[str(quest)].add(actor)
                evidence[str(quest)].append({'actor': list(actor), 'file': relative, 'line': line,
                    'class': owner['name'], 'script': script, 'call': call[1]})
    return {'events': {key: [list(actor) for actor in sorted(actors)] for key, actors in sorted(events.items(), key=lambda row:int(row[0]))},
            'evidence': dict(evidence), 'unsupported': unsupported}
