local string_len = string.len
local string_rep = string.rep
local table_insert = table.insert
local math_floor = math.floor
local file = require("file")
local _debug, _warn, _error = require("qlog").loggers("gettext")
local _M = {}
local _passthru = function(s)
  return s
end
local function _starify(s)
  return string_rep("*", math_floor(string_len(s) * 1.4)), true
end
local strfind = string.find
local strsub = string.sub
local function strsplit(delim, text)
  if delim == "" then
    return {text}
  end
  local list = {}
  local pos = 1
  while true do
    do
      local first, last = strfind(text, delim, pos)
      if first then
        table_insert(list, strsub(text, pos, first - 1))
        pos = last + 1
      else
        table_insert(list, strsub(text, pos))
        break
      end
    end
  end
  return list
end
_M.gettext = _passthru
function _M.setlang(preferred_langs, search_path, global_shortcut)
  local func
  if preferred_langs == "*" then
    func = _starify
  elseif preferred_langs == nil then
    func = _passthru
  elseif type(preferred_langs) == "table" then
    search_path = strsplit(";", search_path)
    do
      local textBundle = MOAITextBundle.new()
      local loaded = false
      local d = {}
      table_insert(d, "Preferred Languages:")
      for i, lang in ipairs(preferred_langs) do
        for j, pattern in ipairs(search_path) do
          local f = pattern:gsub("%?", lang)
          if file.exists(f) then
            if not loaded and textBundle:load(f) then
              loaded = true
              table_insert(d, "[" .. lang .. "]")
            else
              table_insert(d, "(" .. lang .. ")")
            end
          else
            table_insert(d, lang)
          end
        end
      end
      _debug(table.concat(d, " "))
      if loaded then
        function func(s)
          return textBundle:lookup(s)
        end
      else
        textBundle = nil
        _warn("preferred language not found, using default")
        func = _passthru
      end
    end
  end
  _M.gettext = func
  if global_shortcut == nil or global_shortcut then
    _G._ = func
  end
end
return _M
