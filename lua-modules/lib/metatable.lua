local _M = {}
function _M.inject(t, newmt)
  if type(newmt) ~= "table" then
    error("invalid metatable: " .. tostring(newmt))
  end
  local mt = getmetatable(t)
  if mt ~= nil then
    do
      local oldindex = mt.__index
      if type(oldindex) == "table" then
        function mt.__index(t, k)
          return newmt[k] or oldindex[k]
        end
      else
        function mt.__index(t, k)
          return newmt[k] or oldindex(t, k)
        end
      end
    end
  else
    setmetatable(t, {__index = newmt})
  end
end
function _M.copyinto(t, meta)
  if meta == nil then
    return
  end
  for k, v in pairs(meta) do
    if k ~= "__index" and k ~= "__newindex" and k ~= "__metatable" then
      t[k] = v
    end
  end
  if type(meta.__index) == "table" and meta.__index ~= meta then
    _M.copyinto(t, meta.__index)
  end
  _M.copyinto(t, getmetatable(meta))
  return t
end
local write = io.write
local string_rep = string.rep
local function prettyln(indent, ...)
  write(string_rep(" ", indent or 0))
  local n = select("#", ...)
  for i = 1, n do
    write(select(i, ...))
  end
  write("\n")
end
local function table_print(tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    write(tostring(tt))
    if not done[tt] then
      done[tt] = true
      write("\n")
      write(string_rep(" ", indent))
      write("{")
      write("\n")
      indent = indent + 2
      for key, value in pairs(tt) do
        write(string_rep(" ", indent))
        write("[" .. tostring(key) .. "] => ")
        if value == tt then
          write("(self)\n")
        else
          table_print(value, indent, done)
        end
      end
      do
        local mt = getmetatable(tt)
        if mt ~= nil then
          write(string_rep(" ", indent))
          write("~metatable: ")
          table_print(mt, indent, done)
        end
        indent = indent - 2
        write(string_rep(" ", indent))
        write("}")
        write("\n")
      end
    else
      write(" -- see above\n")
    end
  elseif type(tt) == "function" then
    write(tostring(tt))
    if done[tt] then
      do
        local count = 1
        while true do
          do
            local n, v = debug.getupvalue(tt, count)
            if n == nil then
              break
            end
            count = count + 1
          end
        end
        if count > 1 then
          write(" -- upvalues: ")
          write(tostring(count - 1))
        end
        write("\n")
      end
    else
      done[tt] = true
      local i = 1
      while true do
        do
          local n, v = debug.getupvalue(tt, i)
          if n == nil then
            break
          end
          if i == 1 then
            write("\n")
            write(string_rep(" ", indent))
            write("(\n")
          end
          write(string_rep(" ", indent + 2))
          write(n .. " = ")
          table_print(v, indent + 4, done)
          i = i + 1
        end
      end
      if i > 1 then
        write(string_rep(" ", indent))
        write(")")
        write("\n")
      else
        write("\n")
      end
    end
  elseif type(tt) == "userdata" then
    write(tostring(tt))
    do
      local mt = getmetatable(tt)
      if mt ~= nil then
        write(" ~metatable => ")
        table_print(mt, indent + 2, done)
      else
        write("\n")
      end
    end
  elseif type(tt) == "string" then
    write(string.format("%q\n", tt))
  else
    write(tostring(tt))
    write("\n")
  end
end
_M.table_print = table_print
return _M
