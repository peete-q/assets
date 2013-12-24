local table_remove = table.remove
local table_insert = table.insert
local timerutil = require("timerutil")
local url = require("url")
local device = require("device")
local util = require("util")
local json = require("json")
local util = require("util")
local _json_encode = json.encode
local _json_decode = json.decode
local _debug, _warn, _error = require("qlog").loggers("moai.cloud")
local _M = {}
_M.__index = _M
function _M.new(clientKey, clientSecret, baseURL)
  local self = {
    clientKey = clientKey,
    clientSecret = clientSecret,
    baseURL = baseURL or "http://services.moaicloud.com"
  }
  setmetatable(self, _M)
  return self
end
local function _httpGet(task, url, headers)
  _debug("GET " .. url)
  task:httpGet(url, device.userAgent, false, false, headers)
end
local function _httpPost(task, url, headers, body)
  _debug("POST " .. url)
  task:httpPost(url, body, device.userAgent, false, false, headers)
end
local function _httpGetWithRetry(task, url, headers, retryCount)
  if retryCount == nil then
    retryCount = 4
  end
  retryCount = retryCount + 1
  local retryDelay = 0
  function task.retry(task)
    if retryCount > 1 then
      retryCount = retryCount - 1
    else
      task.retry = nil
    end
    if retryDelay > 0 then
      print("Retrying (in " .. retryDelay .. " sec) HTTP GET " .. url, task._cache)
      timerutil.delaycall(retryDelay, _httpGet, task, url, headers)
    else
      _httpGet(task, url, headers)
    end
    retryDelay = retryDelay + 1
    retryDelay = retryDelay * 2
    if retryDelay > 60 then
      retryDelay = 60
    end
  end
  task:retry()
end
local function _httpPostWithRetry(task, url, headers, body, retryCount)
  if retryCount == nil then
    retryCount = 4
  end
  retryCount = retryCount + 1
  local retryDelay = 0
  function task.retry(task)
    if retryCount > 1 then
      retryCount = retryCount - 1
    else
      task.retry = nil
    end
    if retryDelay > 0 then
      _debug("Retrying (in " .. retryDelay .. " sec) HTTP POST " .. url, task._cache)
      timerutil.delaycall(retryDelay, _httpPost, task, url, headers, body)
    else
      _httpPost(task, url, headers, body)
    end
    retryDelay = retryDelay + 1
    retryDelay = retryDelay * 2
    if retryDelay > 60 then
      retryDelay = 60
    end
  end
  task:retry()
end
local function _api_response_handler(task)
  local responseCode = task:getResponseCode()
  local responseText = task:getString()
  local self = task._self
  local callback = task._callback
  _debug("Response: " .. tostring(responseCode) .. ": " .. tostring(responseText))
  if responseCode >= 200 and responseCode < 300 then
    do
      local result = _json_decode(responseText)
      if result == nil and responseText ~= nil and responseText ~= "" and responseText ~= "null" then
        _warn("JSON parser didn't decode this: " .. tostring(responseText))
      end
      if callback then
        callback(result, responseCode, task._type)
      end
    end
  elseif responseCode ~= 0 then
    if responseText == nil or responseText == "" then
      responseText = "Server returned " .. tostring(responseCode)
    end
    if callback then
      callback({error = responseText, responseCode = responseCode}, responseCode)
    end
  elseif responseCode == 0 then
    if task.retry ~= nil then
      task:retry()
    else
      _error("Request failed (after retrying): " .. task._url)
      if callback then
        callback({
          error = "Request failed (unknown error)",
          responseCode = 0
        }, 0)
      end
    end
  end
end
function _M:api(apiPath, ...)
  local method = "GET"
  local params = ""
  local callback, requestType
  local i = 1
  local a = select(i, ...)
  if type(a) == "string" then
    method = a:upper()
    i = i + 1
    a = select(i, ...)
  end
  if type(a) == "table" or type(a) == "string" then
    if type(a) == "table" then
      params = url.format_post_vars(a)
    else
      params = a
    end
    i = i + 1
    a = select(i, ...)
  end
  if a ~= nil and type(a) ~= "function" then
    error("invalid callback: " .. tostring(a))
  end
  callback = a
  assert(type(callback) == "function", "Invalid or missing callback function")
  i = i + 1
  a = select(i, ...)
  if type(a) == "string" then
    requestType = a
  end
  local task = MOAIHttpTask.new()
  task:setCallback(_api_response_handler)
  task._self = self
  task._callback = callback
  task._type = requestType
  local u = self.baseURL .. apiPath
  self.requestId = (self.requestId or 0) + 1
  local headers = {
    "x-client-request-id: " .. tostring(self) .. "-" .. self.requestId
  }
  if self.clientKey ~= nil then
    table_insert(headers, "x-clientkey: " .. self.clientKey)
  end
  _debug(method .. " " .. u)
  if self.clientSecret ~= nil then
    local args
    if method == "GET" then
      args = params
    end
    local str = method .. "&" .. url.encode(u:lower()) .. "&" .. url.encode(args or "")
    local h = crypto.hmac.new("SHA256", self.clientSecret)
    local sig = MOAIDataBuffer.base64Encode(h:digest(str, true))
    table_insert(headers, "x-signature: " .. sig)
  end
  if method == "POST" then
    task._url = u
    _httpPostWithRetry(task, u, headers, params)
  else
    if params ~= "" then
      u = u .. "?" .. params
    end
    task._url = u
    _httpGetWithRetry(task, u, headers)
  end
end
return _M
