-- Optional full data round-trip verifier: execute with Lua 5.2+ (or LuaTeX --luaonly).
local root = assert(arg[1], 'output base directory argument required')
local DB = {}
QuestieLoader = {ImportModule = function(_, name) assert(name == 'QuestieDB'); return DB end}
local function quote(s)
  return '"'..s:gsub('[%z\1-\31\\"]', function(c)
    if c == '"' then return '\\"' end
    if c == '\\' then return '\\\\' end
    return string.format('\\u%04x', c:byte())
  end)..'"'
end
local function number(n)
  if math.type and math.type(n) == 'integer' then return tostring(n) end
  return string.format('%.17g',n)
end
local function keys(t)
  local a={}
  for k in pairs(t) do assert(type(k)=='number' or type(k)=='string');a[#a+1]=k end
  table.sort(a,function(l,r)
    if type(l)~=type(r) then return type(l)=='number' end
    return l<r
  end)
  return a
end
local function encode(v, seen)
  local t=type(v)
  if t=='string' then return quote(v) end
  if t=='boolean' then return tostring(v) end
  if t=='number' then return number(v) end
  assert(t=='table',t)
  seen=seen or {};assert(not seen[v]);seen[v]=true
  local a={}
  for _,k in ipairs(keys(v)) do
    local sk=type(k)=='number' and 'n:'..number(k) or 's:'..k
    a[#a+1]=quote(sk)..':'..encode(v[k],seen)
  end
  seen[v]=nil
  return '{'..table.concat(a,',')..'}'
end
local order={'item','npc','object','quest'}
for _,kind in ipairs(order) do
  local path=root..'/acore'..kind:sub(1,1):upper()..kind:sub(2)..'DB.lua'
  dofile(path)
  local data=assert((loadstring or load)(DB[kind..'Data'], '@'..path))()
  local keysByPosition={}
  for name,ix in pairs(DB[kind..'Keys']) do
    assert(not keysByPosition[ix]);keysByPosition[ix]=name
  end
  for _,id in ipairs(keys(data)) do
    local row=data[id]; local named={}
    for ix,value in pairs(row) do
      named[assert(keysByPosition[ix],'unknown field index')]=value
    end
    io.write('{"section":'..quote(kind..'Data')..',"id":'..number(id)..',"value":'..encode(named)..'}\n')
  end
end
