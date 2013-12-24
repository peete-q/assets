local blockingtcp = {}
do
  local socketcore = require("socket.core")
  local reg = debug.getregistry()
  blockingtcp.sleep = socketcore.sleep
  blockingtcp.connect = reg["tcp{master}"].__index.connect
  blockingtcp.receive = reg["tcp{client}"].__index.receive
  blockingtcp.send = reg["tcp{client}"].__index.send
  blockingtcp.settimeout = reg["tcp{master}"].__index.settimeout
  assert(debug.getinfo(blockingtcp.connect, "S").what == "C", "The debugger needs the real socket functions !")
  package.loaded.socket = nil
end
pcall(require, "sched")
local socket = require("socket")
local url = require("socket.url")
local mime = require("mime")
local ltn12 = require("ltn12")
local log = select(2, pcall(require, "log"))
if type(log) == "string" then
  do
    local LEVELS = {
      ERROR = 0,
      WARNING = 1,
      INFO = 2,
      DETAIL = 3,
      DEBUG = 4
    }
    local LOG_LEVEL = -1
    function log(mod, level, msg, ...)
      if (LEVELS[level] or -1) > LOG_LEVEL then
        return
      end
      if select("#", ...) > 0 then
        msg = msg:format(...)
      end
      io.base.stderr:write(string.format("%s\t%s\t%s\n", mod, level, msg))
    end
  end
end
local debug_getinfo, corunning, cocreate, cowrap, coyield, coresume, costatus = debug.getinfo, coroutine.running, coroutine.create, coroutine.wrap, coroutine.yield, coroutine.resume, coroutine.status
local function getinfo(coro, level, what)
  if coro then
    return debug_getinfo(coro, level, what)
  else
    return debug_getinfo(level + 1, what)
  end
end
local platform = "unix"
do
  local iswindows = function()
    local p = io.popen("echo %os%")
    if p then
      local result = p:read("*l")
      p:close()
      return result == "Windows_NT"
    end
    return false
  end
  local function setplatform()
    if iswindows() then
      platform = "win"
    end
  end
  pcall(setplatform)
end
local path_sep = platform == "unix" and "/" or "\\"
local base_dir
if platform == "unix" then
  base_dir = os.getenv("PWD")
else
  local p = io.popen("echo %cd%")
  if p then
    base_dir = p:read("*l")
    base_dir = string.gsub(base_dir, "\\", "/")
    p:close()
  end
end
if not base_dir then
  error("Unable to determine the working directory.")
end
local is_path_absolute
if platform == "unix" then
  function is_path_absolute(path)
    return path:sub(1, 1) == "/"
  end
else
  function is_path_absolute(path)
    return path:match("^%a:/")
  end
end
local normalize
if platform == "unix" then
  function normalize(path)
    return path:gsub("//", "/")
  end
else
  function normalize(path)
    return path:gsub("\\", "/"):gsub("//", "/")
  end
end
local split = function(path, sep)
  local t = {}
  for w in string.gfind(path, "[^" .. sep .. "]+") do
    table.insert(t, w)
  end
  return t
end
local function merge_paths(absolutepath, relativepath, separator)
  local sep = separator or "/"
  local absolutetable = split(absolutepath, sep)
  local relativetable = split(relativepath, sep)
  for i, path in ipairs(relativetable) do
    if path == ".." then
      table.remove(absolutetable, table.getn(absolutetable))
    elseif path ~= "." then
      table.insert(absolutetable, path)
    end
  end
  return sep .. table.concat(absolutetable, sep)
end
local to_file_uri
if platform == "unix" then
  function to_file_uri(path)
    return url.build({
      scheme = "file",
      authority = "",
      path = path
    })
  end
else
  function to_file_uri(path)
    return url.build({
      scheme = "file",
      authority = "",
      path = "/" .. path
    })
  end
end
local to_path
if platform == "unix" then
  function to_path(url)
    return url.path
  end
else
  function to_path(url)
    return url.path:gsub("^/", "")
  end
end
local debugger_uri, active_session
local active_coroutines = {
  n = 0,
  from_id = setmetatable({}, {__mode = "v"}),
  from_coro = setmetatable({}, {__mode = "k"})
}
local constant_features = {
  language_supports_threads = 0,
  language_name = "Lua",
  language_version = _VERSION,
  protocol_version = 1,
  supports_async = 1,
  data_encoding = "base64",
  breakpoint_languages = "Lua",
  breakpoint_types = "line conditional"
}
local variable_features = setmetatable({}, {
  validators = {
    multiple_sessions = tonumber,
    max_children = tonumber,
    max_data = tonumber,
    max_depth = tonumber,
    show_hidden = tonumber
  },
  __index = {
    multiple_sessions = 0,
    encoding = "UTF-8",
    max_children = 32,
    max_data = 65535,
    max_depth = 1,
    show_hidden = 1,
    uri = "file"
  },
  __newindex = function(self, k, v)
    local mt = getmetatable(self)
    local values, validators = mt.__index, mt.validators
    if values[k] == nil then
      error("No such feature " .. tostring(k))
    end
    v = validators[k] or tostring(v)
    values[k] = v
  end
})
local function b64(data)
  local filter = ltn12.filter.chain(mime.encode("base64"), mime.wrap("base64"))
  local sink, output = ltn12.sink.table()
  ltn12.pump.all(ltn12.source.string(data), ltn12.sink.chain(filter, sink))
  return table.concat(output)
end
local function rawb64(data)
  return (mime.b64(data))
end
local function unb64(data)
  return (mime.unb64(data))
end
local arg_parse = function(cmd_args)
  local args = {}
  for arg, val in cmd_args:gmatch("%-(%w) (%S+)") do
    args[arg] = val
  end
  return args
end
local function cmd_parse(cmd)
  local cmd_name, args, data
  if cmd:find("--", 1, true) then
    cmd_name, args, data = cmd:match("^(%S+)%s+(.*)%s+%-%-%s*(.*)$")
  else
    cmd_name, args, data = cmd:match("^(%S+)%s+(.*)$")
  end
  return cmd_name, arg_parse(args), unb64(data)
end
local function read_packet(skt)
  local size = {}
  while true do
    do
      local byte, err = blockingtcp.receive(skt, 1)
      if not byte then
        return nil, err
      end
      if byte == "\000" then
        break
      end
      size[#size + 1] = byte
    end
  end
  return table.concat(size)
end
local get_uri, get_path
do
  local cache = {}
  function get_abs_file_uri(source)
    local uri
    if source:sub(1, 1) == "@" then
      do
        local sourcepath = source:sub(2)
        local normalizedpath = normalize(sourcepath)
        if not is_path_absolute(normalizedpath) then
          normalizedpath = merge_paths(base_dir, normalizedpath)
        end
        return to_file_uri(normalizedpath)
      end
    else
      return false
    end
  end
  function get_module_uri(source)
    local uri
    if source:sub(1, 1) == "@" then
      local sourcepath = source:sub(2)
      local normalizedpath = normalize(sourcepath)
      local normalizedluapath = normalize(package.path)
      local luapathtable = split(normalizedluapath, ";")
      table.insert(luapathtable, "?.lua")
      for i, var in ipairs(luapathtable) do
        local escaped = string.gsub(var, "[%^%$%(%)%%%.%[%]%*%+%-%?]", function(c)
          return "%" .. c
        end)
        local pattern = string.gsub(escaped, "%%%?", "(.+)")
        local modulename = string.match(normalizedpath, pattern)
        if modulename then
          modulename = string.gsub(modulename, "/", ".")
          if not uri or string.len(uri) > string.len(modulename) then
            uri = modulename
          end
        end
      end
      if uri then
        return "module:///" .. uri
      end
    end
    return false
  end
  function get_uri(source)
    local uri = cache[source]
    if uri ~= nil then
      return uri
    end
    if variable_features.uri == "module" then
      uri = get_module_uri(source)
      uri = uri or get_abs_file_uri(source)
    else
      uri = get_abs_file_uri(source)
    end
    cache[source] = uri
    return uri
  end
  function get_path(uri)
    local parsed_path = assert(url.parse(uri))
    if parsed_path.scheme == "file" then
      return to_path(parsed_path)
    else
      for k, v in pairs(cache) do
        if v == uri then
          assert(k:sub(1, 1) == "@")
          return k:sub(2)
        end
      end
    end
  end
end
local key_cache = setmetatable({n = 0}, {__mode = "v"})
local function generate_key(name)
  if type(name) == "string" then
    return string.format("%q", name)
  elseif type(name) == "number" or type(name) == "boolean" then
    return tostring(name)
  else
    local i = key_cache.n
    key_cache[i] = name
    key_cache.n = i + 1
    return "key_cache[" .. tostring(i) .. "]"
  end
end
local generate_printable_key = function(name)
  if type(name) ~= "string" or not string.format("%q", name) then
  end
  return "[" .. tostring(name) .. "]"
end
local DBGP_ERR_METATABLE = {}
local function dbgp_error(code, message, attrs)
  error(setmetatable({
    code = code,
    message = message,
    attrs = attrs or {}
  }, DBGP_ERR_METATABLE), 2)
end
local function dbgp_assert(code, success, ...)
  if not success then
    dbgp_error(code, (...))
  end
  return success, ...
end
local get_script_level = function(l)
  local hook = debug.gethook()
  for i = 2, math.huge do
    if assert(debug.getinfo(i, "f")).func == hook then
      return i + l
    end
  end
end
local Multival = {
  __tostring = function()
    return ""
  end
}
local function packpcall(...)
  local success = (...)
  if success then
  else
    local results = setmetatable({
      n = select("#", ...) - 1,
      select(2, ...)
    }, Multival) or select(2, ...)
  end
  return success, results
end
local xmlattr_specialchars = {
  ["\""] = "&quot;",
  ["<"] = "&lt;",
  ["&"] = "&amp;"
}
local function generateXML(xml)
  local pieces = {}
  local function generate(node)
    pieces[#pieces + 1] = "<" .. node.name
    pieces[#pieces + 1] = " "
    for attr, val in pairs(node.attrs or {}) do
      pieces[#pieces + 1] = attr .. "=\"" .. tostring(val):gsub("[\"&<]", xmlattr_specialchars) .. "\""
      pieces[#pieces + 1] = " "
    end
    pieces[#pieces] = nil
    if node.children then
      pieces[#pieces + 1] = ">"
      for _, child in ipairs(node.children) do
        if type(child) == "table" then
          generate(child)
        else
          pieces[#pieces + 1] = "<![CDATA[" .. tostring(child) .. "]]>"
        end
      end
      pieces[#pieces + 1] = "</" .. node.name .. ">"
    else
      pieces[#pieces + 1] = "/>"
    end
  end
  generate(xml)
  return table.concat(pieces)
end
local function send_xml(skt, resp)
  if not resp.attrs then
    resp.attrs = {}
  end
  resp.attrs.xmlns = "urn:debugger_protocol_v1"
  local data = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n" .. generateXML(resp)
  log("DEBUGGER", "DEBUG", "Send " .. data)
  blockingtcp.send(skt, tostring(#data) .. "\000" .. data .. "\000")
end
local make_error = function(code, msg)
  local elem = {
    name = "error",
    attrs = {code = code}
  }
  if msg then
    elem.children = {
      {
        name = "message",
        children = {
          tostring(msg)
        }
      }
    }
  end
  return elem
end
local debugintrospection = require("debugintrospection")
local function new_function_introspection(...)
  local result = debugintrospection["function"](...)
  if result and result.file then
    result.repr = result.repr .. "\n" .. get_uri("@" .. result.file) .. "\n" .. tostring(result.line_from)
    result.type = "function (Lua)"
  end
  return result
end
local function make_property(context, value, name, fullname, depth, pagesize, page, size_limit, safe_name)
  local dump = debugintrospection:new(false, false, true, false, true, true)
  dump["function"] = new_function_introspection
  local function build_xml(node, name, fullname, page, depth)
    local data = tostring(node.repr)
    local specials = {}
    if node.metatable then
      specials[#specials + 1] = "metatable"
    end
    if node.environment then
      specials[#specials + 1] = "environment"
    end
    local numchildren = #node + #specials
    local attrs = {
      type = node.array and "sequence" or node.type,
      name = name,
      fullname = rawb64(tostring(context) .. "|" .. fullname),
      encoding = "base64",
      children = 0,
      size = #data
    }
    if numchildren > 0 then
      attrs.children = 1
      attrs.numchildren = numchildren
      attrs.pagesize = pagesize
      attrs.page = page
    end
    local children = {
      b64(size_limit and data:sub(1, size_limit) or data)
    }
    if depth > 0 then
      local from, to = page * pagesize + 1, (page + 1) * pagesize
      for i = from, math.min(#node, to) do
        local key, value = unpack(node[i])
        if type(key) == "number" then
          key = dump.dump[key] or key
        end
        if type(value) == "number" then
          value = dump.dump[value] or value
        end
        children[#children + 1] = build_xml(value, "[" .. key.repr .. "]", fullname .. "[" .. generate_key(key.ref) .. "]", 0, depth - 1)
      end
      for i = #node + 1, math.min(to, numchildren) do
        local special = specials[i - #node]
        local prop = build_xml(dump.dump[node[special]], special, special .. "[" .. fullname .. "]", 0, depth - 1)
        prop.attrs.type = "special"
        children[#children + 1] = prop
      end
    end
    return {
      name = "property",
      attrs = attrs,
      children = children
    }
  end
  fullname = fullname or "(...)[" .. generate_key(name) .. "]"
  if not safe_name then
    name = generate_printable_key(name)
  end
  if getmetatable(value) == Multival then
    do
      local children = {}
      for i = 1, value.n do
        local val = dump[type(value[i])](dump, value[i], depth)
        if type(val) == "number" then
          val = dump.dump[val] or val
        end
        children[#children + 1] = build_xml(val, "[" .. i .. "]", generate_key(val.ref), 0, depth - 1)
      end
      if #children == 1 then
        return children[1]
      end
      return {
        attrs = {
          type = "multival",
          name = name,
          fullname = tostring(context) .. "|" .. fullname,
          encoding = "base64",
          numchildren = value.n,
          children = value.n > 0 and 1 or 0,
          size = 0,
          pagesize = pagesize
        },
        children = children,
        name = "property"
      }
    end
  else
    local root = dump[type(value)](dump, value, depth + 1)
    return build_xml(type(root) == "number" and dump.dump[root] or root, name, fullname, page, depth)
  end
end
io.base = {
  output = io.output,
  stdin = io.stdin,
  stdout = io.stdout,
  stderr = io.stderr
}
function print(...)
  local buf = {
    ...
  }
  for i = 1, select("#", ...) do
    buf[i] = tostring(buf[i])
  end
  io.stdout:write(table.concat(buf, "\t") .. "\n")
end
function io.output(output)
  output = io.base.output(output)
  return io.stdout
end
local dummy = function()
end
local redirect_output = {
  write = function(self, ...)
    local buf = {
      ...
    }
    for i = 1, select("#", ...) do
      buf[i] = tostring(buf[i])
    end
    buf = table.concat(buf):gsub("\n", "\r\n")
    send_xml(self.skt, {
      name = "stream",
      attrs = {
        type = self.mode
      },
      children = {
        b64(buf)
      }
    })
  end,
  flush = dummy,
  close = dummy,
  setvbuf = dummy,
  seek = dummy
}
redirect_output.__index = redirect_output
local copy_output = {
  write = function(self, ...)
    redirect_output.write(self, ...)
    io.base[self.mode]:write(...)
  end,
  flush = function(self, ...)
    return self.out:flush(...)
  end,
  close = function(self, ...)
    return self.out:close(...)
  end,
  setvbuf = function(self, ...)
    return self.out:setvbuf(...)
  end,
  seek = function(self, ...)
    return self.out:seek(...)
  end
}
copy_output.__index = copy_output
local function output_command_handler_factory(mode)
  return function(self, args)
    if args.c == "0" then
      io[mode] = io.base[mode]
    else
      io[mode] = setmetatable({
        skt = self.skt,
        mode = mode
      }, args.c == "1" and copy_output or redirect_output)
    end
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = mode,
        transaction_id = args.i,
        success = "1"
      }
    })
  end
end
local Context
do
  local LOCAL, UPVAL, GLOBAL, STORE, HANDLE = {}, {}, {}, {}, {}
  local foreign_coro_debug = {
    getlocal = debug.getlocal,
    setlocal = debug.setlocal,
    getinfo = debug.getinfo
  }
  local current_coro_debug = {
    getlocal = function(_, level, index)
      return debug.getlocal(get_script_level(level), index)
    end,
    setlocal = function(_, level, index, value)
      return debug.setlocal(get_script_level(level), index, value)
    end,
    getinfo = function(_, level, what)
      return debug.getinfo(get_script_level(level), what)
    end
  }
  Context = {
    [0] = LOCAL,
    [1] = GLOBAL,
    [2] = UPVAL,
    ["__index"] = function(self, k)
      if self[LOCAL][STORE][k] then
        return self[LOCAL][k]
      elseif self[UPVAL][STORE][k] then
        return self[UPVAL][k]
      else
        return self[GLOBAL][k]
      end
    end,
    ["__newindex"] = function(self, k, v)
      if self[LOCAL][STORE][k] then
        self[LOCAL][k] = v
      elseif self[UPVAL][STORE][k] then
        self[UPVAL][k] = v
      else
        self[GLOBAL][k] = v
      end
    end,
    ["LocalContext"] = {
      __index = function(self, k)
        local index = self[STORE][k]
        if not index then
          error("The local " .. tostring(k) .. " does not exitsts.")
        end
        local handle = self[HANDLE]
        return select(2, handle.callbacks.getlocal(handle.coro, handle.level, index))
      end,
      __newindex = function(self, k, v)
        local index = self[STORE][k]
        if index then
          do
            local handle = self[HANDLE]
            handle.callbacks.setlocal(handle.coro, handle.level, index, v)
          end
        else
          error("Cannot set local " .. k)
        end
      end,
      iterator = function(self, prev)
        local key, index = next(self[STORE], prev)
        if key then
          return key, self[key]
        else
          return nil
        end
      end
    },
    ["UpvalContext"] = {
      __index = function(self, k)
        local index = self[STORE][k]
        if not index then
          error("The local " .. tostring(k) .. " does not exitsts.")
        end
        return select(2, debug.getupvalue(self[HANDLE], index))
      end,
      __newindex = function(self, k, v)
        local index = self[STORE][k]
        if index then
          debug.setupvalue(self[HANDLE], index, v)
        else
          error("Cannot set upvalue " .. k)
        end
      end,
      iterator = function(self, prev)
        local key, index = next(self[STORE], prev)
        if key then
          return key, self[key]
        else
          return nil
        end
      end
    },
    ["new"] = function(cls, coro, level)
      local locals, upvalues = {}, {}
      local debugcallbacks = coro and foreign_coro_debug or current_coro_debug
      local func = debugcallbacks.getinfo(coro, level, "f") or dbgp_error(301, "No such stack level: " .. tostring(level)).func
      for i = 1, math.huge do
        local name, val = debugcallbacks.getlocal(coro, level, i)
        if not name then
          break
        elseif name:sub(1, 1) ~= "(" then
          locals[name] = i
        end
      end
      for i = 1, math.huge do
        local name, val = debug.getupvalue(func, i)
        if not name then
          break
        end
        upvalues[name] = i
      end
      locals = setmetatable({
        [STORE] = locals,
        [HANDLE] = {
          callbacks = debugcallbacks,
          level = level,
          coro = coro
        }
      }, cls.LocalContext)
      upvalues = setmetatable({
        [STORE] = upvalues,
        [HANDLE] = func
      }, cls.UpvalContext)
      return setmetatable({
        [LOCAL] = locals,
        [UPVAL] = upvalues,
        [GLOBAL] = debug.getfenv(func)
      }, cls)
    end
  }
end
local function ContextManager()
  local cache = {}
  return function(thread, level)
    local thread_contexts = cache[thread or true]
    if not thread_contexts then
      thread_contexts = {}
      cache[thread or true] = thread_contexts
    end
    local context = thread_contexts[level]
    if not context then
      context = Context:new(thread, level)
      thread_contexts[level] = context
    end
    return context
  end
end
local property_evaluation_environment = {
  key_cache = key_cache,
  metatable = setmetatable({}, {
    __index = function(self, tbl)
      return getmetatable(tbl)
    end,
    __newindex = function(self, tbl, mt)
      return setmetatable(tbl, mt)
    end
  }),
  environment = setmetatable({}, {
    __index = function(self, func)
      return getfenv(func)
    end,
    __newindex = function(self, func, env)
      return setfenv(func, env)
    end
  })
}
property_evaluation_environment.__index = property_evaluation_environment
local stack_levels = setmetatable({}, {__mode = "k"})
local breakpoints = {
  hit_conditions = {
    [">="] = function(value, target)
      return target <= value
    end,
    ["=="] = function(value, target)
      return value == target
    end,
    ["%"] = function(value, target)
      return value % target == 0
    end
  }
}
local events = {}
do
  local file_mapping = {}
  local id_mapping = {}
  local waiting_sessions = {}
  local step_into
  local sequence = 0
  function breakpoints.insert(bp)
    local bpid = sequence
    sequence = bpid + 1
    bp.id = bpid
    local uri = url.parse(bp.filename)
    bp.filename = url.build({
      scheme = uri.scheme,
      authority = "",
      path = uri.path
    })
    local filereg = file_mapping[bp.filename]
    if not filereg then
      filereg = {}
      file_mapping[bp.filename] = filereg
    end
    local linereg = filereg[bp.lineno]
    if not linereg then
      linereg = {}
      filereg[bp.lineno] = linereg
    end
    table.insert(linereg, bp)
    id_mapping[bpid] = bp
    return bpid
  end
  function breakpoints.at(file, line)
    local bps = file_mapping[file] and file_mapping[file][line]
    if not bps then
      return nil
    end
    local do_break = false
    for _, bp in pairs(bps) do
      if bp.state == "enabled" then
        local match = true
        match = bp.condition and true
        if match then
          bp.hit_count = bp.hit_count + 1
          if breakpoints.hit_conditions[bp.hit_condition](bp.hit_count, bp.hit_value) then
            if bp.temporary then
              breakpoints.remove(bp.id)
            end
            do_break = true
          end
        end
      end
    end
    return do_break
  end
  function breakpoints.get(id)
    if id then
      return id_mapping[id]
    else
      return id_mapping
    end
  end
  function breakpoints.remove(id)
    local bp = id_mapping[id]
    if bp then
      id_mapping[id] = nil
      local linereg = file_mapping[bp.filename][bp.lineno]
      for i = 1, #linereg do
        if linereg[i] == bp then
          table.remove(linereg, i)
          break
        end
      end
      if not next(linereg) then
        file_mapping[bp.filename][bp.lineno] = nil
      end
      if not next(file_mapping[bp.filename]) then
        file_mapping[bp.filename] = nil
      end
      return true
    end
    return false
  end
  function breakpoints.get_xml(id)
    local bp = id_mapping[id]
    if not bp then
      return nil, "No such breakpoint: " .. tostring(id)
    end
    local response = {
      name = "breakpoint",
      attrs = {}
    }
    for k, v in pairs(bp) do
      response.attrs[k] = v
    end
    if bp.expression then
      response.children = {
        {
          name = "expression",
          children = {
            bp.expression
          }
        }
      }
    end
    response.attrs.expression = nil
    response.attrs.condition = nil
    response.attrs.temporary = nil
    return response
  end
  function events.register(event)
    local thread = coroutine.running() or "main"
    log("DEBUGGER", "DEBUG", "Registered %s event for %s (%d)", event, tostring(thread), stack_levels[thread])
    if event == "into" then
      step_into = true
    else
      waiting_sessions[thread] = {
        event,
        stack_levels[thread]
      }
    end
  end
  function events.does_match()
    if step_into then
      return true
    end
    local thread = coroutine.running() or "main"
    local event = waiting_sessions[thread]
    if event then
      local event_type, target_level = unpack(event)
      local current_level = stack_levels[thread]
      if event_type == "over" and target_level >= current_level or event_type == "out" and target_level > current_level then
        log("DEBUGGER", "DEBUG", "Event %s matched!", event_type)
        return true
      end
    end
    return false
  end
  function events.discard()
    waiting_sessions[coroutine.running() or "main"] = nil
    step_into = nil
  end
end
local function previous_context_response(self, reason)
  self.previous_context.status = self.state
  self.previous_context.reason = reason or "ok"
  send_xml(self.skt, {
    name = "response",
    attrs = self.previous_context
  })
  self.previous_context = nil
end
local function get_coroutine(coro_id)
  if coro_id then
    coro = dbgp_assert(399, active_coroutines.from_id[tonumber(coro_id)], "No such coroutine")
    dbgp_assert(399, coroutine.status(coro) ~= "dead", "Coroutine is dead")
    return coro ~= corunning() and coro or nil
  end
  return nil
end
local commands
commands = {
  ["break"] = function(self, args)
    self.state = "break"
    previous_context_response(self)
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = "break",
        transaction_id = args.i,
        success = 1
      }
    })
    return false
  end,
  ["status"] = function(self, args)
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = "status",
        reason = "ok",
        status = self.state,
        transaction_id = args.i
      }
    })
  end,
  ["stop"] = function(self, args)
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = "stop",
        reason = "ok",
        status = "stopped",
        transaction_id = args.i
      }
    })
    self.skt:close()
    os.exit(1)
  end,
  ["feature_get"] = function(self, args)
    local name = args.n
    local response = constant_features[name] or variable_features[name] or not not commands[name]
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = "feature_get",
        feature_name = name,
        supported = response and "1" or "0",
        transaction_id = args.i
      },
      children = {
        tostring(response)
      }
    })
  end,
  ["feature_set"] = function(self, args)
    local name, value = args.n, args.v
    local success = 0
    if variable_features[name] then
      variable_features[name] = value
      success = 1
    end
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = "feature_set",
        feature = name,
        success = success,
        transaction_id = args.i
      }
    })
  end,
  ["typemap_get"] = function(self, args)
    local gentype = function(name, type, xsdtype)
      return {
        name = "map",
        attrs = {
          ["name"] = name,
          ["type"] = type,
          ["xsi:type"] = xsdtype
        }
      }
    end
    send_xml(self.skt, {
      name = "response",
      attrs = {
        ["command"] = "typemap_get",
        ["transaction_id"] = args.i,
        ["xmlns:xsi"] = "http://www.w3.org/2001/XMLSchema-instance",
        ["xmlns:xsd"] = "http://www.w3.org/2001/XMLSchema"
      },
      children = {
        gentype("nil", "null"),
        gentype("boolean", "bool", "xsd:boolean"),
        gentype("number", "float", "xsd:float"),
        gentype("string", "string", "xsd:string"),
        gentype("function", "resource"),
        gentype("userdata", "resource"),
        gentype("thread", "resource"),
        gentype("table", "hash"),
        gentype("sequence", "array"),
        gentype("multival", "array")
      }
    })
  end,
  ["run"] = function(self)
    return true
  end,
  ["step_over"] = function(self)
    events.register("over")
    return true
  end,
  ["step_out"] = function(self)
    events.register("out")
    return true
  end,
  ["step_into"] = function(self)
    events.register("into")
    return true
  end,
  ["eval"] = function(self, args, data)
    log("DEBUGGER", "DEBUG", "Going to eval " .. data)
    local result, err, success
    local func, err = loadstring("return " .. data)
    if not func then
      func, err = loadstring(data)
    end
    if func then
      setfenv(func, self.stack(nil, 0))
      success, result = packpcall(pcall(func))
      if not success then
        err = result
      end
    end
    local response = {
      name = "response",
      attrs = {
        command = "eval",
        transaction_id = args.i
      }
    }
    if not err then
      response.attrs.success = 1
      response.children = {
        make_property(0, result, data, "", 1, 8000, 0, nil)
      }
    else
      response.attrs.success = 0
      response.children = {
        make_error(206, err)
      }
    end
    send_xml(self.skt, response)
  end,
  ["stdout"] = output_command_handler_factory("stdout"),
  ["stderr"] = output_command_handler_factory("stderr"),
  ["breakpoint_set"] = function(self, args, data)
    if args.o and not breakpoints.hit_conditions[args.o] then
      dbgp_error(200, "Invalid hit_condition operator: " .. args.o)
    end
    local filename, lineno = args.f, tonumber(args.n)
    local bp = {
      type = args.t,
      state = args.s or "enabled",
      temporary = args.r == "1",
      hit_count = 0,
      filename = filename,
      lineno = lineno,
      hit_value = tonumber(args.h or 0),
      hit_condition = args.o or ">="
    }
    if args.t == "conditional" then
      bp.expression = data
      bp.condition = dbgp_assert(207, loadstring("return (" .. data .. ")"))
    elseif args.t ~= "line" then
      dbgp_error(201, "BP type " .. args.t .. " not yet supported")
    end
    local bpid = breakpoints.insert(bp)
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = "breakpoint_set",
        transaction_id = args.i,
        state = bp.state,
        id = bpid
      }
    })
  end,
  ["breakpoint_get"] = function(self, args)
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = "breakpoint_get",
        transaction_id = args.i
      },
      children = {
        dbgp_assert(205, breakpoints.get_xml(tonumber(args.d)))
      }
    })
  end,
  ["breakpoint_list"] = function(self, args)
    local bps = {}
    for id, bp in pairs(breakpoints.get()) do
      bps[#bps + 1] = breakpoints.get_xml(id)
    end
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = "breakpoint_list",
        transaction_id = args.i
      },
      children = bps
    })
  end,
  ["breakpoint_update"] = function(self, args)
    local bp = breakpoints.get(tonumber(args.d))
    if not bp then
      dbgp_error(205, "No such breakpint " .. args.d)
    end
    if args.o and not breakpoints.hit_conditions[args.o] then
      dbgp_error(200, "Invalid hit_condition operator: " .. args.o)
    end
    local response = {
      name = "response",
      attrs = {
        command = "breakpoint_update",
        transaction_id = args.i
      }
    }
    bp.state = args.s or bp.state
    bp.lineno = tonumber(args.n or bp.lineno)
    bp.hit_value = tonumber(args.h or bp.hit_value)
    bp.hit_condition = args.o or bp.hit_condition
    send_xml(self.skt, response)
  end,
  ["breakpoint_remove"] = function(self, args)
    local response = {
      name = "response",
      attrs = {
        command = "breakpoint_remove",
        transaction_id = args.i
      }
    }
    if not breakpoints.remove(tonumber(args.d)) then
      dbgp_error(205, "No such breakpint " .. args.d)
    end
    send_xml(self.skt, response)
  end,
  ["stack_depth"] = function(self, args)
    local depth = 0
    local coro = get_coroutine(args.o)
    if not coro or not 0 then
    end
    for level = get_script_level(0), math.huge do
      local info = getinfo(coro, level, "S")
      if not info then
        break
      end
      depth = depth + 1
      if info.what == "main" then
        break
      end
    end
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = "stack_depth",
        transaction_id = args.i,
        depth = depth
      }
    })
  end,
  ["stack_get"] = function(self, args)
    local what2uri = {
      tail = "tailreturn:/",
      C = "ccode:/"
    }
    local function make_level(info, level)
      local attrs = {
        level = level,
        where = info.name,
        type = "file"
      }
      local uri = get_uri(info.source)
      if uri and info.currentline then
        attrs.filename = uri
        attrs.lineno = info.currentline
      else
        attrs.filename = what2uri[info.what] or "unknown:/"
        attrs.lineno = -1
      end
      return {name = "stack", attrs = attrs}
    end
    local children = {}
    local coro = get_coroutine(args.o)
    local level = coro and 0 or get_script_level(0)
    if args.d then
      do
        local stack_level = tonumber(args.d)
        children[#children + 1] = make_level(getinfo(coro, stack_level + level, "nSl"), stack_level)
      end
    else
      for i = level, math.huge do
        local info = getinfo(coro, i, "nSl")
        if not info then
          break
        end
        children[#children + 1] = make_level(info, i - level)
        if info.what == "main" then
          break
        end
      end
    end
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = "stack_get",
        transaction_id = args.i
      },
      children = children
    })
  end,
  ["coroutine_list"] = function(self, args)
    local running = coroutine.running()
    local coroutines = {}
    for id, coro in pairs(active_coroutines.from_id) do
      if id ~= "n" then
        coroutines[#coroutines + 1] = {
          name = "coroutine",
          attrs = {
            id = id,
            name = tostring(coro),
            running = coro == running and "1" or "0"
          }
        }
      end
    end
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = "coroutine_list",
        transaction_id = args.i
      },
      children = coroutines
    })
  end,
  ["context_names"] = function(self, args)
    local coro = get_coroutine(args.o)
    local level = tonumber(args.d or 0)
    local info = getinfo(coro, coro and level or get_script_level(level), "f") or dbgp_error(301, "No such stack level " .. tostring(level))
    local contexts = {
      {
        name = "context",
        attrs = {name = "Local", id = 0}
      },
      {
        name = "context",
        attrs = {name = "Upvalue", id = 2}
      },
      {
        name = "context",
        attrs = {name = "Global", id = 1}
      }
    }
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = "context_names",
        transaction_id = args.i
      },
      children = contexts
    })
  end,
  ["context_get"] = function(self, args)
    local context = tonumber(args.c or 0)
    local cxt_id = Context[context] or dbgp_error(302, "No such context: " .. tostring(args.c))
    local level = tonumber(args.d or 0)
    local coro = get_coroutine(args.o)
    local cxt = self.stack(coro, level)
    local properties = {}
    if context ~= 1 or not next then
    end
    for name, val in getmetatable(cxt[cxt_id]).iterator, cxt[cxt_id], nil do
      properties[#properties + 1] = make_property(context, val, name, nil, 0, variable_features.max_children, 0, variable_features.max_data, context ~= 1)
    end
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = "context_get",
        transaction_id = args.i,
        context = context
      },
      children = properties
    })
  end,
  ["property_get"] = function(self, args)
    local context, name = assert(unb64(args.n):match("^(%d+)|(.*)$"))
    context = tonumber(args.c or context)
    local cxt_id = Context[context] or dbgp_error(302, "No such context: " .. tostring(args.c))
    local level = tonumber(args.d or 0)
    local coro = get_coroutine(args.o)
    local size = tonumber(args.m or variable_features.max_data)
    if size < 0 then
      size = nil
    end
    local page = tonumber(args.p or 0)
    local cxt = self.stack(coro, level)
    local chunk = dbgp_assert(206, loadstring("return " .. name))
    setfenv(chunk, property_evaluation_environment)
    local prop = select(2, dbgp_assert(300, pcall(chunk, cxt[cxt_id])))
    local response = make_property(context, prop, name, name, variable_features.max_depth, variable_features.max_children, page, size)
    if name:match("^[%w_]+%[.-%b[]%]$") == name then
      response.attrs.type = "special"
    end
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = "property_get",
        transaction_id = args.i,
        context = context
      },
      children = {response}
    })
  end,
  ["property_value"] = function(self, args)
    args.m = -1
    commands.property_get(self, args)
  end,
  ["property_set"] = function(self, args, data)
    local context, name = assert(unb64(args.n):match("^(%d+)|(.*)$"))
    context = tonumber(args.c or context)
    local cxt_id = Context[context] or dbgp_error(302, "No such context: " .. tostring(args.c))
    local level = tonumber(args.d or 0)
    local coro = get_coroutine(args.o)
    local cxt = self.stack(coro, level)
    local value = select(2, dbgp_assert(206, pcall(setfenv(dbgp_assert(206, loadstring("return " .. data)), cxt))))
    local chunk = dbgp_assert(206, loadstring(name .. " = value"))
    setfenv(chunk, setmetatable({value = value}, property_evaluation_environment))
    dbgp_assert(206, pcall(chunk, cxt[cxt_id]))
    send_xml(self.skt, {
      name = "response",
      attrs = {
        success = 1,
        transaction_id = args.i
      }
    })
  end,
  ["source"] = function(self, args)
    local path
    if args.f then
      path = get_path(args.f)
    else
      path = debug.getinfo(get_script_level(0), "S").source
      assert(path:sub(1, 1) == "@")
      path = path:sub(2)
    end
    local file, err = io.open(path)
    if not file then
      dbgp_error(100, err, {success = 0})
    end
    if file:read(1) == "!" then
      dbgp_error(100, args.f .. " is bytecode", {success = 0})
    end
    file:seek("set", 0)
    local source = cowrap(function()
      local beginline, endline, currentline = tonumber(args.b or 0), tonumber(args.e or math.huge), 0
      for line in file:lines() do
        currentline = currentline + 1
        if beginline <= currentline and endline >= currentline then
          coyield(line .. "\n")
        elseif endline <= currentline then
          break
        end
      end
      file:close()
    end)
    local filter = ltn12.filter.chain(mime.encode("base64"), mime.wrap("base64"))
    local output = {}
    local sink = ltn12.sink.chain(filter, ltn12.sink.table(output))
    assert(ltn12.pump.all(source, sink))
    send_xml(self.skt, {
      name = "response",
      attrs = {
        command = "source",
        transaction_id = args.i,
        success = 1
      },
      children = {
        table.concat(output)
      }
    })
  end
}
local function debugger_loop(self, async_packet)
  blockingtcp.settimeout(self.skt, nil)
  local async_mode = async_packet ~= nil
  if self.previous_context and not async_mode then
    self.state = "break"
    previous_context_response(self)
  end
  self.stack = ContextManager()
  while true do
  end
  self.stack = nil
  self.state = "running"
  blockingtcp.settimeout(self.skt, 0)
end
local function debugger_hook(event, line)
  local thread = corunning() or "main"
  if event == "call" then
    stack_levels[thread] = stack_levels[thread] + 1
  elseif event == "return" or event == "tail return" then
    stack_levels[thread] = stack_levels[thread] - 1
  else
    local do_break, packet
    local info = debug_getinfo(2, "S")
    local uri = get_uri(info.source)
    if uri and uri ~= debugger_uri then
      do_break = breakpoints.at(uri, line) or events.does_match()
      if do_break then
        events.discard()
      end
      if not do_break then
        packet = read_packet(active_session.skt)
        if packet then
          do_break = true
        end
      end
    end
    if do_break then
      local success, err = pcall(debugger_loop, active_session, packet)
      if not success then
        log("DEBUGGER", "ERROR", "Error while debug loop: " .. err)
      end
    end
  end
end
local function init(host, port, idekey)
  host = host or os.getenv("DBGP_IDEHOST") or "127.0.0.1"
  port = port or os.getenv("DBGP_IDEPORT") or "10000"
  idekey = idekey or os.getenv("DBGP_IDEKEY") or "luaidekey"
  local skt = assert(socket.tcp())
  blockingtcp.settimeout(skt, nil)
  local ok, err
  for i = 1, 5 do
    ok, err = blockingtcp.connect(skt, host, port)
    if ok then
      break
    end
    blockingtcp.sleep(0.5)
  end
  if err then
    error(string.format("Cannot connect to %s:%d : %s", host, port, err))
  end
  debugger_uri = get_uri(debug.getinfo(1).source)
  local source
  for i = 2, math.huge do
    local info = debug.getinfo(i)
    if not info then
      break
    end
    source = get_uri(info.source) or source
  end
  source = source or "unknown:/"
  local thread = coroutine.running() or "main"
  stack_levels[thread] = 1
  local sessionid = tostring(os.time()) .. "_" .. tostring(thread)
  send_xml(skt, {
    name = "init",
    attrs = {
      appid = "Lua DBGp",
      idekey = idekey,
      session = sessionid,
      thread = tostring(thread),
      parent = "",
      language = "Lua",
      protocol_version = "1.0",
      fileuri = source
    }
  })
  local sess = {
    skt = skt,
    state = "starting",
    id = sessionid
  }
  active_session = sess
  debugger_loop(sess)
  debug.sethook(debugger_hook, "rlc")
  local function resume_handler(coro, ...)
    if costatus(coro) == "dead" then
      local coro_id = active_coroutines.from_coro[coro]
      active_coroutines.from_id[coro_id] = nil
      active_coroutines.from_coro[coro] = nil
      stack_levels[coro] = nil
    end
    return ...
  end
  function coroutine.resume(coro, ...)
    if not stack_levels[coro] then
      stack_levels[coro] = 0
      active_coroutines.n = active_coroutines.n + 1
      active_coroutines.from_id[active_coroutines.n] = coro
      active_coroutines.from_coro[coro] = active_coroutines.n
      debug.sethook(coro, debugger_hook, "rlc")
    end
    return resume_handler(coro, coresume(coro, ...))
  end
  local wrap_handler = function(status, ...)
    if not status then
      error((...))
    end
    return ...
  end
  function coroutine.wrap(f)
    local coro = coroutine.create(f)
    return function(...)
      return wrap_handler(coroutine.resume(coro, ...))
    end
  end
  return sess
end
return init
