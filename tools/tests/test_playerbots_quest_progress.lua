-- Run from the addon root with Lua 5.1 or 5.2+. Exercise Playerbots quest progress through
-- the production comms, tooltip and party map modules with both MBOT bridge variants.
local SOURCE = "."

local modules, sent, printed, updates = {}, {}, {}, {}
local now, roster, connected = 1, {"Tankbot", "Healbot", "Human"}, {}
local frame
local function module(name)
    if not modules[name] then modules[name] = {private={}} end
    return modules[name]
end
QuestieLoader = {CreateModule=function(_, name) return module(name) end,
                 ImportModule=function(_, name) return module(name) end}
QuestieCompat = {HBD={}}
Questie = {db={profile={}}}
DEFAULT_CHAT_FRAME = {AddMessage=function(_, message) printed[#printed+1] = message end}
function GetTime() return now end
function UnitName(unit)
    if unit == "player" then return "Owner" end
    return roster[tonumber(unit:match("party(%d+)"))]
end
function UnitIsConnected(unit) return connected[UnitName(unit)] ~= false end
function GetNumPartyMembers() return #roster end
function GetNumRaidMembers() return 0 end
function CreateFrame()
    frame = {RegisterEvent=function() end, SetScript=function(self, event, callback) self[event] = callback end}
    return frame
end
function SendAddonMessage(prefix, message, channel, target)
    assert(prefix == "MBOT" and #message <= 255)
    sent[#sent+1] = {message=message, channel=channel, target=target}
end
local quests = {
    [100] = {ObjectiveData={{Type="monster", Id=101}}},
    [200] = {ObjectiveData={{Type="item", Id=500}, {Type="monster", Id=101},
        {Type="killcredit", RootId=900, IdList={901,902}}, {Type="event"},
        {Type="reputation", Id=72}, {Type="spell", Id=444}}},
}
module("QuestieDB").GetQuest = function(id) return quests[id] end
module("QuestieDB").GetNPC = function(_, id) return {name="NPC"..id} end
module("QuestieDB").GetObject = function(_, id) return {name="Object"..id} end
-- QuestieDB:GetItem always returns a Sources list built from the item's drops.
local itemSources = {[50432]={{Id=299, Type="monster"}}, [750]={{Id=705, Type="monster"}}}
module("QuestieDB").GetItem = function(_, id) return {Id=id, name="Item"..id, Sources=itemSources[id] or {}} end
module("QuestieLib").Count = function(_, values) local n=0; for _ in pairs(values) do n=n+1 end; return n end
-- Production QuestieLib:GetObjectiveDescription strips one trailing period; the
-- local quest log starts empty and holds quest objects by ID.
module("QuestieLib").GetObjectiveDescription = function(_, objective)
    local text = objective and (objective.FullDescription or objective.Description) or ""
    return (text:gsub("%.$", ""))
end
module("QuestiePlayer").currentQuestlog = {}
module("QuestiePartyObjectives").ScheduleUpdate = function(_, id) updates[#updates+1] = id or 0 end

-- Load complete production modules, including the native insertion and tooltip lookup.
dofile(SOURCE .. "/Modules/Network/QuestieComms.lua")
dofile(SOURCE .. "/Modules/Network/QuestieCommsData.lua")
local comms = module("QuestieComms")
local function loadAddon()
    dofile(SOURCE .. "/Modules/Network/QuestiePlayerbots.lua")
    module("QuestiePlayerbots"):Initialize()
end
local function receive(message, sender)
    frame.OnEvent(frame, "CHAT_MSG_ADDON", "MBOT", message, "WHISPER", sender or "Owner")
end
local function advance(seconds)
    now = now + seconds
    frame.OnUpdate(frame, seconds)
end
local function hello(push)
    receive("CAPS_BEGIN")
    receive("CAPS~QUEST_PROGRESS_V1" .. (push == false and "" or ",QUEST_PROGRESS_PUSH_V1"))
    receive("CAPS_END")
end
local function token(name)
    for i=#sent,1,-1 do
        local bot, value, mode = sent[i].message:match("^GET~QUEST_PROGRESS~([^~]+)~([^~]+)~?([^~]*)$")
        if bot == name and mode ~= "UNWATCH" then return value end
    end
    error("No request for "..name)
end
local function begin(name, request)
    receive("QUEST_PROGRESS_BEGIN~" .. name .. "~" .. request .. "~Player-1-00000001")
end
local function quest(name, request, id, status)
    receive("QUEST_PROGRESS_QUEST~" .. name .. "~" .. request .. "~" .. id .. "~" .. (status or "I"))
end
local function objective(name, request, id, typ, index, target, current, required, finished)
    local message = table.concat({"QUEST_PROGRESS_OBJECTIVE",name,request,id,typ,index,target,current,required}, "~")
    if finished ~= nil then message = message .. "~" .. finished end
    receive(message)
end
local function finish(name, request) receive("QUEST_PROGRESS_END~"..name.."~"..request) end
local function progress(name, request, current, status)
    begin(name, request); quest(name, request, 100, status)
    objective(name, request, 100, "m", 1, 101, current, 10)
    finish(name, request)
end
local function entry(name, id, index)
    return comms.remoteQuestLogs[id or 100] and comms.remoteQuestLogs[id or 100][name]
        and comms.remoteQuestLogs[id or 100][name][index or 1]
end
local function nativeHuman(name, current)
    comms:InsertQuestDataPacket({id=100, status="I", objectives={
        {id=101,typ="m",fin=false,ful=current,req=10}}}, name)
    return comms.remoteQuestLogs[100][name]
end

loadAddon()
assert(sent[1].message == "HELLO~1")
hello()
local tank, heal, human = token("Tankbot"), token("Healbot"), token("Human")
assert(sent[2].message == "GET~QUEST_PROGRESS~Tankbot~"..tank.."~WATCH")
local humanData = nativeHuman("Human", 6)
receive("ERR~GET~QUEST_PROGRESS~"..human.."~BOT_UNAVAILABLE")
assert(comms.remoteQuestLogs[100].Human == humanData and #printed == 0, "discovery damaged human comms")

-- Bots' concurrent snapshots stay bound to their own request and native objective slot.
begin("Tankbot",tank); begin("Healbot",heal)
quest("Tankbot",tank,100); quest("Healbot",heal,100)
objective("Tankbot",tank,100,"m",1,101,8,10)
objective("Healbot",heal,100,"m",1,101,4,10)
finish("Healbot",heal); finish("Tankbot",tank)
assert(entry("Tankbot").fulfilled == 8 and entry("Healbot").fulfilled == 4)
assert(comms:GetQuest(100,"Tankbot")[1].required == 10)
local tooltip = comms.data:GetTooltip("m_101")[100]
assert(tooltip.Human[1].fulfilled == 6 and tooltip.Tankbot[1].fulfilled == 8 and tooltip.Healbot[1].fulfilled == 4)
local count = #updates
progress("Tankbot",tank,8)
assert(#updates == count, "unchanged snapshot redrew objectives")
progress("Tankbot",tank,10,"C")
assert(entry("Tankbot").finished and entry("Tankbot").status == "C")
progress("Healbot",heal,4,"F")
assert(entry("Healbot").status == "F")
begin("Tankbot",tank); finish("Tankbot",tank)
assert(not entry("Tankbot") and entry("Healbot") and entry("Human"), "quest turn-in removed another member")
assert(comms.data:GetTooltip("m_101")[100].Tankbot == nil)

-- Reject spoofed, unsolicited, mismatched, oversized and malformed snapshots atomically.
progress("Tankbot","qpb0x0",9)
assert(not entry("Tankbot"), "stale issued token was accepted")
progress("Tankbot",heal,9)
assert(not entry("Tankbot"), "another bot's valid WATCH token was accepted")
receive("QUEST_PROGRESS_BEGIN~Tankbot~"..tank,"Human")
quest("Tankbot",tank,100); finish("Tankbot",tank)
assert(not entry("Tankbot"))
begin("Tankbot",tank); quest("Tankbot",tank,100)
objective("Tankbot",tank,100,"m",1,101,"nan",10); finish("Tankbot",tank)
assert(not entry("Tankbot"))
begin("Tankbot",tank); quest("Tankbot",tank,100)
objective("Tankbot",tank,100,"m",1,101,3,10)
objective("Tankbot",tank,100,"m",1,101,4,10); finish("Tankbot",tank)
assert(not entry("Tankbot"), "duplicate objective corrupted snapshot")
begin("Tankbot",tank); quest("Tankbot",tank,100)
receive("QUEST_PROGRESS_OBJECTIVE~Tankbot~"..tank.."~100~m~1~101~"..string.rep("9",255).."~10")
receive("QUEST_PROGRESS_OBJECTIVE~Tankbot~"..tank.."~100~m~1~101")
finish("Tankbot",tank)
assert(not entry("Tankbot"))
begin("Tankbot",tank); quest("Tankbot",tank,100)
objective("Healbot",tank,100,"m",1,101,9,10); finish("Tankbot",tank)
assert(not entry("Tankbot") and entry("Healbot").fulfilled == 4)
begin("Tankbot",tank)
for id=300,375 do quest("Tankbot",tank,id) end
finish("Tankbot",tank)
assert(not comms.remoteQuestLogs[300], "unbounded quest snapshot was accepted")
begin("Tankbot",tank); quest("Tankbot",tank,100)
for index=1,33 do objective("Tankbot",tank,100,"m",index,1000+index,0,1) end
finish("Tankbot",tank)
assert(not entry("Tankbot"), "unbounded objective snapshot was accepted")
begin("Tankbot",tank); quest("Tankbot",tank,100)
objective("Tankbot",tank,100,"m",33,101,0,1); finish("Tankbot",tank)
assert(not entry("Tankbot"), "out-of-range objective index was accepted")

-- Server indexes differ from Questie's corrected order. Match targets, including kill credits.
begin("Tankbot",tank); quest("Tankbot",tank,200)
objective("Tankbot",tank,200,"m",1,101,2,10,0)
objective("Tankbot",tank,200,"i",2,500,3,5,0)
objective("Tankbot",tank,200,"m",3,900,1,2,0)
objective("Tankbot",tank,200,"e",4,0,0,1,1)
objective("Tankbot",tank,200,"r",5,72,-100,42000,0)
objective("Tankbot",tank,200,"s",6,444,0,1,0)
objective("Tankbot",tank,200,"p",7,0,2,5,0)
objective("Tankbot",tank,200,"g",8,0,50000,100000,0)
objective("Tankbot",tank,200,"m",9,99999,1,3,0)
finish("Tankbot",tank)
assert(entry("Tankbot",200,1).fulfilled == 3 and entry("Tankbot",200,2).fulfilled == 2)
assert(entry("Tankbot",200,3).fulfilled == 1 and entry("Tankbot",200,4).finished)
assert(entry("Tankbot",200,4).id == nil and entry("Tankbot",200,5).fulfilled == -100)
assert(entry("Tankbot",200,6).id == 444 and entry("Tankbot",200,-7).id == nil)
assert(entry("Tankbot",200,-8).fulfilled == 50000 and entry("Tankbot",200,-9).id == 99999)
assert(comms.data:GetTooltip("m_901")[200].Tankbot[3].text == "NPC901")
assert(comms.data:GetTooltip("m_902")[200].Tankbot[3].fulfilled == 1)
comms:InsertQuestDataPacket({id=200, objectives={
    [3]={id=900,typ="i",fin=false,ful=4,req=5}}}, "Human")
assert(not comms.data:GetTooltip("m_901")[200].Human, "mismatched native objective got kill-credit aliases")
comms:InsertQuestDataPacket({id=200, objectives={
    [3]={id=101,typ="m",fin=false,ful=6,req=10}}}, "Human")
assert(not comms.data:GetTooltip("m_901")[200].Human, "unrelated monster got kill-credit aliases")
assert(not comms.data:KeyExists("e_0"))
begin("Tankbot",tank); quest("Tankbot",tank,200)
objective("Tankbot",tank,200,"m",1,902,2,2,1); finish("Tankbot",tank)
assert(entry("Tankbot",200,3).finished, "kill-credit alias did not map")

-- Other bridges push WATCH updates under their own tokens and number objectives per type.
progress("Tankbot","qpp7x1",6)
assert(entry("Tankbot").fulfilled == 6, "bridge push token was rejected")

-- Reject arbitrary or malformed bridge push tokens.
progress("Tankbot", "random123", 9)
assert(entry("Tankbot").fulfilled == 6, "arbitrary push token was accepted")
progress("Tankbot", "qpp7x1junk", 9)
assert(entry("Tankbot").fulfilled == 6, "malformed push token was accepted")
progress("Tankbot", "qpp7x", 9)
assert(entry("Tankbot").fulfilled == 6, "incomplete push token was accepted")

begin("Tankbot","qpp7x2"); quest("Tankbot","qpp7x2",200)
objective("Tankbot","qpp7x2",200,"m",1,101,4,10)
objective("Tankbot","qpp7x2",200,"i",1,500,2,5)
objective("Tankbot","qpp7x2",200,"m",2,99999,1,3)
objective("Tankbot","qpp7x2",200,"i",2,88888,1,4)
finish("Tankbot","qpp7x2")
assert(entry("Tankbot",200,1).fulfilled == 2 and entry("Tankbot",200,2).fulfilled == 4,
    "per-type objective indices were rejected")
assert(entry("Tankbot",200,-3).id == 99999 and entry("Tankbot",200,-4).id == 88888,
    "per-type unknown counters collided")

-- Questie's database can name another item than the server for one objective.
-- Bots then report the database objective like a Questie client.
quests[33] = {ObjectiveData={{Type="item", Id=50432}}}
quests[34] = {ObjectiveData={{Type="item", Id=1}, {Type="item", Id=2}}}
quests[35] = {ObjectiveData={{Type="item", Id=1}}}
quests[36] = {ObjectiveData={{Type="item", Id=1}, {Type="item", Id=2}, {Type="item", Id=5}}}
begin("Tankbot",tank)
quest("Tankbot",tank,33); quest("Tankbot",tank,34); quest("Tankbot",tank,35); quest("Tankbot",tank,36)
objective("Tankbot",tank,33,"i",1,750,3,8,0)
objective("Tankbot",tank,34,"i",1,3,1,5,0)
objective("Tankbot",tank,35,"i",1,3,1,5,0)
objective("Tankbot",tank,35,"i",2,4,2,5,0)
objective("Tankbot",tank,36,"i",1,5,1,5,0)
objective("Tankbot",tank,36,"i",2,3,2,5,0)
objective("Tankbot",tank,36,"i",3,4,3,5,0)
finish("Tankbot",tank)
assert(entry("Tankbot",33,1).id == 50432 and entry("Tankbot",33,1).fulfilled == 3,
    "mismatched database objective was not paired")
assert(comms.data:GetTooltip("m_299")[33].Tankbot[1].fulfilled == 3, "database drop source has no tooltip")
assert(comms.data:GetTooltip("m_299")[33].Tankbot[1].text == "Item50432")
-- With the quest in the local log, members' lines use its text like map icon tooltips.
module("QuestiePlayer").currentQuestlog[33] = {Objectives={[1]={Description="Tough Wolf Meat."}}}
assert(comms.data:GetTooltip("m_299")[33].Tankbot[1].text == "Tough Wolf Meat", "party line ignored local objective text")
module("QuestiePlayer").currentQuestlog[33] = nil
assert(not entry("Tankbot",34,1) and not entry("Tankbot",34,2) and entry("Tankbot",34,-1).id == 3,
    "ambiguous database objectives were paired")
assert(not entry("Tankbot",35,1) and entry("Tankbot",35,-1).id == 3 and entry("Tankbot",35,-2).id == 4,
    "ambiguous server objectives were paired")
assert(entry("Tankbot",36,3).fulfilled == 1 and entry("Tankbot",36,1).id == 1 and entry("Tankbot",36,1).fulfilled == 2
    and entry("Tankbot",36,2).id == 2 and entry("Tankbot",36,2).fulfilled == 3, "remaining objectives were not paired in order")

-- Partial snapshots expire without replacing the last complete state.
begin("Healbot",heal); quest("Healbot",heal,100)
objective("Healbot",heal,100,"m",1,101,7,10)
advance(11); finish("Healbot",heal)
assert(entry("Healbot").fulfilled == 4)
local beforeRefresh = #sent
advance(50)
local renewed = false
for i=beforeRefresh+1,#sent do
    renewed = renewed or sent[i].message == "GET~QUEST_PROGRESS~Healbot~"..heal.."~WATCH"
end
assert(renewed and token("Healbot") == heal, "WATCH lease was not renewed")
progress("Healbot",heal,7)
assert(entry("Healbot").fulfilled == 7)

-- Disconnect/leave clears only owned bot data, sends UNWATCH and rejects late packets.
connected.Healbot = false
advance(2)
assert(not entry("Healbot"))
assert(sent[#sent].message == "GET~QUEST_PROGRESS~Healbot~"..heal.."~UNWATCH")
progress("Healbot",heal,9)
assert(not entry("Healbot"))
connected.Healbot = true
advance(2)
local rejoined = token("Healbot")
assert(rejoined ~= heal)
progress("Healbot",heal,9)
assert(not entry("Healbot"))
progress("Healbot",rejoined,2)
assert(entry("Healbot").fulfilled == 2)
progress("Tankbot",token("Tankbot"),5)
local converted = nativeHuman("Tankbot",1)
progress("Tankbot",token("Tankbot"),8)
assert(comms.remoteQuestLogs[100].Tankbot == converted, "in-flight WATCH overwrote native takeover")
roster = {"Healbot","Human"}
frame.OnEvent(frame,"PARTY_MEMBERS_CHANGED")
advance(1)
assert(comms.remoteQuestLogs[100].Tankbot == converted, "cleanup removed a real client's replacement")
assert(comms.remoteQuestLogs[100].Human == humanData)

-- Timeouts and late replies cannot grow the pending state or overwrite native human data.
advance(61)
advance(11)
assert(comms.remoteQuestLogs[100].Human == humanData)
local oldToken = rejoined
comms:ResetAll()
loadAddon(); hello()
local reloadToken = token("Healbot")
assert(reloadToken ~= oldToken, "reload reused stale request token")
progress("Healbot",oldToken,10)
assert(not entry("Healbot"))
progress("Healbot",reloadToken,3)
assert(entry("Healbot").fulfilled == 3)

-- Initial bridge timeouts retry automatically; a snapshot-only bridge still cleans departed bots.
comms:ResetAll(); loadAddon()
local beforeRetry = #sent
advance(31)
assert(#sent > beforeRetry and sent[#sent].message == "HELLO~1")
hello(false)
local snapshotOnly = token("Healbot")
progress("Healbot","qpp1x1",9)
assert(not entry("Healbot"), "push token was accepted without WATCH")
progress("Healbot",snapshotOnly,4)
assert(entry("Healbot").fulfilled == 4)
roster = {"Human"}
advance(2)
assert(not entry("Healbot"), "snapshot-only bridge did not clean departed bot")

-- A bridge that answers without quest progress support is not probed again.
comms:ResetAll(); loadAddon()
receive("CAPS_BEGIN"); receive("CAPS~INVENTORY_OPEN_V1"); receive("CAPS_END")
local beforeUnsupported = #sent
advance(31)
assert(#sent == beforeUnsupported, "unsupported bridge was probed again")

-- Without any bridge answer, HELLO is retried only a few times.
local beforeSilent = #sent
comms:ResetAll(); loadAddon()
for _=1,5 do advance(31) end
local hellos = 0
for i=beforeSilent+1,#sent do
    if sent[i].message == "HELLO~1" then hellos = hellos + 1 end
end
assert(hellos == 4, "realm without a bridge kept receiving HELLO probes")

-- Exercise the complete native party renderer, objective preparation and spawn
-- handlers. Only client map/frame APIs and the static DB query boundary are doubled.
comms:ResetAll()
roster, connected = {"Tankbot", "Human"}, {}
loadAddon(); hello()
local coordinates = {[12]={{40,50}}}
quests[400] = {Id=400, Objectives={}, ObjectiveData={
    {Type="killcredit", RootId=900, IdList={901,902}, Text="Credit target"},
    {Type="event", Text="Explore here", Coordinates=coordinates},
}, SpecialObjectives={{Id=777, Type="event", Description="Special use", Coordinates=coordinates}}}
local mapToken = token("Tankbot")
begin("Tankbot",mapToken); quest("Tankbot",mapToken,400)
objective("Tankbot",mapToken,400,"g",1,0,50,100,0)
objective("Tankbot",mapToken,400,"m",2,900,1,2,0)
objective("Tankbot",mapToken,400,"e",3,0,0,1,0)
finish("Tankbot",mapToken)
assert(entry("Tankbot",400,-1).fulfilled == 50)

-- Bridges without error replies end requests for unobservable members with NO_BOT.
local beforeNoBot = #sent
receive("QUEST_PROGRESS_END~Human~"..token("Human").."~NO_BOT")
advance(13); advance(2)
for i=beforeNoBot+1,#sent do
    assert(not sent[i].message:find("~Human~", 1, true), "NO_BOT member was polled again")
end

local mapPins, renderErrors = {}, {}
Questie.Debug = function() end
Questie.Error = function(...) renderErrors[#renderErrors+1] = table.concat({...}, " ") end
Questie.db.profile.showPartyQuestObjectives = true
Questie.db.profile.objectiveFilterDistance = 0
QuestieCompat.C_Timer = {After=function() end}
QuestieCompat.C_QuestLog = {}
QuestieCompat.GetQuestLogIndexByID = function() return nil end
QuestieCompat.GetGroupUnitByName = function(name)
    for i, value in ipairs(roster) do if value == name then return "party"..i end end
end
QuestieCompat.GetNumGroupMembers = function() return #roster + 1 end
QuestieCompat.HBD.GetWorldCoordinatesFromZone = function(_, x, y) return x*100, y*100 end
CallErrorHandler = function(message) renderErrors[#renderErrors+1] = tostring(message) end
QUEST_MONSTERS_KILLED = "%s slain: %d/%d"
QUEST_ITEMS_NEEDED = "%s: %d/%d"
QUEST_OBJECTS_FOUND = "%s: %d/%d"
module("QuestLogCache").questLog_DO_NOT_MODIFY = {}
module("QuestiePlayer").GetGroupType = function() return "party" end
module("CommsVisibility").ShouldShowPartyObjective = function() return true end
module("QuestieLib").ColorWheel = function() return {} end
module("QuestieLib").GetFullObjectiveText = function(text) return text end
module("QuestieLib").Euclid = function(_, x1,y1,x2,y2) return math.sqrt((x1-x2)^2+(y1-y2)^2) end
module("QuestieCorrections").questNPCBlacklist = {}
module("QuestieDB").QueryNPCSingle = function(id, field)
    if field == "name" then return "NPC"..id end
    if field == "spawns" then return coordinates end
    if field == "rank" then return 0 end
    if field == "waypoints" then return {} end
end
module("ZoneDB").GetUiMapIdByAreaId = function(_, zone) return zone end
module("ZoneDB").GetDungeonLocation = function() return nil end
module("QuestieIconVisibility").IsEnabledAnywhere = function() return true end
module("Phasing").IsSpawnDataVisible = function() return true end
module("QuestieMap").FindClosestStarter = function() return {} end
module("QuestieMap").IsLootedObjectSpawn = function() return false end
module("QuestieMap").DrawWorldIcon = function(_, data, zone, x, y)
    local pin = {data=data, zone=zone, x=x, y=y}
    mapPins[#mapPins+1] = pin
    return pin, {data=data}
end
module("QuestieFramePool").UnloadFrame = function(_, pin) pin.data = nil end
module("ThreadLib").ThreadCallbackInstant = function(callback, complete)
    local ok, message = coroutine.resume(coroutine.create(callback))
    if not ok then renderErrors[#renderErrors+1] = tostring(message) end
    complete(ok)
end
dofile(SOURCE .. "/Modules/Quest/QuestieQuest.lua")
dofile(SOURCE .. "/Modules/Quest/QuestieQuestPrivates.lua")
dofile(SOURCE .. "/Modules/Network/QuestiePartyObjectives.lua")
module("QuestiePartyObjectives"):Update()
assert(#renderErrors == 0, table.concat(renderErrors, "\n"))
local creditTargets, events, specials = {}, 0, 0
for _, pin in ipairs(mapPins) do
    if pin.data then
        local data = pin.data
        if data.ObjectiveIndex == 1 then creditTargets[data.ObjectiveTargetId] = true end
        if data.ObjectiveIndex == 2 then
            events = events + 1
            assert(data.ObjectiveData.Coordinates == coordinates)
        end
        if data.ObjectiveIndex == 65 then
            specials = specials + 1
            assert(not comms:GetQuest(400,"Tankbot")[data.ObjectiveIndex], "special pin inherited an unrelated counter")
        end
    end
end
assert(creditTargets[901] and creditTargets[902], "native kill-credit party targets were not drawn")
assert(events == 1 and specials == 1, "native event/special map rendering failed")
print("Questie Playerbots: native comms, tooltips, map rendering, objectives and lifecycle passed")
