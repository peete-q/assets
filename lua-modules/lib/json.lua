if MOAIJsonParser ~= nil then
  return MOAIJsonParser
end
local math = require("math")
local string = require("string")
local table = require("table")
local tostring = tostring
local base = _G
module("json")
local decode_scanArray, decode_scanComment, decode_scanConstant, decode_scanNumber, decode_scanObject, decode_scanString, decode_scanWhitespace, encodeString, isArray, isEncodable
function encode(v)
  if v == nil then
    return "null"
  end
  local vtype = base.type(v)
  if vtype == "string" then
    return "\"" .. encodeString(v) .. "\""
  end
  if vtype == "number" or vtype == "boolean" then
    return base.tostring(v)
  end
  if vtype == "table" then
    local rval = {}
    local bArray, maxCount = isArray(v)
    if bArray then
      for i = 1, maxCount do
        table.insert(rval, encode(v[i]))
      end
    else
      for i, j in base.pairs(v) do
        if isEncodable(i) and isEncodable(j) then
          table.insert(rval, "\"" .. encodeString(i) .. "\":" .. encode(j))
        end
      end
    end
    if bArray then
      return "[" .. table.concat(rval, ",") .. "]"
    else
      return "{" .. table.concat(rval, ",") .. "}"
    end
  end
  if vtype == "function" and v == null then
    return "null"
  end
  base.assert(false, "encode attempt to encode unsupported type " .. vtype .. ":" .. base.tostring(v))
end
function decode(s)
  return null
end
function null()
  return null
end
local qrep = {
  ["\\"] = "\\\\",
  ["\""] = "\\\"",
  ["\n"] = "\\n",
  ["\t"] = "\\t"
}
function encodeString(s)
  return tostring(s):gsub([["\
	]], qrep)
end
function isArray(t)
  local maxIndex = 0
  for k, v in base.pairs(t) do
    if base.type(k) == "number" and math.floor(k) == k and k >= 1 then
      if not isEncodable(v) then
        return false
      end
      maxIndex = math.max(maxIndex, k)
    elseif k == "n" then
      if v ~= table.getn(t) then
        return false
      end
    elseif isEncodable(v) then
      return false
    end
  end
  return true, maxIndex
end
function isEncodable(o)
  local t = base.type(o)
  return t == "string" or t == "boolean" or t == "number" or t == "nil" or t == "table" or t == "function" and o == null
end
do
  local type = base.type
  local error = base.error
  local assert = base.assert
  local print = base.print
  local tonumber = base.tonumber
  local init_token_table = function(tt)
    local struct = {}
    local value
    function struct:link(other_tt)
      value = other_tt
      return struct
    end
    function struct:to(chars)
      for i = 1, #chars do
        tt[chars:byte(i)] = value
      end
      return struct
    end
    return function(name)
      tt.name = name
      return struct
    end
  end
  local c_esc, c_e, c_l, c_r, c_u, c_f, c_a, c_s, c_slash = tostring("\\elrufas/"):byte(1, 9)
  local tt_object_key, tt_object_colon, tt_object_value, tt_doublequote_string, tt_singlequote_string, tt_array_value, tt_array_seperator, tt_numeric, tt_boolean, tt_null, tt_comment_start, tt_comment_middle, tt_ignore = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
  local strchars = ""
  local allchars = ""
  for i = 0, 255 do
    local c = string.char(i)
    if c ~= "\n" and c ~= "\r" then
      strchars = strchars .. c
    end
    allchars = allchars .. c
  end
  init_token_table(tt_object_key)("object (' or \" or } or , expected)"):link(tt_singlequote_string):to("'"):link(tt_doublequote_string):to("\""):link(true):to("}"):link(tt_object_key):to(","):link(tt_comment_start):to("/"):link(tt_ignore):to(" \t\r\n")
  init_token_table(tt_object_colon)("object (: expected)"):link(tt_object_value):to(":"):link(tt_comment_start):to("/"):link(tt_ignore):to(" \t\r\n")
  init_token_table(tt_object_value)("object ({ or [ or ' or \" or number or boolean or null expected)"):link(tt_object_key):to("{"):link(tt_array_seperator):to("["):link(tt_singlequote_string):to("'"):link(tt_doublequote_string):to("\""):link(tt_numeric):to("0123456789.-"):link(tt_boolean):to("tf"):link(tt_null):to("n"):link(tt_comment_start):to("/"):link(tt_ignore):to(" \t\r\n")
  init_token_table(tt_doublequote_string)("double quoted string"):link(tt_ignore):to(strchars):link(c_esc):to("\\"):link(true):to("\"")
  init_token_table(tt_singlequote_string)("single quoted string"):link(tt_ignore):to(strchars):link(c_esc):to("\\"):link(true):to("'")
  init_token_table(tt_array_value)("array (, or ] expected)"):link(tt_array_seperator):to(","):link(true):to("]"):link(tt_comment_start):to("/"):link(tt_ignore):to(" \t\r\n")
  init_token_table(tt_array_seperator)("array ({ or [ or ] or ' or \" or number or boolean or null expected)"):link(tt_object_key):to("{"):link(tt_array_seperator):to("["):link(true):to("]"):link(tt_singlequote_string):to("'"):link(tt_doublequote_string):to("\""):link(tt_comment_start):to("/"):link(tt_numeric):to("0123456789.-"):link(tt_boolean):to("tf"):link(tt_null):to("n"):link(tt_ignore):to(" \t\r\n")
  init_token_table(tt_numeric)("number"):link(tt_ignore):to("0123456789.-Ee")
  init_token_table(tt_comment_start)("comment start (* expected)"):link(tt_comment_middle):to("*")
  init_token_table(tt_comment_middle)("comment end"):link(tt_ignore):to(allchars):link(true):to("*")
  function decode(js_string)
    local pos = 1
    local function next_byte()
      pos = pos + 1
      return js_string:byte(pos - 1)
    end
    local function location()
      local n = tostring("\n"):byte()
      local line, lpos = 1, 0
      for i = 1, pos do
        if js_string:byte(i) == n then
          line, lpos = line + 1, 1
        else
          lpos = lpos + 1
        end
      end
      return "Line " .. line .. " character " .. lpos
    end
    local function next_token(tok)
      while pos <= #js_string do
        local b = js_string:byte(pos)
        local t = tok[b]
        if not t then
          error("Unexpected character at " .. location() .. ": " .. string.char(b) .. " (" .. b .. ") when reading " .. tok.name .. [[

Context: 
]] .. js_string:sub(math.max(1, pos - 30), pos + 30) .. "\n" .. tostring(" "):rep(pos + math.min(-1, 30 - pos)) .. "^")
        end
        pos = pos + 1
        if t ~= tt_ignore then
          return t
        end
      end
      error("unexpected termination of JSON while looking for " .. tok.name)
    end
    local function read_string(tok)
      local start = pos
      repeat
        local t = next_token(tok)
        if t == c_esc then
          pos = pos + 1
        end
      until t == true
      return (base.loadstring("return " .. js_string:sub(start - 1, pos - 1))())
    end
    local function read_num()
      local start = pos
      while pos <= #js_string do
        local b = js_string:byte(pos)
        if not tt_numeric[b] then
          break
        end
        pos = pos + 1
      end
      return tonumber(js_string:sub(start - 1, pos - 1))
    end
    local function read_bool()
      pos = pos + 3
      local a, b, c, d = js_string:byte(pos - 3, pos)
      if a == c_r and b == c_u and c == c_e then
        return true
      end
      pos = pos + 1
      if a ~= c_a or b ~= c_l or c ~= c_s or d ~= c_e then
        error("Invalid boolean: " .. js_string:sub(math.max(1, pos - 5), pos + 5))
      end
      return false
    end
    local function read_null()
      pos = pos + 3
      local u, l1, l2 = js_string:byte(pos - 3, pos - 1)
      if u == c_u and l1 == c_l and l2 == c_l then
        return nil
      end
      error("Invalid value (expected null):" .. js_string:sub(pos - 4, pos - 1) .. " (" .. js_string:byte(pos - 1) .. "=" .. js_string:sub(pos - 1, pos - 1) .. " / " .. c_l .. ")")
    end
    local read_object_value, read_object_key, read_array, read_value, read_comment
    function read_value(t, fromt)
      if t == tt_object_key then
        return read_object_key({})
      end
      if t == tt_array_seperator then
        return read_array({})
      end
      if t == tt_singlequote_string or t == tt_doublequote_string then
        return read_string(t)
      end
      if t == tt_numeric then
        return read_num()
      end
      if t == tt_boolean then
        return read_bool()
      end
      if t == tt_null then
        return read_null()
      end
      if t == tt_comment_start then
        return read_value(read_comment(fromt))
      end
      error("unexpected termination of - " .. js_string:sub(math.max(1, pos - 10), pos + 10))
    end
    function read_comment(fromt)
      while true do
        while true do
          next_token(tt_comment_start)
          while true do
            repeat
              local t = next_token(tt_comment_middle)
            until next_byte() == c_slash
            local t = next_token(fromt)
            if t ~= tt_comment_start then
              return t
            end
          end
        end
      end
    end
    function read_array(o, i)
      i = i or 1
      local tt = tt_array_seperator
      while true do
        do
          local t = next_token(tt)
          if t == tt_comment_start then
            t = read_comment(tt)
          end
          if t == true then
            return o
          end
          o[i] = read_value(t, tt)
          t = next_token(tt_array_value)
          if t == tt_comment_start then
            t = read_comment(tt_array_value)
          end
          if t == true then
            return o
          end
          i = i + 1
        end
      end
    end
    function read_object_value(o)
      local t = next_token(tt_object_value)
      return read_value(t, tt_object_value)
    end
    function read_object_key(o)
      while true do
        do
          local t = next_token(tt_object_key)
          if t == tt_comment_start then
            t = read_comment(tt_object_key)
          end
          if t == true then
            return o
          end
          if t == tt_object_key then
            return read_object_key(o)
          end
          local k = read_string(t)
          if next_token(tt_object_colon) == tt_comment_start then
            t = read_comment(tt_object_colon)
          end
          local v = read_object_value(o)
          o[k] = v
        end
      end
    end
    local r = read_object_value()
    if pos <= #js_string then
      return r
    end
  end
end
