"""Generated deferred databases must fit the stock 3.3.5 client's lexer."""
import io
import re
import subprocess
import unittest

from _test_paths import ADDON_ROOT
import db_snapshot
import generate_acore_full_base as generator


class FullBaseLiteralTests(unittest.TestCase):
    def test_unicode_rows_are_batched_as_independent_sources(self):
        text = ''.join(f'[{i}]={{"éééé"}},\n' for i in range(1, 8))
        output = io.StringIO()
        writer = generator.LuaBlobWriter(output, 'npcData', limit=32)
        writer.write(text)
        writer.finish()
        chunks = re.findall(r'\[====\[\n(.*?)\]====\]', output.getvalue(), re.S)
        self.assertGreater(len(chunks), 1)
        self.assertTrue(all(len(chunk.encode('utf-8')) <= 32 for chunk in chunks))
        self.assertTrue(all(chunk.startswith('return {\n') and chunk.endswith('}') for chunk in chunks))
        self.assertEqual(''.join(chunk[len('return {\n'):-1] for chunk in chunks), text)

    def test_oversized_record_is_rejected_instead_of_splitting_lua_syntax(self):
        writer = generator.LuaBlobWriter(io.StringIO(), 'npcData', limit=32)
        with self.assertRaises(ValueError):
            writer.write('[1]={"' + 'é' * 100 + '"},\n')

    def test_delimiter_collision_is_rejected(self):
        writer = generator.LuaBlobWriter(io.StringIO(), 'npcData')
        with self.assertRaises(ValueError):
            writer.write('return "]====]"')

    def test_all_shipped_bases_have_bounded_literals(self):
        for filename in generator.FILES.values():
            content = (ADDON_ROOT / 'Database/AzerothCore' / filename).read_text(encoding='utf-8')
            chunks = re.findall(r'\[====\[\n(.*?)\]====\]', content, re.S)
            self.assertTrue(chunks, filename)
            self.assertTrue(all(len(chunk.encode('utf-8')) <= generator.MAX_LITERAL_BYTES for chunk in chunks), filename)

    def test_production_loader_merges_chunks_and_rejects_invalid_data(self):
        try:
            executable = db_snapshot.lua_executable()
        except ValueError:
            self.skipTest('Lua unavailable')
        with db_snapshot.temporary_directory(ADDON_ROOT / 'tools/reports') as directory:
            source = '[1]="é",\n[2]=false,\n[4]={},\n'
            output = io.StringIO()
            writer = generator.LuaBlobWriter(output, 'npcData', limit=24)
            writer.write(source)
            writer.finish()
            path = directory / 'roundtrip.lua'
            init = (ADDON_ROOT / 'Modules/QuestieInit.lua').read_text(encoding='utf-8')
            loader = init[init.index('function QuestieInit:LoadDatabase(key)'):init.index('function _QuestieInit.StartStageCoroutine()')]
            path.write_text('QuestieDB = {}; QuestieInit = {}; loadstring = loadstring or load; coYield = coroutine.yield\n'
                            + loader + '\n' + output.getvalue() + '''
local function run()
    local thread = coroutine.create(function() QuestieInit:LoadDatabase("npcData") end)
    repeat
        local ok, err = coroutine.resume(thread)
        if not ok then return false, err end
    until coroutine.status(thread) == "dead"
    return true
end
assert(run())
local data = QuestieDB.npcData
assert(data[1] == "é" and data[2] == false and data[3] == nil and next(data[4]) == nil)
local function rejects(source, message)
    QuestieDB.npcData = source
    local ok, err = run()
    assert(not ok and err:find(message, 1, true), tostring(err))
end
rejects(nil, "Missing base database npcData")
rejects({__questieSourceChunks=true}, "Invalid base database source")
rejects({__questieSourceChunks=true, "return {[1]=false}", "return {[1]={}}"}, "Duplicate record 1")
rejects({__questieSourceChunks=true, "return false"}, "Invalid database result")
rejects({__questieSourceChunks=true, "invalid lua!"}, "Failed to load database npcData chunk 1")
QuestieDB.npcData = "return {[5]={}}"
assert(run() and type(QuestieDB.npcData[5]) == "table")
''',
                            encoding='utf-8')
            result = subprocess.run([executable, str(path)], capture_output=True, text=True, encoding='utf-8')
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
