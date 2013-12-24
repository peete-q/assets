local util = require("util")
local file = require("file")
local device = require("device")
local date = require("date")
local URLCache = require("URLCache")
local timerutil = require("timerutil")
local http = require("http")
local url = require("url")
local http = require("http")
local json = require("json")
local PersistentTable = require("PersistentTable")
local FB_APP_KEY, FB_SECRET
FB_APP_KEY = "226333800803074"
FB_SECRET = "1f41b75e5f5a1ac11e3480c1cea4aaba"
--do break end
FB_APP_KEY = "257165310981688"
FB_SECRET = "78b5c1380c162e69e265f3dade058b59"
local _debug, _warn, _error = require("qlog").loggers("facebook")
local _MockApp = false
if MOAIApp == nil then
  dofile("mock/MOAIApp.lua")
  _MockApp = true
end
local MOAIApp = MOAIApp
local MOAIDataBuffer = MOAIDataBuffer
local PHOTO_POLL_INTERVAL
local _M = {}
if FB == nil then
  function _M.init()
  end
  function _M.setListener(callback)
  end
  function _M.isLinked()
  end
  function _M.login()
  end
  function _M.isLoggedIn()
    return false
  end
  function _M.supported()
    return false
  end
  return _M
end
local function defaultCallback(event, data)
  _debug("Facebook Event: %s, Data: %s", util.tostr(event), util.tostr(data))
end
local fbAccessToken, loginTimer
local friendsList = {}
local user = {}
local fbCallback = defaultCallback
_M.EVENT_LOGGINGIN = "auth.loggingin"
_M.EVENT_LOGIN = "auth.login"
_M.EVENT_LOGOUT = "auth.logout"
_M.EVENT_LOGIN_FAILED = "auth.loginfail"
_M.EVENT_ACCOUNT_LINKED = "account.linked"
_M.EVENT_FRIENDSLIST_READY = "friendslist.ready"
local settings = PersistentTable.new(device.getDocumentsPath() .. "/hbsfb.lua")
local function checkErrorResponse(response, activity)
  if response == nil or response.error ~= nil then
    local err
    if response ~= nil then
      err = "Error " .. activity .. ": " .. util.tostr(response.error)
    else
      err = "Error " .. activity
    end
    _error(err)
    return true
  end
  return false
end
local function packageParams(t)
  if device.os == device.OS_ANDROID then
    local newT = {
      json = json.encode(t)
    }
    return newT
  end
  return t
end
local function decodeResponse(response)
  if device.os == device.OS_ANDROID and json and json.decode and response then
    return json.decode(response)
  end
  return response
end
function FB.api_each(basePath, eachCallback, finalCallback, searchStr)
  local function iterate(response)
    response = decodeResponse(response)
    if checkErrorResponse(response, "iterating " .. basePath) then
      return
    end
    if response.data ~= nil then
      for i, elem in ipairs(response.data) do
        eachCallback(elem)
      end
    end
    if response.paging ~= nil and response.paging.next ~= nil then
      do
        local newPath = response.paging.next
        FB.api(newPath, iterate)
      end
    elseif finalCallback ~= nil then
      finalCallback()
    end
  end
  FB.api(basePath, iterate)
end
local function cancelLoginTimer()
  if loginTimer ~= nil then
    loginTimer:stop()
    loginTimer = nil
  end
end
local function onAuthentication(response)
  _debug("FB: Logged in: " .. util.tostr(response))
  local oldId = settings.fbUserId
  fbAccessToken = response.access_token or response.accessToken
  settings.connected = true
  settings.fbUserId = response.userID
  settings:save()
  fbCallback(_M.EVENT_LOGIN, response)
  if oldId == nil then
    fbCallback(_M.EVENT_ACCOUNT_LINKED, settings.fbUserId)
  end
  _M.retrieveUserInfo()
  if device.os ~= device.OS_ANDROID then
    _M.retrieveFriendsList(function()
    end)
  end
end
local function update()
  if not _M.isLinked() or device.os == device.OS_ANDROID then
    return
  end
  _debug("Facebook: Updating")
  FB.getLoginStatus(function(response)
    response = decodeResponse(response)
    _debug("Facebook: Login Status: " .. util.tostr(response))
    if response.authResponse then
      onAuthentication(response.authResponse)
    else
      if response.error ~= nil and response.error.type == "OAuthException" then
        settings.fbUserId = nil
        settings:save()
        fbCallback(_M.EVENT_LOGOUT, response)
      end
      if settings.fbUserId ~= nil then
        _M.login()
      end
    end
  end)
end
function _M.setListener(callback)
  if type(callback) == "function" then
    fbCallback = callback
  else
    fbCallback = defaultCallback
  end
end
function _M.isFetchingPhotos()
  return purgeSet ~= nil
end
function _M.init(callback)
  FB.init(FB_APP_KEY)
  update()
end
function _M.supported()
  return true
end
function _M.isLinked()
  return settings.fbUserId ~= nil
end
function _M.isLoggedIn()
  return fbAccessToken ~= nil
end
function _M.login()
  if fbAccessToken ~= nil then
    return
  end
  if loginTimer ~= nil then
    MOAIApp.showDialog("Login in progress", "You are are currently logging into Facebook. Please be patient.", nil, "Dismiss")
    return
  end
  local delayTime = 30
  if device.os == device.OS_ANDROID then
    delayTime = 360
  end
  loginTimer = timerutil.delaycall(delayTime, function()
    _M.unlink()
    MOAIApp.showDialog(_("Login Failed."), _("Strikefleet Omega could not establish a connection to Facebook."), nil, _("Dismiss"))
    fbCallback(_M.EVENT_LOGIN_FAILED, false)
  end)
  fbCallback(_M.EVENT_LOGGINGIN, true)
  FB.login(function(response)
    response = decodeResponse(response)
    cancelLoginTimer()
    fbCallback(_M.EVENT_LOGGINGIN, false)
    if not checkErrorResponse(response, "logging in") then
      if response.authResponse ~= nil then
        _debug("Hurray!")
        onAuthentication(response.authResponse)
      end
    elseif response.error.type == "OAuthException" then
      _unlink(response)
    end
  end, {
    scope = "read_friendlists,user_photos,user_about_me"
  })
end
local function _unlink(response)
  response = decodeResponse(response)
  _debug("FB Login Response (unlinking): %s", util.tostr(response))
  if settings.fbUserId ~= nil then
    settings.fbUserId = nil
    settings:save()
  end
  if fbAccessToken ~= nil then
    fbAccessToken = nil
    fbCallback(_M.EVENT_LOGOUT, response)
  end
  cancelLoginTimer()
end
function _M.unlink()
  _unlink(nil)
end
function _M.getFullName()
  return user.name
end
function _M.getID()
  return user.id
end
function _M.getFriendsList()
  return friendsList
end
function _M.retrieveFriendsList(callback)
  if not _M.isLinked() then
    callback(nil, "not linked to FB")
    return
  end
  if fbAccessToken == nil then
    callback(nil, "not logged in")
    return
  end
  _debug("Attempting to retrieve friends list")
  friendsList = {}
  local path = "/me/friends?fields=installed,username,name,first_name,middle_name,last_name"
  if device.os == device.OS_ANDROID then
    path = string.format("/me/friends?access_token=%s&fields=installed,username,name,first_name,middle_name,last_name", fbAccessToken)
  end
  FB.api_each(path, function(friend)
    if friend and friend.installed then
      _debug("Adding friend: ", friend)
      friendsList[#friendsList + 1] = friend
    end
  end, function()
    _debug("Completed Fetching Friends List")
    fbCallback(_M.EVENT_FRIENDSLIST_READY, friendsList)
  end)
end
function _M.retrieveUserInfo()
  if not _M.isLinked() then
    return
  end
  if fbAccessToken == nil then
    return
  end
  user = {}
  _debug("Attempting to fetch user")
  FB.api("/me", function(response)
    response = decodeResponse(response)
    if checkErrorResponse(response, "iterating /me") then
      return
    end
    user = response
    if device.os == device.OS_ANDROID then
      _M.retrieveFriendsList(function()
      end)
    end
  end)
end
return _M
