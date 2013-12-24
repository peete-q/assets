local _M = {}
local GameCenter = GameCenter
local _debug, _warn, _error = require("qlog").loggers("gamecenter")
if GameCenter == nil then
  GameCenter = {
    login = function()
      _debug("GameCenter login")
    end,
    setLoginCallback = function()
    end,
    submitAchievement = function(id, progress)
      _debug("GameCenter achievement progress: " .. id .. " = " .. tostring(progress))
    end,
    getFriendsList = function()
      return {}
    end,
    isLoggedIn = function()
      return false
    end
  }
end
local _friendsList = {}
local _loggingIn = false
local _loginFailedCallback, friendsListCallback
local function friendsListReady(friends)
  _friendsList = friends
  if friendsListCallback then
    friendsListCallback(friend)
  end
end
local function loginCallback()
  MOAIGameCenter.setGetFriendsListCallback(friendsListReady)
  MOAIGameCenter.getFriendsList()
end
local function loginFailedCallback()
  if _loginFailedCallback then
    _loginFailedCallback()
  end
end
local _haveShownGCLogin = false
function _M.autologin()
  if not _haveShownGCLogin and not _loggingIn then
    _haveShownGCLogin = true
    _loggingIn = true
    GameCenter.setLoginCallback(loginCallback)
    GameCenter.setLoginFailedCallback(loginFailedCallback)
    GameCenter.login()
  end
end
function _M.login()
  if GameCenter.isLoggedIn() or _loggingIn then
    return
  end
  GameCenter.setLoginCallback(loginCallback)
  GameCenter.setLoginFailedCallback(loginFailedCallback)
  GameCenter.login()
end
function _M.update(achievementId, percentComplete)
  GameCenter.submitAchievement(achievementId, percentComplete)
end
function _M.isLoggedIn()
  return GameCenter.isLoggedIn()
end
function _M.openGC()
  MOAIApp.openURL("gamecenter:/me/account")
end
function _M.getFriendsList()
  return _friendsList
end
function _M.getUserInfo(userList, callback)
  if not GameCenter.isLoggedIn() then
    return
  end
  _debug("Attempting to fetch user data", userList, callback)
  MOAIGameCenter.setGetUserInfoCallback(callback)
  MOAIGameCenter.getUserInfo(userList)
end
function _M.clearGetUserInfoCallback()
  MOAIGameCenter.setGetUserInfoCallback(nil)
end
function _M.getAlias()
  return MOAIGameCenter.getPlayerAlias()
end
function _M.getID()
  return MOAIGameCenter.getPlayerID()
end
function _M.setFriendsListCallback(callback)
  friendsListCallback = callback
end
function _M.reportScore(score, board)
  if not GameCenter.isLoggedIn() then
    return
  end
  MOAIGameCenter.reportScore(score, board)
end
function _M.setLoginFailedCallback(func)
  _loginFailedCallback = func
end
function _M.onLoginFailedDismissed()
  _loggingIn = false
end
return _M
