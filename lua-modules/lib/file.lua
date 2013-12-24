local util = require("util")
local io = io
local string = string
local assert = assert
local error = error
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local dofile = dofile
local pcall = pcall
local util = util
local os = os
local MOAIFileSystem = MOAIFileSystem
local table_insert = table.insert
local table_remove = table.remove
local table_concat = table.concat
local strsplit = util.strsplit
local _M = {}
function _M.write(file, str, affirmPath)
  if affirmPath then
    local dirname = _M.pathinfo(file, "dirname")
    _M.mkdir(dirname)
  end
  local f, err = io.open(file, "wb")
  if not f then
    return nil, string.format("Unable to open file for writing: %s: %s", file, err)
  end
  f:write(tostring(str))
  f:close()
  return true
end
function _M.append(file, str)
  local f, err = io.open(file, "ab")
  if not f then
    return nil, string.format("Unable to open file for writing: %s: %s", file, err)
  end
  f:write(tostring(str))
  f:close()
  return true
end
function _M.read(file)
  local f, err = io.open(file, "rb")
  if not f then
    return nil, string.format("Unable to open file for reading: %s: %s", file, err)
  end
  local result = f:read("*all")
  f:close()
  return result
end
function _M.lines(file)
  local f, err = io.open(file, "r")
  if not f then
    error(string.format("Unable to open file for reading: %s: %s", file, err))
  end
  return f:lines()
end
function _M.exists(file)
  file = file:gsub("/+$", "")
  return MOAIFileSystem.checkFileExists(file) or MOAIFileSystem.checkPathExists(file)
end
function _M.mkdir(path)
  if not path:match("/$") then
    path = path .. "/"
  end
  return MOAIFileSystem.affirmPath(path)
end
function _M.rename(src, dst, affirmPath)
  if affirmPath then
    local dirname = _M.pathinfo(file, "dirname")
    _M.mkdir(dirname)
  end
  return os.rename(src, dst)
end
function _M.copy(src, dst, affirmPath)
  local content, err = _M.read(src)
  if content == nil then
    return nil, err
  end
  return _M.write(dst, content, affirmPath)
end
function _M.remove(path, recurse)
  if MOAIFileSystem.checkFileExists(path) then
    return MOAIFileSystem.deleteFile(path)
  end
  if MOAIFileSystem.checkPathExists(path) then
    return MOAIFileSystem.deleteDirectory(path, recurse)
  end
  return false
end
_M.delete = _M.remove
function _M.pathinfo(path, options)
  local parts = strsplit("/", path)
  local file, dirname
  if #parts > 2 then
    file = parts[#parts]
    table_remove(parts, #parts)
    dirname = table_concat(parts, "/")
  elseif #parts == 2 then
    file = parts[2]
    if path == "/" then
      file = nil
    end
    dirname = "/"
  else
    file = parts[1]
    dirname = nil
  end
  local fname, ext
  if file ~= nil then
    fname, ext = file:match("(.+)%.([^.]*)$")
    if fname == nil then
      fname = file
      ext = nil
    end
  end
  if options == nil then
    return dirname, fname, ext
  elseif options == "dirname" then
    return dirname
  elseif options == "basename" then
    return fname
  elseif options == "filename" then
    return file
  elseif options == "extension" then
    return ext
  end
  assert(false, "invalid pathinfo option: " .. tostring(options))
  return dirname, fname, ext
end
local _list_iter = function(t)
  local i = 0
  local n = table.getn(t)
  return function()
    i = i + 1
    if i <= n then
      return t[i]
    end
  end
end
local function _files(path)
  return _list_iter(MOAIFileSystem.listFiles(path))
end
local _list_iter = function(t)
  if t == nil then
    return function()
      return nil
    end
  end
  local i = 0
  local n = table.getn(t)
  return function()
    i = i + 1
    if i <= n then
      return t[i]
    end
  end
end
local function _dirs(path)
  return _list_iter(MOAIFileSystem.listDirectories(path))
end
function _M.files(path, recurse)
  if recurse == nil or not recurse then
    return _files(path)
  end
  local fileIter
  local dirIter = _M.directories(path, recurse)
  local function iter()
    local curF
    while curF == nil do
      if fileIter == nil then
        if dirIter == nil then
          return nil
        end
        local curD = dirIter()
        if curD == nil then
          dirIter = nil
          fileIter = _files(path)
        else
          fileIter = _files(curD)
        end
      end
      curF = fileIter()
      if curF == nil then
        fileIter = nil
      end
    end
    return curF
  end
  return iter
end
function _M.directories(path, recurse)
  if recurse == nil or not recurse then
    return _dirs(path)
  end
  local i = 0
  local dirIter
  local dirq = {path}
  local depth, depthq
  if recurse ~= true then
    depthq = {1}
  end
  local function iter()
    local curD
    while curD == nil do
      if dirIter == nil then
        i = i + 1
        if i > #dirq then
          return nil
        end
        dirIter = _dirs(dirq[i])
        if depthq ~= nil then
          depth = depthq[i]
        end
      end
      curD = dirIter()
      if curD == nil then
        dirIter = nil
      end
    end
    if recurse == true or depth < recurse then
      table_insert(dirq, curD)
      if depthq ~= nil then
        table_insert(depthq, depth + 1)
      end
    end
    return curD
  end
  return iter
end
function _M.serialize(path, obj, affirmPath)
  if type(obj) == "string" then
    return _M.write(path, string.format("return %q", obj), affirmPath)
  else
    return _M.write(path, "return " .. util.tostr(obj), affirmPath)
  end
end
function _M.deserialize(path)
  local success, result = pcall(dofile, path)
  if success then
    return result
  end
  return nil, result
end
return _M
