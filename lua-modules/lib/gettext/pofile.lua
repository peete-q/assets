local file = require("file")
local table_insert = table.insert
local _M = {}
_M.__index = _M
function _M.new()
  local self = {}
  setmetatable(self, _M)
  self:clear()
  return self
end
function _M:put(s, refPath, refLine, ctx)
  if s == nil or s == "" or not s:find("%S") then
    return
  end
  local ref = tostring(refPath) .. ":" .. tostring(refLine)
  local rec = self.strings[s]
  if rec == nil then
    rec = {
      refs = {},
      ecomment = ctx
    }
    self.strings[s] = rec
  end
  table_insert(rec.refs, ref)
end
function _M:cat_lua(path)
  local str = file.read(path)
  local printedfile = false
  local linenum = 0
  for line in str:gmatch([[
[^
]+]]) do
    linenum = linenum + 1
    for s in line:gmatch("_%b()") do
      s = s:gsub("^_%(+%s*", ""):gsub("%s*%)+$", "")
      self:put(str, path, linenum)
    end
  end
end
function _M:cat_po(path)
end
function _M:cat(path)
  if path:find("%.lua$") then
    return self:cat_lua(path)
  end
  if path:find("%.po[t]?$") then
    return self:cat_po(path)
  end
  error("unknown file format: " .. path)
end
function _M:clear()
  self.strings = {}
  self.errors = 0
end
function _M:save(path)
  local out
  if type(path) == "string" then
    do
      local err
      out, err = io.open(path, "w")
      if not out then
        error("error opening " .. path .. " for write: " .. err)
      end
    end
  else
    out = path
  end
  for s, rec in pairs(self.strings) do
    if #rec.refs > 0 then
      for _, r in ipairs(rec.refs) do
        out:write(string.format("#: %s\n", r))
      end
    end
    if rec.ecomment then
      out:write("#. ")
      local _s = rec.ecomment:gsub("\n", [[

%#. ]])
      out:write(_s)
      out:write("\n")
    end
    if s:find("%%%-*[0-9]*[fdsq]") then
      out:write("#, c-format\n")
    end
    out:write(string.format("msgid \"%s\"\n", s:gsub("\"", "\\\"")))
    out:write([[
msgstr ""

]])
  end
  if type(path) == "string" then
    out:close()
  end
end
return _M
