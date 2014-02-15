local tostring = tostring
local string = string
local table = table
local print = print
local type = type
local io = io
local pairs = pairs
local ipairs = ipairs
local os = os
local collectgarbage = collectgarbage
local getmetatable = getmetatable
local setmetatable = setmetatable
local MOAISim = MOAISim
local strfind = string.find
local tinsert = table.insert
local tremove = table.remove
local strsub = string.sub
local min = math.min
local max = math.max
local floor = math.floor
local select = select
local debug = debug
local assert = assert
module(...)
function printfln(fmt, ...)
  print(fmt:format(...))
  io.stdout:flush()
end
function tostr(e, visited)
  if type(e) == "table" then
    visited = visited or {}
    return tablestr(e, visited)
  else
    return tostring(e)
  end
end
function tablestr(t, visited)
  visited = visited or {}
  local fmt = string.format
  local function str(e, visited)
    if type(e) == "string" then
      return fmt("%q", e)
    elseif type(e) == "table" then
      if visited[e] then
        return tostring(e)
      else
        return tablestr(e, visited)
      end
    else
      return tostring(e)
    end
  end
  visited[t] = true
  local s = {}
  for k, v in pairs(t) do
    local keystr
    if type(k) == "string" then
      if string.match(k, "^[_%a][_%w%d]*$") then
        keystr = k
      else
        keystr = fmt("[%s]", str(k, visited))
      end
    else
      keystr = fmt("[%s]", str(k, visited))
    end
    table.insert(s, fmt("%s = %s", keystr, str(v, visited)))
  end
  return string.format("{ %s }", table.concat(s, ", "))
end
function tobinarystr(n, width)
  local str = {}
  local insert = table.insert
  local w = 0
  if n < 0 then
    insert(str, "1")
    w = 1
    n = -n
  else
    insert(str, "")
  end
  while n > 0 do
    w = w + 1
    if n % 2 == 0 then
      insert(str, 2, "0")
    else
      insert(str, 2, "1")
    end
    n = math.floor(n / 2)
  end
  if width ~= nil and width > w then
    table.insert(str, 1, string.rep("0", width - w))
  end
  return table.concat(str, "")
end
function nilify(t, visited, dbg)
  if dbg ~= nil then
    printfln("   nil -> (%s)", tostring(t))
  end
  visited = visited or {}
  if type(t) == "userdata" and not visited[t] then
    visited[t] = true
    if dbg ~= nil then
      nilify(getmetatable(t), visited, dbg .. "~mt")
    else
      nilify(getmetatable(t), visited)
    end
  elseif type(t) == "table" and not visited[t] then
    visited[t] = true
    for k, v in pairs(t) do
      if type(k) ~= "string" or not k:match("^__") and not k:match("^_m$") then
        t[k] = nil
        local vt = type(v)
        if dbg ~= nil then
          printfln("  nilify (%s) %s[%s]", vt, dbg, k)
        end
        if (vt == "table" or vt == "userdata") and not visited[v] then
          if dbg ~= nil then
            nilify(v, visited, string.format("%s[%s]", dbg, k))
          else
            nilify(v, visited)
          end
        end
      end
    end
  end
  if t.clear and type(t.clear) == "function" then
    t:clear()
  end
  t = nil
end
function timestamp(t)
  return os.date("!%Y-%m-%d %H:%M:%S", t)
end
function sortedpairs(t, f)
  local a = {}
  for n in pairs(t) do
    table.insert(a, n)
  end
  table.sort(a, f)
  local i = 0
  local function iter()
    i = i + 1
    if a[i] == nil then
      return nil
    else
      return a[i], t[a[i]]
    end
  end
  return iter
end
function breakstr(str, splitter)
  assert(str, debug.traceback())
  local idx = str:find(splitter)
  if idx == nil then
    return str, nil
  end
  return str:sub(1, idx - 1), str:sub(idx + 1, str:len())
end
function strsplit(delim, text)
  if delim == "" then
    return {text}
  end
  local list = {}
  local pos = 1
  while true do
    do
      local first, last = strfind(text, delim, pos)
      if first then
        tinsert(list, strsub(text, pos, first - 1))
        pos = last + 1
      else
        tinsert(list, strsub(text, pos))
        break
      end
    end
  end
  return list
end
function clamp(val, minVal, maxVal)
  return min(max(val, minVal), maxVal)
end
local _NIL = {}
function pack2(...)
  local n = select("#", ...)
  local t = {
    ...
  }
  for i = 1, n do
    if t[i] == nil then
      t[i] = _NIL
    end
  end
  return t
end
function unpack2(t, k, n)
  k = k or 1
  n = n or #t
  if k > n then
    return
  end
  local v = t[k]
  if v == _NIL then
    v = nil
  end
  return v, unpack2(t, k + 1, n)
end
function find(t, val)
  for i = 1, #t do
    if t[i] == val then
      return i
    end
  end
  return nil
end
function find_and_remove(t, val)
  for i = 1, #t do
    if t[i] == val then
      tremove(t, i)
      return i
    end
  end
  return nil
end
function pairsByKeys(t, f)
  local a = {}
  for n in pairs(t) do
    table.insert(a, n)
  end
  table.sort(a, f)
  local i = 0
  local function iter()
    i = i + 1
    if a[i] == nil then
      return nil
    else
      return a[i], t[a[i]]
    end
  end
  return iter
end
function roundNumber(val, decimal)
  if decimal then
    return floor((val * 10 ^ decimal + 0.5) / 10 ^ decimal)
  else
    return floor(val + 0.5)
  end
end
function commasInNumbers(num)
  local result = ""
  local sign, before, after = string.match(tostring(num), "^([%+%-]?)(%d*)(%.?.*)$")
  while string.len(before) > 3 do
    result = "," .. string.sub(before, -3, -1) .. result
    before = string.sub(before, 1, -4)
  end
  return sign .. before .. result .. after
end
function todebugstr(f)
  local t = debug.getinfo(f)
  return string.format("%s:%s:%d (%s)", t.what, t.source, t.linedefined, t.namewhat)
end
function set_if_nil(t, field, value)
  if t[field] == nil then
    t[field] = value
  end
end
function flatten_table(base, t, idx)
  idx = idx or ""
  if type(t) == "table" then
    if idx ~= "" then
      idx = idx .. "_"
    end
    for i, v in pairs(t) do
      flatten_table(base, v, idx .. i)
    end
  elseif type(t) ~= "table" then
    base[idx] = t
  end
end
function string_insert(self, insert, place)
  return self:sub(1, place - 1) .. insert .. self:sub(place, self:len())
end
function table_copy(t)
  local t2 = {}
  for i, v in pairs(t) do
    t2[i] = v
  end
  return setmetatable(t2, getmetatable(t))
end
function table_deepcopy(object)
  local lookup_table = {}
  local function _copy(object)
    if type(object) ~= "table" then
      return object
    elseif lookup_table[object] then
      return lookup_table[object]
    end
    local new_table = {}
    lookup_table[object] = new_table
    for index, value in pairs(object) do
      new_table[_copy(index)] = _copy(value)
    end
    return setmetatable(new_table, getmetatable(object))
  end
  return _copy(object)
end
