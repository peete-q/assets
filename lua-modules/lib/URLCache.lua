require("moai.compat")
local file = require("file")
local device = require("device")
local util = require("util")
local url = require("url")
local crypto = require("crypto")
local digest = crypto.evp.digest
local device = device
local file = file
local url = url
local assert = assert
local MOAIThread = MOAIThread
local MOAIHttpTask = MOAIHttpTask
local table = table
local pairs = pairs
local getfenv = getfenv
local type = type
local setmetatable = setmetatable
local tostring = tostring
local unpack = unpack
local printfln = util.printfln
local url_parse = url.parse
module(...)
local URLCache = _M
_M.__index = URLCache
function new(cacheName)
  assert(type(cacheName) == "string" and cacheName ~= "", "cacheName must be a valid directory name")
  local o = {}
  setmetatable(o, URLCache)
  o.cacheName = cacheName
  o.cachePath = device.getDocumentsPath(cacheName)
  o.queue = {}
  return o
end
function cacheFile(self, urlstr)
  local scheme, authority, path = url_parse(urlstr)
  local ext = file.pathinfo(path, "extension")
  if ext == nil then
    ext = ""
  else
    ext = "." .. ext
  end
  return self.cachePath .. "/" .. digest("md5", urlstr) .. ext
end
function exists(self, urlstr)
  local f = self:cacheFile(urlstr)
  return file.exists(f)
end
function clear(self)
  local path = self.cachePath
  local files = file.files(self.cachePath)
  for i, f in pairs(files) do
    file.remove(f)
  end
end
function remove(self, urlstr)
  local f = self:cacheFile(urlstr)
  return file.remove(f)
end
local _PumpTasks
local function _TaskHandler(task, responseCode)
  local response = task:getString()
  local callback = task.userCallback
  local urlstr = task.urlstr
  local cache = task.cache
  local f = task.localFile
  local userData = task.userData
  task.userCallback = nil
  task.cache = nil
  task.urlstr = nil
  task.localFile = nil
  task.userData = nil
  cache.task = nil
  if callback ~= nil then
    if response == nil or response == "" then
      if responseCode ~= nil then
        callback(cache, urlstr, nil, "server returned: " .. tostring(responseCode), userData)
      else
        callback(cache, urlstr, nil, "unknown network error", userData)
      end
    else
      do
        local success, err = file.write(f, response)
        if success then
          callback(cache, urlstr, f, nil, userData)
        else
          callback(cache, urlstr, nil, err, userData)
        end
      end
    end
  end
  _PumpTasks(cache)
end
local function _DoRequest(self, urlstr, localFile, callback, force, userData)
  if not force and file.exists(localFile) then
    printfln("URLCache: returning cached result for %s", urlstr)
    callback(self, urlstr, localFile, nil, userData)
    return
  end
  local task = MOAIHttpTask.new()
  task.urlstr = urlstr
  task.cache = self
  task.localFile = localFile
  task.userCallback = callback
  task:setCallback(_TaskHandler)
  if userData then
    task.userData = userData
  end
  self.task = task
  printfln("URLCache: beginning fetch of %s", task.urlstr)
  task:httpGet(task.urlstr)
end
function _PumpTasks(self)
  if #self.queue == 0 or self.task ~= nil then
    return
  end
  local request = table.remove(self.queue, 1)
  _DoRequest(self, unpack(request))
end
function fetch(self, urlstr, callback, force, userData)
  local f = self:cacheFile(urlstr)
  if self.task == nil then
    _DoRequest(self, urlstr, f, callback, force, userData)
  else
    table.insert(self.queue, {
      urlstr,
      f,
      callback,
      force,
      userData
    })
  end
end
function getContents(self, urlstr)
  local f = self:cacheFile(urlstr)
  if file.exists(f) then
    return file.read(f)
  end
  return nil
end
