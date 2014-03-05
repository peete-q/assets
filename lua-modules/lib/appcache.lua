local http = require("http")
local device = require("device")
local util = require("util")
local jws = require("net.jws")
local file = require("file")
local timerutil = require("timerutil")
local versionutil = require("versionutil")
local table_insert = table.insert
local table_remove = table.remove
local _debug, _warn, _error = require("qlog").loggers("appcache")
local _fileExists = MOAIFileSystem.checkFileExists
local _dirExists = MOAIFileSystem.checkPathExists
local _groupPath = function(self, groupName, f, which)
  return string.format("%s/%s/%s/%s", self._path, groupName, which, f)
end
local function _cachePath(path, createIfNeeded)
  return device.getCachePath(path, createIfNeeded)
end
local function _save(self)
  local f, err = io.open(self._path .. "/appcache.lua", "wb")
  if not f then
    error("error saving appcache: " .. err)
  end
  f:write("return {\n")
  for k, v in pairs(self) do
    if not k:match("^_") then
      local vt = type(v)
      if vt == "string" then
        f:write(string.format("[%q]=%q,\n", k, v))
      elseif vt ~= "function" and vt ~= "userdata" then
        f:write(string.format("[%q]=%s,\n", k, util.tostr(v)))
      end
    end
  end
  f:write("}")
  f:close()
end
local function _fireEvent(self, eventName, ...)
  if _debug then
    _debug("EVENT: " .. tostring(eventName), ...)
  end
  local fn = self[eventName]
  if fn ~= nil then
    local success, result = pcall(fn, self, ...)
    if success then
      return result
    else
      _error("Event Handler encountered error: " .. debug.getfuncinfo(fn) .. ": " .. tostring(result))
    end
  end
end
local function _httpGetWithRetry(task, url, headers, retryCount)
  if retryCount == nil then
    retryCount = 4
  end
  retryCount = retryCount + 1
  local retryDelay = 0
  local realHttpGet = task.httpGet
  function task.retry(task)
    if retryCount > 1 then
      retryCount = retryCount - 1
    else
      task.retry = nil
    end
    if retryDelay > 0 then
      _debug("Retrying (in " .. retryDelay .. " sec) HTTP GET " .. url, task._cache)
      timerutil.delaycall(retryDelay, realHttpGet, task, url, device.userAgent, false, false, headers)
    else
      realHttpGet(task, url, device.userAgent, false, false, headers)
    end
    retryDelay = retryDelay + 1
    retryDelay = retryDelay * 2
    if retryDelay > 60 then
      retryDelay = 60
    end
  end
  task:retry()
end
local _M = {}
_M.__index = _M
local ON_UPDATE_READY = "onUpdateReady"
local ON_NO_UPDATE = "onNoUpdate"
local ON_DOWNLOADING = "onDownloading"
local ON_PROGRESS = "onProgress"
local ON_OBSOLETE = "onObsolete"
local ON_ERROR = "onError"
local ON_CHECKING = "onChecking"
local ON_ABORTED = "onAborted"
local ON_GROUP_READY = "onGroupReady"
local ON_SWAP_COMPLETE = "onSwapComplete"
local ON_SWAP_STARTED = "onSwapStarted"
local ON_IDLE = "onIdle"
_M.STATUS_UNCACHED = "UNCACHED"
_M.STATUS_IDLE = "IDLE"
_M.STATUS_CHECKING = "CHECKING"
_M.STATUS_DOWNLOADING = "DOWNLOADING"
_M.STATUS_UPDATEREADY = "UPDATEREADY"
_M.STATUS_SWAPPING = "SWAPPING"
_M.STATUS_OBSOLETE = "OBSOLETE"
local GSTATUS_PENDING = "pending"
local GSTATUS_EMBEDDED = "embedded"
local GSTATUS_READY = "ready"
local GSTATUS_UPDATE = "update"
local MANIFEST_TYP_LUA = "application/x-acu-manifest-lua"
function _M.new(manifestURL, keyStore, basePath)
  if type(manifestURL) ~= "string" then
    error("Invalid URL: " .. tostring(manifestURL))
  end
  if basePath == nil then
    basePath = "appcache"
  end
  local path = _cachePath(basePath)
  local self
  local success, result = pcall(dofile, path .. "/appcache.lua")
  if success and type(result) == "table" and result.manifestURL == manifestURL then
    self = result
    self._status = _M.STATUS_IDLE
  else
    self = {}
    self.manifestURL = manifestURL
    self.splitGroup = nil
    self.groups = {}
    self.lastUpdateCheck = nil
    self.lastUpdate = nil
    self._status = _M.STATUS_UNCACHED
  end
  self._path = path
  self._keystore = keyStore
  self._queue = {}
  self._retain = {}
  self._groupStatus = {}
  self._groupCPath = {}
  self._baseURL = file.pathinfo(self.manifestURL, "dirname")
  setmetatable(self, _M)
  return self
end
local function _file_sig(path, calg, key)
  if calg == "none" then
    return file.exists(path)
  end
  if not _fileExists(path) then
    return nil
  end
  if _debug then
    _debug("\t\tgenerating signature for " .. path)
  end
  local data, err = file.read(path)
  if not data then
    error(err)
  end
  local hmac = crypto.hmac.new(calg, key)
  hmac:update(data)
  return hmac:digest()
end
local function _createFileGroupList(basePath, alg, keyStore, kid)
  local key = jws._selectKey(keyStore, kid)
  if key == nil then
    error("Invalid or unrecognized key")
  end
  local calg = jws.ALG_TO_CRYPTO_ALG[alg]
  local groups = {}
  for d in file.directories(basePath, 2) do
    local groupName = d:sub(basePath:len() + 2)
    local group
    if _debug then
      _debug(groupName)
    end
    for f in file.files(d, true) do
      if group == nil then
        group = {
          kid = kid,
          alg = alg,
          files = {}
        }
        groups[groupName] = group
      end
      local relativePath = f:sub(d:len() + 2)
      if _debug then
        _debug("", relativePath)
      end
      group.files[relativePath] = _file_sig(f, calg, key)
    end
  end
  return groups
end
function _M.createSignedManifest(basePath, alg, keyStore, kid)
  local table_insert = table.insert
  local header = {
    kid = kid,
    alg = alg,
    typ = MANIFEST_TYP_LUA,
    iat = os.time(os.date("!*t"))
  }
  local manifest = {
    groups = _createFileGroupList(basePath, alg, keyStore, kid)
  }
  return jws.encode(header, util.tostr(manifest), keyStore, kid)
end
function _M.createSignedSplitTestManifest(basePath, weights, alg, keyStore, kid)
  local table_insert = table.insert
  local header = {
    kid = kid,
    alg = alg,
    typ = MANIFEST_TYP_LUA,
    iat = os.time(os.date("!*t"))
  }
  local manifest = {
    splitWeights = weights,
    splitGroups = {}
  }
  local totalW = 0
  for k, v in pairs(weights) do
    totalW = totalW + v
    manifest.splitGroups[k] = _createFileGroupList(basePath .. "/" .. k, alg, keyStore, kid)
  end
  for k, v in pairs(weights) do
    manifest.splitWeights[k] = v / totalW
  end
  return jws.encode(header, util.tostr(manifest), keyStore, kid)
end
local function _appcache_group_verify(self, groupName)
  local group = self.groups[groupName]
  local calg = jws.ALG_TO_CRYPTO_ALG[group.alg]
  local key = jws._selectKey(self._keystore, group.kid)
  local isvalid = true
  if key ~= nil or calg == "none" then
    local needsUpdate = false
    local validfiles = {}
    local Q = self._queue
    for f, sig in pairs(group.files) do
      if _debug then
        _debug("\tverifying: " .. f)
      end
      local fpath
      if self._groupCPath[groupName] then
        fpath = self._groupCPath[groupName] .. f
      else
        fpath = _groupPath(self, groupName, f, "current/files")
      end
      local valid = false
      if type(sig) == "string" then
        do
          local lsig = _file_sig(fpath, calg, key)
          valid = sig == lsig
          if _debug then
            if not valid then
              isvalid = false
              _debug("\t\tsig: FAIL: Manifest:" .. tostring(sig) .. " ?= Local:" .. tostring(lsig))
            else
              _debug("\t\tsig: true")
            end
          end
        end
      else
        valid = file.exists(fpath)
        if _debug then
          _debug("\t\tfile exists: " .. tostring(valid))
        end
        if not valid then
          isvalid = false
        end
      end
      if not valid then
        if _debug then
          _debug("\tqueuing " .. f)
        end
        needsUpdate = true
        table_insert(Q, groupName)
        table_insert(Q, f)
        table_insert(Q, false)
        file.remove(_groupPath(self, groupName, f, "current/etags"))
      else
        table_insert(validfiles, f)
      end
    end
    if needsUpdate then
      for i = 1, #validfiles do
        table_insert(Q, groupName)
        table_insert(Q, validfiles[i])
        table_insert(Q, true)
      end
      self._groupStatus[groupName] = GSTATUS_UPDATE
    else
      local s = self._groupStatus[groupName]
      if s == nil or s == GSTATUS_EMBEDDED then
        self._groupStatus[groupName] = GSTATUS_PENDING
      end
    end
  end
  return isvalid
end
local function _reuse_group_file(self, groupName, f)
  local cpath = self._groupCPath[groupName]
  if cpath ~= nil then
    cpath = cpath .. f
  else
    cpath = _groupPath(self, groupName, f, "current/files")
  end
  if _debug then
    _debug("\treusing file: " .. cpath)
  end
  file.copy(cpath, _groupPath(self, groupName, f, "tmp/files"), true)
  file.copy(_groupPath(self, groupName, f, "current/etags"), _groupPath(self, groupName, f, "tmp/etags"), true)
end
local _appcache_GET_file_cb
local function _appcache_GET_next_file(self)
  if not self:busy() then
    return
  end
  local Q = self._queue
  local quota = 30
  while #Q >= 3 and Q[3] == true do
    if quota <= 0 then
      timerutil.delaycall(0.001, _appcache_GET_next_file, self)
      return
    end
    quota = quota - 1
    local groupName = table_remove(Q, 1)
    local f = table_remove(Q, 1)
    local valid = table_remove(Q, 1)
    assert(valid, "invalid file somehow managed to sneak through")
    _reuse_group_file(self, groupName, f)
  end
  if #Q < 3 then
    assert(#Q == 0, "partial queue results found")
    local updateReady = false
    for k, gstatus in pairs(self._groupStatus) do
      if gstatus ~= GSTATUS_READY then
        updateReady = true
        break
      end
    end
    if updateReady then
      self._status = _M.STATUS_UPDATEREADY
      _fireEvent(self, ON_UPDATE_READY)
    else
      self._status = _M.STATUS_IDLE
      _fireEvent(self, ON_NO_UPDATE)
    end
    return
  end
  local groupName = table_remove(Q, 1)
  local f = table_remove(Q, 1)
  local valid = table_remove(Q, 1)
  assert(not valid, "valid file somehow managed to sneak through")
  if self._status ~= _M.STATUS_DOWNLOADING then
    self._status = _M.STATUS_DOWNLOADING
    _fireEvent(self, ON_DOWNLOADING)
  end
  local task = MOAIHttpTask.new()
  task:setCallback(_appcache_GET_file_cb)
  task._cache = self
  task._groupName = groupName
  task._f = f
  local headers, etag
  if _fileExists(_groupPath(self, groupName, f, "current/files")) then
    etag = file.read(_groupPath(self, groupName, f, "current/etags"))
    if etag ~= nil then
      headers = {
        "If-None-Match: " .. etag
      }
    end
  end
  local url
  if self.splitGroup == nil then
    url = self._baseURL .. "/" .. groupName .. "/" .. f
  else
    url = self._baseURL .. "/" .. self.splitGroup .. "/" .. groupName .. "/" .. f
  end
  task._url = url
  _httpGetWithRetry(task, url, headers)
end
function _appcache_GET_file_cb(task)
  local responseCode = task:getResponseCode()
  local responseText = task:getString()
  local self = task._cache
  local groupName = task._groupName
  local f = task._f
  _fireEvent(self, ON_PROGRESS, groupName, f)
  if responseCode == 200 then
    file.write(_groupPath(self, groupName, f, "tmp/files"), responseText, true)
    do
      local etag = task:getResponseHeader("Etag")
      if etag ~= nil then
        file.write(_groupPath(self, groupName, f, "tmp/etags"), etag, true)
      end
      if _debug then
        _debug("\tfetched file [" .. tostring(etag) .. "]: " .. groupName .. "/" .. f)
      end
    end
  elseif responseCode == 304 then
    _reuse_group_file(self, groupName, f)
  elseif task.retry ~= nil then
    task:retry()
  else
    _error("Error fetching " .. f .. " <" .. task._url .. ">: " .. responseCode .. " " .. tostring(responseText))
  end
  _appcache_GET_next_file(self)
end
local function _appcache_run(self)
  for k, v in pairs(self._retain) do
    if self.groups[k] == nil then
      _warn("Retained group not found in manifest: " .. k)
    end
  end
  for name, group in pairs(self.groups) do
    if not self:busy() then
      return
    end
    if self._retain[name] then
      if _debug then
        _debug("retaining: " .. name)
      end
      _appcache_group_verify(self, name)
      if _debug then
        _debug("status: " .. self._groupStatus[name])
      end
      coroutine.yield()
    end
  end
  _appcache_GET_next_file(self)
end
function _M:status()
  return self._status
end
function _M:purge(deleteAll)
  _debug("PURGING " .. self._path)
  if deleteAll then
    file.remove(self._path, true)
  else
    file.remove(self._path .. "/appcache.lua")
  end
  self.groups = {}
  self.splitGroup = nil
  if self._status ~= _M.STATUS_OBSOLETE then
    self._status = _M.STATUS_UNCACHED
  end
end
function _M:busy()
  local status = self._status
  return status == _M.STATUS_CHECKING or status == _M.STATUS_DOWNLOADING or status == _M.STATUS_SWAPPING
end
function _M:queueSize()
  return #self._queue / 3
end
function _M:lastUpdateTag()
  if self.lastUpdate == nil then
    return "nil-" .. tostring(self.splitGroup)
  else
    return os.date("!%Y%m%d_%H%M%S", self.lastUpdate) .. "-" .. tostring(self.splitGroup)
  end
end
local function _appcache_GET_manifest(task)
  local responseCode = task:getResponseCode()
  local responseText = task:getString()
  local self = task._cache
  if _debug then
    _debug("HTTP Response for manifest fetch", responseCode)
  end
  if responseCode == 404 or responseCode == 410 then
    self._status = _M.STATUS_OBSOLETE
    _fireEvent(self, ON_OBSOLETE)
    self:purge()
    _fireEvent(self, ON_IDLE)
  elseif responseCode == 200 then
    do
      local body, header = jws.decode(responseText, self._keystore)
      if body == nil then
        self._status = _M.STATUS_UNCACHED
        _fireEvent(self, ON_ERROR, "manifest decode error: " .. tostring(header))
        _fireEvent(self, ON_IDLE)
        return
      end
      local manifest
      if header.typ == MANIFEST_TYP_LUA then
        manifest = assert(loadstring("return " .. body))()
      else
        self._status = _M.STATUS_UNCACHED
        _fireEvent(self, ON_ERROR, "manifest has unrecognized type: " .. tostring(header.typ))
        _fireEvent(self, ON_IDLE)
        return
      end
      if type(manifest) ~= "table" then
        self._status = _M.STATUS_UNCACHED
        _fireEvent(self, ON_ERROR, "manifest is invalid: " .. tostring(manifest))
        _fireEvent(self, ON_IDLE)
        return
      end
      local groups, split
      if manifest.splitGroups ~= nil then
        do
          local weightVals, weightKeys
          local weights = manifest.splitWeights
          if weights == nil then
            weightVals = {}
            weightKeys = {}
            do
              local n = 0
              for k, v in pairs(manifest.splitGroups) do
                n = n + 1
              end
              for k, v in pairs(manifest.splitGroups) do
                table_insert(weightKeys, k)
                table_insert(weightVals, 1 / n)
              end
            end
          else
            weightVals = {}
            weightKeys = {}
            for k, v in pairs(weights) do
              table_insert(weightKeys, k)
              table_insert(weightVals, v)
            end
          end
          local roll
          if task._roll == nil then
            roll = math.random()
          else
            roll = task._roll
          end
          local roll0 = roll
          local n = #weightKeys
          split = weightKeys[n]
          for i = 1, n - 1 do
            local w = weightVals[i]
            if roll <= w then
              split = weightKeys[i]
              break
            end
            roll = roll - w
          end
          _debug("Split Groups: [" .. table.concat(weightKeys, ",") .. "] -> [" .. table.concat(weightVals, ",") .. "] ==> (" .. roll0 .. " -> " .. tostring(split) .. ")")
          groups = manifest.splitGroups[split]
        end
      else
        groups = manifest.groups
      end
      self.groups = groups
      self.splitGroup = split
      self.etag = task:getResponseHeader("Etag")
      if _debug then
        _debug("Manifest ETag: ", self.etag)
      end
      self.lastUpdate = header.iat or os.time(os.date("!*t"))
      _save(self)
      local thread = MOAIThread.new()
      thread:run(function()
        _appcache_run(self)
      end)
    end
  elseif responseCode == 304 then
    _save(self)
    do
      local thread = MOAIThread.new()
      thread:run(function()
        _appcache_run(self)
      end)
    end
  elseif responseCode == 0 and task.retry ~= nil then
    task:retry()
  else
    if self.lastUpdate ~= nil then
      self._status = _M.STATUS_IDLE
    else
      self._status = _M.STATUS_UNCACHED
    end
    _fireEvent(self, ON_ERROR, "error fetching manifest: " .. tostring(responseCode) .. " " .. tostring(responseText))
    _fireEvent(self, ON_IDLE)
  end
end
function _M:update(roll)
  if self:busy() then
    return
  end
  self._status = _M.STATUS_CHECKING
  self.lastUpdateCheck = os.time()
  _fireEvent(self, ON_CHECKING)
  local task = MOAIHttpTask.new()
  task:setCallback(_appcache_GET_manifest)
  task._cache = self
  task._roll = roll
  local headers
  if self.etag ~= nil then
    headers = {
      "If-None-Match: " .. self.etag
    }
  end
  _httpGetWithRetry(task, self.manifestURL, headers)
end
function _M:abort()
  if self:busy() then
    self._status = _M.STATUS_IDLE
    _fireEvent(self, ON_ABORTED)
    _fireEvent(self, ON_IDLE)
  end
end
function _M:retain(group, value)
  local shouldUpdate = false
  if type(group) == "table" then
    for k, v in pairs(group) do
      if v and self:retain(k, true) then
        shouldUpdate = true
      end
    end
    return shouldUpdate
  end
  local old = self._retain[group]
  if value == nil or value then
    self._retain[group] = true
    if not old then
      shouldUpdate = true
    end
  else
    self._retain[group] = nil
  end
  return shouldUpdate
end
local function _appcache_swap(self)
  _debug("ARE VE SWAPPING?")
  for groupName, gstatus in pairs(self._groupStatus) do
    if not self:busy() then
      return
    end
    local cpath = string.format("%s/%s/current", self._path, groupName)
    if gstatus == GSTATUS_PENDING then
      self._groupStatus[groupName] = GSTATUS_READY
      self._groupCPath[groupName] = nil
      _fireEvent(self, ON_GROUP_READY, groupName, cpath .. "/files/", self.groups[groupName].files)
    elseif gstatus == GSTATUS_UPDATE then
      do
        local tpath = string.format("%s/%s/tmp", self._path, groupName)
        local opath = string.format("%s/%s/old", self._path, groupName)
        if _debug then
          _debug("\trenaming " .. tpath .. " -> " .. cpath)
        end
        file.remove(opath, true)
        if not file.exists(cpath) or file.rename(cpath, opath) then
          do
            local success, err = file.rename(tpath, cpath)
            if success then
              self._groupStatus[groupName] = GSTATUS_READY
              self._groupCPath[groupName] = nil
              _fireEvent(self, ON_GROUP_READY, groupName, cpath .. "/files/", self.groups[groupName].files)
            else
              _error("APPCACHE: error: cannot rename tmp -> current: " .. tpath .. ": " .. tostring(err))
              file.rename(opath, cpath)
            end
          end
        else
          local success, result = file.rename(cpath, opath)
          _error("APPCACHE: error: cannot rename current -> old: " .. cpath .. ": " .. result)
        end
      end
    else
      _error("APPCACHE: error: invalid gstatus for " .. groupName .. ": " .. tostring(gstatus))
    end
    coroutine.yield()
  end
  self._status = _M.STATUS_IDLE
  if _debug then
    _debug("idle")
  end
  _fireEvent(self, ON_SWAP_COMPLETE)
  _fireEvent(self, ON_IDLE)
end
function _M:swap()
  if self._status ~= _M.STATUS_UPDATEREADY then
    return false
  end
  self._status = _M.STATUS_SWAPPING
  _fireEvent(self, ON_SWAP_STARTED)
  if _debug then
    _debug("\tswapping cached files")
  end
  local thread = MOAIThread.new()
  thread:run(function()
    _appcache_swap(self)
  end)
  return true
end
function _M:ready(embeddedPath)
  if self._status ~= _M.STATUS_UNCACHED then
    if self._status ~= _M.STATUS_IDLE then
      error("Cannot embed while busy")
    end
    local valid = true
    for groupName, files in pairs(self.groups) do
      if not _appcache_group_verify(self, groupName) then
        valid = false
      end
    end
    if valid then
      _debug("Skipping embed request because cache is already initialized.")
      embeddedPath = nil
    end
  end
  if embeddedPath ~= nil then
    do
      local body, header = jws.decode(file.read(embeddedPath .. "/manifest.jws"), self._keystore)
      if body ~= nil and header.typ == MANIFEST_TYP_LUA then
        _debug("Found embedded manifest: " .. embeddedPath .. "/manifest.jws")
        local manifest = loadstring("return " .. body)()
        if type(manifest) == "table" then
          self._embeddedPath = embeddedPath
          self.groups = manifest.groups
          for groupName, files in pairs(self.groups) do
            local cpath = embeddedPath .. "/" .. groupName .. "/"
            if file.exists(cpath) then
              _debug("Retaining embedded group: " .. groupName)
              for jon, jones in pairs(files) do
                print(jon, jones)
              end
              self._groupStatus[groupName] = GSTATUS_EMBEDDED
              self._groupCPath[groupName] = cpath
              self._retain[groupName] = true
              _fireEvent(self, ON_GROUP_READY, groupName, cpath, self.groups[groupName].files)
            else
              _debug("Group is not embedded: " .. groupName)
            end
          end
        end
      end
    end
  else
    for groupName, files in pairs(self.groups) do
      local cpath = string.format("%s/%s/current", self._path, groupName)
      self._groupStatus[groupName] = GSTATUS_READY
      self._groupCPath[groupName] = nil
      self._retain[groupName] = true
      _fireEvent(self, ON_GROUP_READY, groupName, cpath .. "/files/", self.groups[groupName].files)
    end
  end
end
return _M
