local isregulararray = function(T)
  local n = 1
  for k, v in pairs(T) do
    if rawget(T, n) == nil then
      return false
    end
    n = n + 1
  end
  return true
end
local dump_pool = {}
dump_pool.__index = dump_pool
local all_dumps = setmetatable({}, {__mode = "k"})
function dump_pool:new(dump_locales, dump_upvalues, dump_metatables, dump_stacks, dump_fenv, keep_reference)
  if dump_locales then
  else
    -- unhandled boolean indicator
  end
  if dump_upvalues then
  else
    -- unhandled boolean indicator
  end
  if dump_metatables then
  else
    -- unhandled boolean indicator
  end
  if dump_stacks then
  else
    -- unhandled boolean indicator
  end
  if dump_fenv then
  else
    -- unhandled boolean indicator
  end
  if keep_reference then
  else
    -- unhandled boolean indicator
  end
  local dump = setmetatable({
    current_id = 1,
    tables = {},
    dump = {},
    dump_locales = true,
    dump_upvalues = true,
    dump_metatables = true,
    dump_stacks = true,
    dump_fenv = true,
    keep_reference = true
  }, self)
  all_dumps[dump] = true
  return dump
end
function dump_pool:_next_id()
  local id = self.current_id
  self.current_id = id + 1
  return id
end
function dump_pool:_register_new(value)
  local id = self.current_id
  self.current_id = id + 1
  self.tables[value] = id
  return id
end
function dump_pool:_metatable(value, result, depth)
  if self.dump_metatables then
    local mt = getmetatable(value)
    if mt then
      result.metatable = self[type(mt)](self, mt, depth - 1)
      if mt.__len then
        result.length = #value
      end
    end
  end
  return result
end
function dump_pool:_field(dest, key, value, depth)
  local dkey, dvalue = self[type(key)](self, key, depth - 1), self[type(value)](self, value, depth - 1)
  if dkey and dvalue then
    dest[#dest + 1] = {dkey, dvalue}
  end
end
function dump_pool:table(value, depth)
  depth = depth or math.huge
  if depth < 0 then
    return nil
  end
  if all_dumps[value] then
    return nil
  end
  local id = self.tables[value]
  if not id then
    id = self:_register_new(value)
    local t = {
      type = "table",
      repr = tostring(value),
      ref = self.keep_reference and value or nil
    }
    if not not next(value) then
      -- unhandled boolean indicator
    else
    end
    t.array = true
    for k, v in t.array and ipairs or pairs(value) do
      self:_field(t, k, v, depth)
    end
    t.length = #value
    self:_metatable(value, t, depth)
    self.dump[id] = t
  end
  return id
end
function dump_pool:userdata(value, depth)
  depth = depth or math.huge
  if depth < 0 then
    return nil
  end
  return self:_metatable(value, {
    type = "userdata",
    repr = tostring(value),
    ref = self.keep_reference and value or nil
  }, depth)
end
function dump_pool:thread(value, depth)
  depth = depth or math.huge
  if depth < 0 then
    return nil
  end
  local result = {
    type = "thread",
    repr = tostring(value),
    status = coroutine.status(value),
    ref = self.keep_reference and value or nil
  }
  local stack = self.tables[value]
  if self.dump_stacks and not stack then
    stack = self:_register_new(value)
    local stack_table = {type = "special"}
    for i = 1, math.huge do
      if not debug.getinfo(value, i, "f") then
        break
      end
      stack_table[#stack_table + 1] = {
        self:number(i, depth - 1),
        self["function"](self, i, depth - 1, value)
      }
    end
    stack_table.repr = tostring(#stack_table) .. " levels"
    self.dump[stack] = stack_table
  end
  result.stack = stack
  return result
end
dump_pool["function"] = function(self, value, depth, thread)
  depth = depth or math.huge
  if depth < 0 then
    return nil
  end
  local info = thread and debug.getinfo(thread, value, "nSfl") or debug.getinfo(value, "nSfl")
  local func = info.func
  local result = {
    type = "function",
    ref = self.keep_reference and func or nil
  }
  result.kind = info.what
  if info.name and 0 < #info.name then
    result.repr = "function: " .. info.name
  elseif func then
    result.repr = tostring(func)
  else
    result.repr = "<tail call>"
  end
  if not func then
    return result
  end
  if info.what ~= "C" then
    if info.source:sub(1, 1) == "@" then
      result.file = info.source:sub(2)
    end
    result.line_from = info.linedefined
    result.line_to = info.lastlinedefined
    if 0 <= info.currentline then
      result.line_current = info.currentline
    end
  end
  local env = getfenv(func)
  if self.dump_fenv and env ~= getfenv(0) then
    result.environment = self:table(env, depth - 1)
  end
  local upvalues = self.tables[func]
  if self.dump_upvalues and not upvalues and func and debug.getupvalue(func, 1) then
    local ups_table = {type = "special"}
    upvalues = self:_register_new(func)
    for i = 1, math.huge do
      local name, val = debug.getupvalue(func, i)
      if not name then
        break
      end
      self:_field(ups_table, name, val, depth)
    end
    ups_table.repr = tostring(#ups_table)
    self.dump[upvalues] = ups_table
  end
  result.upvalues = upvalues
  if self.dump_locales and type(value) == "number" then
    if thread then
    else
      local getlocal = function(...)
        return debug.getlocal(thread, ...)
      end or debug.getlocal
    end
    if getlocal(value, 1) then
      local locales = {type = "special"}
      local locales_id = self:_next_id()
      for i = 1, math.huge do
        local name, val = getlocal(value, i)
        if not name then
          break
        elseif name:sub(1, 1) ~= "(" and val ~= self then
          self:_field(locales, name, val, depth)
        end
      end
      locales.repr = tostring(#locales)
      self.dump[locales_id] = locales
      result.locales = locales_id
    end
  end
  return result
end
function dump_pool:string(value, depth)
  depth = depth or math.huge
  if depth < 0 then
    return nil
  end
  return {
    type = "string",
    repr = string.format("%q", value):gsub("\\\n", "\\n"),
    length = #value,
    ref = self.keep_reference and value or nil
  }
end
setmetatable(dump_pool, {
  __index = function(cls, vtype)
    return function(self, value, depth)
      if depth == nil or depth >= 0 then
      else
      end
      return {
        repr = tostring(value),
        type = vtype,
        ref = self.keep_reference and value or nil
      } or nil
    end
  end
})
return dump_pool
