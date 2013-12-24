local url = require("url")
local util = require("util")
local MOAIHttpTask = MOAIHttpTask
local type = type
local format_post_vars = url.format_post_vars
local tostring = tostring
local _M = {}
local _Handler = function(task)
  local response = task:getString()
  local callback = task.userCallback
  task.userCallback = nil
  if callback ~= nil then
    if task.getResponseCode == nil then
      if response == nil or response == "" then
        callback(nil, "unknown network error", task)
      else
        callback(200, response, task)
      end
    else
      callback(task:getResponseCode(), response, task)
    end
  end
end
function _M.get(url, callback, headers)
  local task = MOAIHttpTask.new()
  task:setCallback(_Handler)
  task.userCallback = callback
  task:httpGet(url, headers)
end
function _M.post(url, body, callback, headers)
  if type(body) == "table" then
    body = format_post_vars(body)
  end
  local task = MOAIHttpTask.new()
  task:setCallback(_Handler)
  task.userCallback = callback
  task:httpPost(url, body, headers)
end
return _M
