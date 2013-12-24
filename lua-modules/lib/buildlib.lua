local lfs = require("lfs")
local attributes = lfs.attributes
local DIRSEP = package.config:sub(1, 1)
local type = type
local errors = 0
local TESTING = false
local _M = {}
_M.COPY_WITH_PATH = "mkdir -p $(dirname \"$(TARGET)\") && cp \"$(INPUT)\" \"$(TARGET)\""
_M.COPY = "cp \"$(INPUT)\" \"$(TARGET)\""
_M.autocreate_output_path = true
local function isdir(path)
  return attributes(path, "mode") == "directory"
end
local function isfile(path)
  return attributes(path, "mode") == "file"
end
local function mtime(path)
  local time, err = attributes(path, "modification")
  if time then
    return time
  else
    return -1
  end
end
local function dep_is_newer(src, dest)
  local t = mtime(dest)
  return t < 0 or t < mtime(src)
end
local subst = function(str, T)
  local count
  T = T or _G
  repeat
    str, count = str:gsub("%$%(([%w,_]+)%)", function(f)
      local s = T[f]
      if not s then
        return ""
      else
        return s
      end
    end)
  until count == 0
  return str
end
local build_vars = {}
_M.vars = build_vars
function _M.exec(cmd, dont_fail, echo)
  if dont_fail == nil then
    dont_fail = true
  end
  local _cmd = subst(cmd, build_vars)
  if echo == nil or echo then
    print(_cmd)
  end
  if not TESTING then
    local res = os.execute(_cmd)
    if res ~= 0 and not dont_fail then
      if not echo then
        print(_cmd)
      end
      _M.quit("%s --> failed with code %d", _cmd, res)
    end
    return res
  end
end
local function shell_nl(cmd, ...)
  cmd = subst(cmd):format(...)
  local inf = io.popen(cmd .. " 2>&1", "r")
  if not inf then
    return ""
  end
  local res = inf:read("*a")
  inf:close()
  return res
end
function _M.shell(cmd, ...)
  return (shell_nl(cmd, ...):gsub([[

$]], ""))
end
local _shell = _M.shell
function _M.splitpath(path)
  local i = #path
  local ch = path:sub(i, i)
  while i > 0 and ch ~= "/" and ch ~= "\\" do
    i = i - 1
    ch = path:sub(i, i)
  end
  if i == 0 then
    return "", path
  else
    return path:sub(1, i - 1), path:sub(i + 1)
  end
end
local split = function(s, re)
  local i1 = 1
  local ls = {}
  while true do
    do
      local i2, i3 = s:find(re, i1)
      if not i2 then
        append(ls, s:sub(i1))
        return ls
      end
      append(ls, s:sub(i1, i2 - 1))
      i1 = i3 + 1
    end
  end
end
local function mkparentdirs(path)
  local p
  local i1 = 1
  while true do
    do
      local i2, i3 = path:find("[/\\]+", i1)
      if not i2 then
        return true
      end
      if p == nil then
        p = path:sub(i1, i2 - 1)
      else
        p = p .. DIRSEP .. path:sub(i1, i2 - 1)
      end
      if p ~= "" and not isdir(p) then
        local res, err = lfs.mkdir(p)
        if not res then
          return false, err
        end
      end
      i1 = i3 + 1
    end
  end
  return true, nil
end
local function _maybe_run_rule(relfile, rule, dep, opts)
  local extfn = rule.ext
  if extfn ~= nil then
    if type(extfn) == "function" then
      relfile = extfn(relfile)
    else
      relfile = relfile:gsub("(%..*)$", extfn)
    end
  end
  if relfile == nil then
    return false
  end
  local file = rule.odir .. DIRSEP .. relfile
  local force = opts.force
  if type(force) == "function" then
    force = force(relfile)
  elseif type(force) == "string" then
    force = relfile:find(force)
  end
  if force or dep_is_newer(dep, file) then
    build_vars.INPUT = dep
    build_vars.TARGET = file
    build_vars.RELATIVE_TARGET = relfile
    if _M.autocreate_output_path and not TESTING then
      local res, err = mkparentdirs(file)
      if not res then
        _M.error("creating directory for: %s: %s", file, err)
        return true
      end
    end
    do
      local cmd = rule[2]
      if type(cmd) == "string" then
        _M.exec(cmd, true)
      else
        cmd(dep, file, relfile)
      end
    end
  end
  return true
end
local function _should_include(e, f)
  if type(e) == "table" then
    for k, v in pairs(e) do
      if v == f then
        return false
      end
    end
    return true
  end
  if type(e) == "function" then
    return not e(f)
  end
  if type(e) == "string" then
    return not f:find(e)
  end
  return e ~= f
end
local function _find_files(path, rules, recurse, relpath, opts)
  recurse = recurse or true
  local excl = opts.exclude
  for f in lfs.dir(path) do
    if f ~= "." and f ~= ".." and f ~= ".svn" then
      local file = f
      local relfile
      if relpath == nil then
        relfile = file
      else
        relfile = relpath .. DIRSEP .. file
      end
      if excl == nil or _should_include(excl, relfile) then
        if path ~= "." then
          file = path .. DIRSEP .. file
        end
        if isdir(file) then
          if recurse then
            _find_files(file, rules, recurse, relfile, opts)
          end
        else
          for i = 1, #rules do
            local r = rules[i]
            if relfile:find(r._pat) and _maybe_run_rule(relfile, r, file, opts) then
              break
            end
          end
        end
      end
    end
  end
end
local _shellwc_to_pat = function(wc)
  return "^" .. wc:gsub("%.", "%%."):gsub("%*", ".*") .. "$"
end
function _M.run(dir, odir, rules, opts)
  opts = opts or {}
  if type(opts.exclude) == "string" then
    opts.exclude = _shellwc_to_pat(opts.exclude)
  end
  if type(opts.force) == "string" then
    opts.force = _shellwc_to_pat(opts.force)
  end
  for i, r in ipairs(rules) do
    r._pat = _shellwc_to_pat(r[1])
    r.odir = r.odir or odir
  end
  _find_files(dir, rules, true, nil, opts)
end
function _M.warning(msg, ...)
  io.stderr:write("warning: ", msg:format(...), "\n")
  io.stderr:flush()
end
function _M.error(msg, ...)
  errors = errors + 1
  io.stderr:write("error: ", msg:format(...), "\n")
  io.stderr:flush()
end
function _M.quit(msg, ...)
  _M.error(msg, ...)
  os.exit(1)
end
function _M.copy(src, dest)
  local inf, err = io.open(src, "r")
  if err then
    quit(err)
  end
  local outf, err = io.open(dest, "w")
  if err then
    quit(err)
  end
  outf:write(inf:read("*a"))
  outf:close()
  inf:close()
end
function _M.exit(code)
  if code == nil then
    if errors == 0 then
      code = 0
    else
      code = 1
    end
  end
  if code == 0 then
    io.stdout:write("BUILD SUCCESS\n")
    io.stdout:flush()
  else
    io.stdout:write("BUILD FAILED\n")
    io.stdout:flush()
  end
  os.exit(code)
end
local file = {}
function file.exists(path)
  return attributes(path, "mode") == nil
end
file.isdir = isdir
file.isfile = isfile
file.mtime = mtime
_M.file = file
return _M
