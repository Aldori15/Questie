"""Bounded C++ proofs linking quest events to registered NPC/object actors.

Relationships and bounded completion-location evidence come from registered scripts.
Unsupported expressions remain review gaps rather than guessed identities or positions.
"""
from collections import defaultdict
import hashlib
import math
from pathlib import Path
import re


# Reviewed display zones for the fingerprinted Children's Week entry selector.
CHILD_DISPLAY_ZONES = {
    'NPC_CAVERNS_OF_TIME_CW_TRIGGER': (1, 440),
    'NPC_EXODAR_01_CW_TRIGGER': (530, 3557),
    'NPC_EXODAR_02_CW_TRIGGER': (530, 3557),
    'NPC_AERIS_LANDING_CW_TRIGGER': (530, 3518),
    'NPC_AUCHINDOUN_CW_TRIGGER': (530, 3519),
    'NPC_SPOREGGAR_CW_TRIGGER': (530, 3521),
    'NPC_THRONE_OF_ELEMENTS_CW_TRIGGER': (530, 3518),
    'NPC_SILVERMOON_01_CW_TRIGGER': (530, 3487),
}


# Changed state machines lose their location proof until reviewed again.
REVIEWED_ESCORTS = {
    ('src/server/scripts/Kalimdor/zone_the_barrens.cpp', 'npc_wizzlecrank_shredder'):
        ('6a51dd9d9a31e037fba86fe684ce5b71f92d15ca55dd63d67f72ef9f5902d65f',
         {'pointId': 24, 'requireLastPoint': True, 'minimumWaitMs': 16000}),
    ('src/server/scripts/Northrend/zone_borean_tundra.cpp', 'npc_lurgglbr'):
        ('b5dbc121294dfa8ce1ad4f674305456b12afb1cb5d746e4e39b510ed1b5d3b69',
         {'pointId': 41, 'requireLastPoint': True, 'minimumWaitMs': 12500}),
    ('src/server/scripts/EasternKingdoms/zone_westfall.cpp', 'npc_daphne_stilwell'):
        ('8aa353a320c247da812ef6caf8050dd3133543d5d43190630666d0c3134be870',
         {'pointId': 17, 'displayZone': 40}),
}
CHILDRENS_WEEK = 'src/server/scripts/Events/childrens_week.cpp'
REVIEWED_PROXIMITY = {
    'npc_winterfin_playmate': '022bba39b260465cc40a6b9dab6b3f05ed94c5c4057ce6f8b0665c2cca9a3ea0',
    'npc_snowfall_glade_playmate': '1733b54953e23354764e809b8f38b341f6b51bb0fbc3050aa8905a42054d68ab',
    'npc_the_biggest_tree': '5701da6c52f9c1fde453ed1646796b80edfeeacdb24cc7715c4631dc9147ecae',
    'npc_high_oracle_soo_roo': 'b237c55b678ef282598cf9eb3d0b7cbd447c959fbc902b975e00ae65003ae904',
    'npc_elder_kekek': 'dd5a8a2da565a3db595dad1d33c99ffdda942c064e1b2f8fef0a854433ae3ef1',
    'npc_grizzlemaw_cw_trigger': 'ce27aeb3fd886be72ed0d9d0fd1301fc0a06c43586d37ea302a7ef84da7e8545',
}
REVIEWED_CHILDREN_TRIGGER = '936705cd8c47fc5f08efb2a11c3bbca6ec2c63ea942e332e400f1f672643c556'
CHILDREN_DESTINATIONS = {
    'NPC_CAVERNS_OF_TIME_CW_TRIGGER': ('QUEST_TIME_TO_VISIT_THE_CAVERNS_A', 'QUEST_TIME_TO_VISIT_THE_CAVERNS_H'),
    'NPC_EXODAR_01_CW_TRIGGER': ('QUEST_THE_SEAT_OF_THE_NARUU',),
    'NPC_EXODAR_02_CW_TRIGGER': ('QUEST_CALL_ON_THE_FARSEER',),
    'NPC_AERIS_LANDING_CW_TRIGGER': ('QUEST_JHEEL_IS_AT_AERIS_LANDING',),
    'NPC_AUCHINDOUN_CW_TRIGGER': ('QUEST_AUCHINDOUN_AND_THE_RING',),
    'NPC_SPOREGGAR_CW_TRIGGER': ('QUEST_HCHUU_AND_THE_MUSHROOM_PEOPLE',),
    'NPC_THRONE_OF_ELEMENTS_CW_TRIGGER': ('QUEST_VISIT_THE_THRONE_OF_ELEMENTS',),
}


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


def _owner_scope(classes, owner):
    parents = [row for row in classes if row['open'] < owner['open'] < row['end']
               and re.search(r'\bCreatureScript\b', row['declaration'])]
    return min(parents, key=lambda row: row['end']-row['open']) if parents else owner


def _source_digest(masked, scope):
    return hashlib.sha256(re.sub(r'\s+', '', masked[scope['start']:scope['end']+1]).encode()).hexdigest()


def _reviewed_escort(masked, classes, owner, relative):
    scope = _owner_scope(classes, owner)
    reviewed = REVIEWED_ESCORTS.get((relative, scope['name']))
    if reviewed and _source_digest(masked, scope) == reviewed[0]:
        return {**reviewed[1], 'sourceDigest': reviewed[0]}
    return None


def _children_destinations(masked, classes, owner, relative, constants):
    scope = _owner_scope(classes, owner)
    if (relative != CHILDRENS_WEEK or scope['name'] != 'npc_cw_area_trigger'
            or _source_digest(masked, scope) != REVIEWED_CHILDREN_TRIGGER):
        return None
    body = masked[scope['open']+1:scope['end']]
    result = {}
    for name, quests in CHILDREN_DESTINATIONS.items():
        entry = _quest_id(name, constants, body)
        values = [_quest_id(quest, constants, body) for quest in quests]
        if not entry or any(value is None for value in values):
            return None
        result[entry] = values
    silvermoon = _quest_id('NPC_SILVERMOON_01_CW_TRIGGER', constants, body)
    special_quest = _quest_id('QUEST_NOW_WHEN_I_GROW_UP', constants, body)
    return (result, silvermoon, special_quest) if silvermoon and special_quest else None


def _method_at(masked, owner, names, position):
    body = masked[owner['open']+1:owner['end']]
    matches = []
    for method in re.finditer(r'\b('+'|'.join(names)+r')\s*\(', body):
        opening = owner['open']+1+method.end()-1
        closing = _close(masked, opening, '(', ')')
        suffix = re.match(r'\s*(?:(?:const|override|final|noexcept)\s*)*\{', masked[closing+1:])
        if not suffix:
            continue
        start = closing+suffix.end()
        end = _close(masked, start)
        if start < position < end:
            matches.append((method[1], masked[opening+1:closing], start, end))
    return matches[0] if len(matches) == 1 else None


def _enclosing_ifs(masked, start, end, position):
    conditions = []
    for branch in re.finditer(r'\bif\s*\(', masked[start+1:position]):
        opening = start+1+branch.end()-1
        closing = _close(masked, opening, '(', ')')
        tail = closing+1
        while tail < end and masked[tail].isspace():
            tail += 1
        finish = _close(masked, tail) if masked[tail] == '{' else masked.find(';', tail, end)
        if tail <= position < finish:
            conditions.append(masked[opening+1:closing])
    return conditions


def _interaction_credit(masked, owner, call, recipient, arguments):
    names = ('OnGossipHello', 'OnGossipSelect', 'OnGossipSelectCode', 'GossipHello', 'GossipSelect',
             'GossipSelectCode', 'sGossipHello', 'sGossipSelect', 'OnReportUse')
    method = _method_at(masked, owner, names, call.start())
    if not method or not recipient:
        return None
    name, parameters, start, _ = method
    if not re.search(r'\bPlayer\s*\*\s*'+re.escape(recipient)+r'\b', parameters):
        return None
    prefix = masked[start+1:call.start()]
    if re.search(r'\b'+re.escape(recipient)+r'\s*=(?!=)', prefix):
        return None
    if call[1] == 'GroupEventHappens':
        if len(arguments) != 2:
            return None
        anchor = arguments[1].strip()
        if anchor in ('me', 'm_creature') and re.search(r'\b(?:CreatureScript|GameObjectScript)\b', owner['declaration']):
            return None
        if anchor not in ('me', 'm_creature', recipient):
            if not re.search(r'\b(?:Creature|GameObject)\s*\*\s*'+re.escape(anchor)+r'\b', parameters):
                return None
            if re.search(r'\b'+re.escape(anchor)+r'\s*=(?!=)', prefix):
                return None
    elif len(arguments) != 1:
        return None
    return name


def _follower_destination(masked, classes, owner, call, recipient, constants):
    if not recipient or not re.search(r':\s*public\s+FollowerAI\s*\{', owner['declaration']):
        return None
    method = _method_at(masked, owner, ('MoveInLineOfSight',), call.start())
    if not method:
        return None
    _, parameters, start, end = method
    unit = re.fullmatch(r'\s*Unit\s*\*\s*(\w+)\s*', parameters)
    if not unit:
        return None
    body = masked[owner['open']+1:owner['end']]
    if len(re.findall(r'\bMoveInLineOfSight\s*\(', body)) != 2:
        return None
    if re.search(r'\b(?:Player|auto)\s*\*\s*GetLeaderForFollower\s*\(', body):
        return None
    prefix = masked[start+1:call.start()]
    getter = re.search(r'\bPlayer\s*\*\s*'+re.escape(recipient)
                       +r'\s*=\s*GetLeaderForFollower\s*\(\s*\)', prefix)
    if not getter or re.search(r'\b'+re.escape(recipient)+r'\s*=(?!=)', prefix[getter.end():]):
        return None
    if re.search(r'\b'+re.escape(unit[1])+r'\s*=(?!=)', prefix):
        return None
    entry, radius = None, None
    for condition in _enclosing_ifs(masked, start, end, call.start()):
        compact = re.sub(r'\s+', '', condition)
        if '||' in compact:
            continue
        check = re.search(r'(?:^|&&)'+re.escape(unit[1])+r'->GetEntry\(\)==(\w+(?:::\w+)*|\d+)(?:&&|$)', compact)
        if check:
            entry = _quest_id(check[1], constants, body)
        distance = re.fullmatch(r'me->IsWithinDistInMap\('+re.escape(unit[1])
                                +r',INTERACTION_DISTANCE(?:\*(\d+))?\)', compact)
        if distance:
            radius = 5 * int(distance[1] or 1)
    return {'destinationNpcId': entry, 'radius': radius} if entry and radius and radius <= 50 else None


def _coordinate_credit(masked, owner, call):
    blocks = [owner['open']+1+match.start() for match in re.finditer(r'\{', masked[owner['open']+1:call.start()])
              if _close(masked, owner['open']+1+match.start()) > call.start()]
    if not blocks:
        return None
    start, end = blocks[0], _close(masked, blocks[0])
    number = r'([-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)[fF]?'
    for condition in _enclosing_ifs(masked, start, end, call.start()):
        match = re.fullmatch(r'\s*me\s*->\s*GetDistance\s*\(\s*'+number+r'\s*,\s*'
                             +number+r'\s*,\s*'+number+r'\s*\)\s*<\s*'+number+r'\s*', condition)
        if match:
            x, y, z, radius = map(float, match.groups())
            if all(math.isfinite(value) for value in (x, y, z, radius)) and 0 < radius <= 50:
                return {'position_x': x, 'position_y': y, 'position_z': z, 'radius': radius}
    return None


def _escort_waypoint(masked, classes, owner, call, recipient):
    """Recognize direct escort credit in one unambiguous waypoint switch case."""
    if not recipient or not re.search(r':\s*public\s+npc_escortAI\s*\{', owner['declaration']):
        return None
    scope = _owner_scope(classes, owner)
    scope_body = masked[scope['open']+1:scope['end']]
    for method in re.finditer(r'\b(?:GetPlayerForEscort|Start)\s*\(', scope_body):
        closing = _close(scope_body, method.end()-1, '(', ')')
        if re.match(r'\s*(?:(?:const|override|final|noexcept)\s*)*\{', scope_body[closing+1:]):
            return None
    if re.search(r'\b\w+\s*=\s*(?:\*\s*)?(?:me|m_creature|this)\s*[,;)]', scope_body):
        return None
    if re.search(r'\b(?:Creature|Unit|WorldObject|auto)\s*[*&]+\s*\w+\s*[({]\s*'
                 r'(?:me|m_creature|this)\s*[)}]', scope_body):
        return None
    if re.search(r'\b(?:AddWaypoint|SetNextWaypoint|FillPointMovementListForCreature|'
                 r'GenerateWaypointArray|MovementInform|UpdateEntry|SetEntry|'
                 r'NearTeleportTo|TeleportTo|UpdatePosition|Relocate|SetPosition)\s*\(', scope_body):
        return None
    if re.search(r'\b(?:WaypointList|ScriptWP)\b', scope_body):
        return None
    body = masked[owner['open']+1:owner['end']]
    if len(re.findall(r'\bWaypointReached\s*\(', scope_body)) != 1:
        return None
    methods = list(re.finditer(r'\bvoid\s+WaypointReached\s*\(\s*(?:uint32|uint32_t)\s+'
                               r'(\w+)\s*\)\s*(?:override\s*)?\{', body))
    if len(methods) != 1:
        return None
    method = methods[0]
    start = owner['open']+1+method.end()-1
    end = _close(masked, start)
    if not start < call.start() < end:
        return None
    method_body = masked[start+1:end]
    variable = re.escape(method[1])
    if re.search(r'\b'+variable+r'\s*(?:[+*/%-]?=(?!=)|\+\+|--)|(?:\+\+|--)\s*\b'+variable+r'\b', method_body):
        return None
    declarations = list(re.finditer(r'\bPlayer\s*\*\s*'+re.escape(recipient)+r'\b',
                                    masked[start+1:call.start()]))
    if len(declarations) != 1:
        return None
    declaration = start+1+declarations[0].start()
    getter = re.match(r'Player\s*\*\s*'+re.escape(recipient)
                      +r'\s*=\s*GetPlayerForEscort\s*\(\s*\)', masked[declaration:call.start()])
    if not getter or re.search(r'\b'+re.escape(recipient)+r'\s*=(?!=)',
                               masked[declaration+getter.end():call.start()]):
        return None
    switches = []
    for switch in re.finditer(r'\bswitch\s*\(', method_body):
        opening = start+1+switch.end()-1
        closing = _close(masked, opening, '(', ')')
        brace = re.match(r'\s*\{', masked[closing+1:end])
        if not brace:
            continue
        switch_open = closing+brace.end()
        switch_end = _close(masked, switch_open)
        if switch_open < call.start() < switch_end:
            switches.append((masked[opening+1:closing].strip(), switch_open, switch_end))
    if len(switches) != 1 or switches[0][0] != method[1]:
        return None
    _, switch_open, switch_end = switches[0]
    labels = []
    for label in re.finditer(r'\bcase\s+([^:]+):|\bdefault\s*:', masked[switch_open+1:switch_end]):
        position = switch_open+1+label.start()
        preceding = masked[switch_open+1:position]
        if preceding.count('{') != preceding.count('}'):
            continue
        value = label[1].strip() if label[1] else None
        if value is not None and not re.fullmatch(r'\d+[uUlL]*', value):
            return None
        labels.append((position, switch_open+1+label.end(), int(value.rstrip('uUlL')) if value else None))
    cases = [index for index, label in enumerate(labels) if label[0] < call.start()]
    if not cases:
        return None
    index = cases[-1]
    point = labels[index][2]
    if point is None or sum(row[2] == point for row in labels) != 1:
        return None
    # Earlier callbacks may move the actor; this callback resets it to its current waypoint.
    other_cases = list(scope_body)
    for label_index, (_, label_end, _) in enumerate(labels):
        case_end = labels[label_index+1][0] if label_index+1 < len(labels) else switch_end
        if label_index != index:
            for position in range(label_end, case_end):
                other_cases[position-scope['open']-1] = ' '
    checked = ''.join(other_cases)
    if re.search(r'\b(?:me|m_creature)\s*->\s*GetMotionMaster\s*\(', checked):
        return None
    active_prefix = masked[start+1:switch_open] + masked[labels[index][1]:call.start()]
    if re.search(r'\b(?:for|while|do|goto)\b', active_prefix):
        return None

    def terminates(case_index):
        case_end = labels[case_index+1][0] if case_index+1 < len(labels) else switch_end
        segment = masked[labels[case_index][1]:case_end].strip()
        if segment.startswith('{') and _close(segment, 0) == len(segment)-1:
            segment = segment[1:-1]
        terminal = re.search(r'\b(?:break|return)\s*;\s*$', segment)
        if not terminal:
            return False
        before = segment[:terminal.start()]
        return (before.count('{') == before.count('}')
                and not re.search(r'\b(?:if|else)\b[^;{}]*$', before))

    if not terminates(index) or index and not terminates(index-1):
        return None
    return point


def collect(source_root, creature_templates, object_templates):
    root = Path(source_root)
    bindings = _template_bindings(creature_templates, 'monster')
    for script, actors in _template_bindings(object_templates, 'object').items():
        bindings[script].update(actors)
    events, evidence, unsupported = defaultdict(set), defaultdict(list), []
    escort_waypoints = []
    location_proofs = {key: [] for key in ('interactionCredits', 'interactionOmissions', 'followerDestinations',
                                         'coordinateCredits', 'proximityCredits')}
    if not bindings:
        return {'events': {}, 'evidence': {}, 'unsupported': [], 'escortWaypoints': [], **location_proofs}
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
            interaction = _interaction_credit(masked, owner, call, recipient, arguments)
            if recipient:
                valid_actor |= (call[1] == 'CompleteQuest' and len(arguments) == 1)
                valid_actor |= (call[1] == 'GroupEventHappens' and len(arguments) == 2
                                and arguments[1].strip() == recipient)
            valid_actor |= interaction is not None
            line = text.count('\n', 0, call.start())+1
            destinations = _children_destinations(masked, classes, owner, relative, constants)
            scope = _owner_scope(classes, owner)
            if relative == CHILDRENS_WEEK and scope['name'] == 'npc_cw_area_trigger' and not destinations:
                unsupported.append({'file': relative, 'line': line, 'class': owner['name'],
                                    'reason': 'Changed reviewed quest/entry selector'})
                continue
            resolved = [(quest, actor, script) for actor, script in actual_owners] if quest is not None else []
            if destinations:
                by_entry, silvermoon, special_quest = destinations
                expression = arguments[0].strip() if arguments else ''
                if expression == 'questId':
                    resolved = [(value, actor, script) for actor, script in actual_owners
                                for value in by_entry.get(actor[1], ()) if actor[0] == 'monster']
                elif quest == special_quest:
                    resolved = [(quest, actor, script) for actor, script in actual_owners
                                if actor == ('monster', silvermoon)]
            if not resolved or not valid_actor:
                unsupported.append({'file': relative, 'line': line, 'class': owner['name'],
                                    'reason': 'Dynamic/ambiguous quest or unrelated event actor',
                                    'expression': masked[call.end():end].strip()})
                continue
            for quest, actor, script in resolved:
                events[str(quest)].add(actor)
                proof = {'actor': list(actor), 'file': relative, 'line': line,
                         'class': owner['name'], 'script': script, 'call': call[1]}
                evidence[str(quest)].append(proof)
                location = {**proof, 'questId': quest}
                if interaction:
                    location_proofs['interactionCredits'].append({**location, 'method': interaction})
                elif _method_at(masked, owner, ('OnGossipHello', 'OnGossipSelect', 'GossipHello', 'GossipSelect',
                                                 'sGossipHello', 'sGossipSelect', 'OnReportUse'), call.start()):
                    location_proofs['interactionOmissions'].append({**location, 'reason': 'unprovedInteractionPlayer'})
                try:
                    native_point = _coordinate_credit(masked, owner, call)
                except ValueError:
                    native_point = None
                if native_point:
                    location_proofs['coordinateCredits'].append({**location, **native_point})
                digest = _source_digest(masked, scope)
                if (relative == CHILDRENS_WEEK and (destinations or REVIEWED_PROXIMITY.get(scope['name']) == digest)):
                    display = next((zone for name, zone in CHILD_DISPLAY_ZONES.items()
                                    if destinations and _quest_id(name, constants, masked[owner['open']+1:owner['end']]) == actor[1]), None)
                    location_proofs['proximityCredits'].append({**location, 'radius': 20 if destinations else 10,
                                                               'requiresStationary': True, 'sourceDigest': digest,
                                                               **({'displayMap': display[0], 'displayZone': display[1]} if display else {})})
                if actor[0] == 'monster' and call[1] == 'GroupEventHappens' and arguments[1].strip() == 'me':
                    try:
                        point = _escort_waypoint(masked, classes, owner, call, recipient)
                        follower = _follower_destination(masked, classes, owner, call, recipient, constants)
                    except ValueError:
                        point, follower = None, None
                    if follower:
                        location_proofs['followerDestinations'].append({**location, **follower})
                    reviewed = _reviewed_escort(masked, classes, owner, relative)
                    if point is not None:
                        additions = reviewed if reviewed and reviewed['pointId'] == point else {}
                        escort_waypoints.append({**location, 'npcId': actor[1], 'pointId': point, **additions})
                    elif reviewed and reviewed.get('requireLastPoint'):
                        escort_waypoints.append({**location, 'npcId': actor[1], **reviewed})
    return {'events': {key: [list(actor) for actor in sorted(actors)] for key, actors in sorted(events.items(), key=lambda row:int(row[0]))},
            'evidence': dict(evidence), 'unsupported': unsupported, 'escortWaypoints': escort_waypoints, **location_proofs}
