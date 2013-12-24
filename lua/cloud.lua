local moaicloud = require("moai.cloud")
local json = require("json")
local util = require("util")
local analytics = require("analytics")
local PersistentQueue = require("PersistentQueue")
local PersistentTable = require("PersistentTable")
local device = require("device")
local timerutil = require("timerutil")
local device = require("device")
local url = require("url")
local fb = require("fb")
local gamecenter = require("gamecenter")
local actionset = require("actionset")
local _debug, _warn, _error = require("qlog").loggers("cloud")
local table_insert = table.insert
local table_remove = table.remove
local ERROR_RETRY_TIME = 120
local THROTTLE_TIME = 5
local _client, _request, _busy, _Q, _config, _postingScore, _fetchingLB, _fetchingLB_FB, _fetchingLB_GC, _fetchingWLB, _fetchingWLB_FB, _fetchingWLB_GC, _fetchingWinner, _fetchingWinner_FB, _fetchingWinner_GC, _leaderboardCallback, _post_leaderboardCallback
local _M = {}
local _android_token_req, _api_response
local _androidAS = actionset.new()
local function _next_req()
  if _Q:empty() then
    _busy = false
    _debug("Status: Idle")
    return
  end
  if _busy then
    return
  end
  _debug("Status: Busy")
  _busy = true
  _request = _Q:peek()
  local args = _request.args
  if args[2] == nil then
    args[2] = "GET"
  end
  _debug("Cloud request: " .. args[2] .. " " .. args[1])
  table_insert(args, _api_response)
  _client:api(unpack(args))
  if _android_token_req then
    _debug("Pushing PushToken API request")
    _config.pushToken = _android_token_req
    _config:save()
    _Q:add({
      type = "PushToken",
      args = {
        "/moai/pushtoken/" .. _android_token_req,
        "POST",
        json.encode({
          provider = "GOOGLE",
          channels = {
            "all",
            "GoogleUsers"
          }
        })
      }
    })
    _android_token_req = nil
  end
end
local function _push_lb_req(reqType, ...)
  _debug("LB Fetch: " .. reqType .. " API request")
  local _request = {
    type = reqType,
    args = {
      ...
    }
  }
  local args = _request.args
  if args[2] == nil then
    args[2] = "GET"
  end
  _debug("Cloud request: " .. args[2] .. " " .. args[1])
  table_insert(args, _leaderboard_response)
  table_insert(args, reqType)
  _client:api(unpack(args))
end
local function leaderboardFinished(reqType, response)
  if _leaderboardCallback then
    local newList = {}
    for k, v in pairs(response) do
      if tonumber(k) then
        newList[tonumber(k)] = v
      end
    end
    _leaderboardCallback(reqType, newList)
  end
end
function _leaderboard_response(response, responseCode, reqType)
  _debug("Cloud response: " .. reqType)
  local p = get_profile()
  if type(response) == "table" and response.error ~= nil then
    _error("Cloud error: Request = " .. util.tostr(args))
    response._request = _request
    analytics.error("MOAICLOUD_ERR", util.tostr(response))
  elseif reqType == "GetWeeklyBoardTime" then
    if response.stamp and p.survivalWTimeStamp and p.survivalWTimeStamp < response.stamp then
      p.survivalWHighScore = 0
      p.survivalWOmega13 = 0
      p.survivalWDeathBlossom = 0
      p.survivalWHighScoreWave = 0
      p.survivalWTimeStamp = nil
      p:save()
    end
  elseif reqType == "PostHighScore" then
    if _post_leaderboardCallback then
      _post_leaderboardCallback()
    end
  elseif reqType == "PostHighScoreWeekly" then
    if type(response) == "table" and response.userid == device.udid and p.survivalWHighScore and response.score >= p.survivalWHighScore then
      p.survivalWHighScore = response.score
      p.survivalWOmega13 = response.omega
      p.survivalWDeathBlossom = response.blossom
      p.survivalWHighScoreWave = response.wave
      p.survivalWTimeStamp = response.date
      p:save()
    end
    if _post_leaderboardCallback then
      _post_leaderboardCallback()
    end
  elseif reqType == "GetLeaderboard_Top" then
    _fetchingLB = false
    do
      local p = get_profile()
      local playerDef
      if type(response) == "table" then
        for k, v in pairs(response) do
          if v.userid and device.udid == v.userid and v.score then
            playerDef = v
            break
          end
        end
        if playerDef and p.survivalHighScore and playerDef.score > p.survivalHighScore then
          p.survivalHighScore = playerDef.score
          p.survivalOmega13 = playerDef.omega
          p.survivalDeathBlossom = playerDef.blossom
          p.survivalHighScoreWave = playerDef.wave
          if not p.levelSurvivorWave or p.levelSurvivorWave < playerDef.wave then
            p.levelSurvivorWave = playerDef.wave
          end
          p:save()
        end
      end
      leaderboardFinished(reqType, response)
    end
  elseif reqType == "GetLeaderboard_FB" then
    _fetchingLB_FB = false
    leaderboardFinished(reqType, response)
  elseif reqType == "GetLeaderboard_GC" then
    _fetchingLB_GC = false
    leaderboardFinished(reqType, response)
  elseif reqType == "GetLeaderboard_WTop" then
    _fetchingWLB = false
    leaderboardFinished(reqType, response)
  elseif reqType == "GetLeaderboard_WFB" then
    _fetchingWLB_FB = false
    leaderboardFinished(reqType, response)
  elseif reqType == "GetLeaderboard_WGC" then
    _fetchingWLB_GC = false
    leaderboardFinished(reqType, response)
  elseif reqType == "GetLeaderboardWinner_Top" then
    _fetchingWinner = response
  elseif reqType == "GetLeaderboardWinner_FB" then
    _fetchingWinner_FB = response
  elseif reqType == "GetLeaderboardWinner_GC" then
    _fetchingWinner_GC = response
  end
  if (reqType == "GetLeaderboard_WTop" or reqType == "GetLeaderboard_WFB" or reqType == "GetLeaderboard_WGC") and type(response) == "table" then
    for k, v in pairs(response) do
      if v.userid and device.udid == v.userid and v.score then
        playerDef = v
        break
      end
    end
    if playerDef and p.survivalWHighScore and playerDef.score >= p.survivalWHighScore then
      p.survivalWHighScore = playerDef.score
      p.survivalWOmega13 = playerDef.omega
      p.survivalWDeathBlossom = playerDef.blossom
      p.survivalWHighScoreWave = playerDef.wave
      p.survivalWTimeStamp = playerDef.date
      p:save()
    end
  end
end
function _api_response(response)
  _debug("Cloud response: " .. util.tostr(response))
  local reqType = _request.type
  if type(response) == "table" and response.error ~= nil and (response.responseCode == 0 or response.responseCode == 500) and reqType ~= "VersionCheck" then
    _debug("Error communicating with server (" .. response.responseCode .. "), retrying after a bit")
    _debug("Status: Waiting")
    timerutil.delaycall(ERROR_RETRY_TIME, function()
      _debug("Status: Retrying")
      _busy = false
      _next_req()
    end)
    return
  end
  _Q:remove()
  if type(response) == "table" and response.error ~= nil then
    _error("Cloud error: Request = " .. util.tostr(args))
    response._request = _request
    analytics.error("MOAICLOUD_ERR", util.tostr(response))
  elseif reqType == "VersionCheck" then
    if response.version then
      VersionCheck(response.version)
    elseif type(response[1]) == "table" then
      VersionCheck(response[1].version)
    end
  elseif reqType == "UDataCheck" then
    for k, v in ipairs(response) do
      if v.gift ~= nil and v.gift.cur ~= nil then
        _debug("Adding UData gift: " .. util.tostr(v.gift))
        profile_currency_txn(v.gift.cur, tonumber(v.gift.amt), "Gift: " .. v.note, true)
        UserDataGift(v.gift)
      else
        _warn("Unknown userdata record found: " .. util.tostr(v))
      end
    end
  elseif reqType == "PostHighScore" then
    if _post_leaderboardCallback then
      _post_leaderboardCallback()
    end
  elseif reqType == "InjectHSScores" then
    if _post_leaderboardCallback then
      _post_leaderboardCallback()
    end
  elseif reqType == "GetLeaderboard_Top" then
    _fetchingLB = false
    do
      local p = get_profile()
      local playerDef
      if type(response) == "table" then
        for k, v in pairs(response) do
          if v.userid and device.udid == v.userid and v.score then
            playerDef = v
            break
          end
        end
        if playerDef and p.survivalHighScore and playerDef.score > p.survivalHighScore then
          p.survivalHighScore = playerDef.score
          p.survivalOmega13 = playerDef.omega
          p.deathBlossom = playerDef.blossom
          p.survivalHighScoreWave = playerDef.wave
          if not p.levelSurvivorWave or p.levelSurvivorWave < playerDef.wave then
            p.levelSurvivorWave = playerDef.wave
          end
          p:save()
        end
      end
      leaderboardFinished(reqType, response)
    end
  elseif reqType == "GetLeaderboard_FB" then
    _fetchingLB_FB = false
    leaderboardFinished(reqType, response)
  elseif reqType == "GetLeaderboard_GC" then
    _fetchingLB_GC = false
    leaderboardFinished(reqType, response)
  elseif reqType == "GetLeaderboard_WTop" then
    _fetchingWLB = false
    leaderboardFinished(reqType, response)
  elseif reqType == "GetLeaderboard_WFB" then
    _fetchingWLB_FB = false
    leaderboardFinished(reqType, response)
  elseif reqType == "GetLeaderboard_WGC" then
    _fetchingWLB_GC = false
    leaderboardFinished(reqType, response)
  elseif reqType == "GetLeaderboardWinner_Top" then
    _fetchingWinner = response
  elseif reqType == "GetLeaderboardWinner_FB" then
    _fetchingWinner_FB = response
  elseif reqType == "GetLeaderboardWinner_GC" then
    _fetchingWinner_GC = response
  end
  if THROTTLE_TIME > 0 then
    _debug("Status: Throttling")
  end
  timerutil.delaycall(THROTTLE_TIME, function()
    _busy = false
    _next_req()
  end)
end
local function _push_req(reqType, ...)
  _debug("Pushing " .. reqType .. " API request")
  _Q:add({
    type = reqType,
    args = {
      ...
    }
  })
  if not _busy then
    _next_req()
  end
end
local function _onDidRegister(token)
  if MOAIEnvironment.getOSBrand() == MOAIEnvironment.OS_BRAND_IOS then
    _debug("Push Notification Token: " .. tostring(token))
    _config.pushToken = token
    _config:save()
    _push_req("PushToken", "/moai/pushtoken/" .. token, "POST", json.encode({
      provider = "APPLE",
      channels = {"all", "iOSUsers"}
    }))
  else
    _android_token_req = token
  end
end
local _onRemoteNotification = function(userInfo)
  print("Recieved remote notification")
end
local _androidTokenCall
local function androidTokenCheck()
  local token = MOAIApp:getRemoteNotificationToken()
  if token then
    print("Grabbed token: " .. token)
    _push_req("PushToken", "/moai/pushtoken/" .. token, "POST", json.encode({
      provider = "GOOGLE",
      channels = {
        "all",
        "GoogleUsers"
      }
    }))
    _androidTokenCall:stop()
    _androidTokenCall = nil
  end
end
function _M.init(clientKey, clientSecret)
  _client = moaicloud.new(clientKey, clientSecret)
  _Q = PersistentQueue.new("moai-cloud")
  _config = PersistentTable.new("moai-cloud-config", true)
  _postingScore = PersistentQueue.new("sbchs")
  _push_req("VersionCheck", "/moai/collections/versions", "GET", "q=" .. url.encode("{platform:'" .. device.platform .. "'}"))
  _debug("Cloud API initialized (Pending Requests: " .. _Q:len() .. ")")
  _next_req()
  if MOAIApp.registerForRemoteNotifications then
    MOAIApp.setListener(MOAIApp.DID_REGISTER, _onDidRegister)
    MOAIApp.setListener(MOAIApp.REMOTE_NOTIFICATION, _onRemoteNotification)
    _debug("Initializing push token")
    local token = _config.pushToken
    if token == nil then
      _debug("Did not find token, requesting..")
      _config.pushToken = true
      _config:save()
      if device.os == device.OS_ANDROID then
        _androidTokenCall = _androidAS:repeatcall(10, androidTokenCheck)
      end
      MOAIApp.registerForRemoteNotifications(MOAIApp.REMOTE_NOTIFICATION_ALERT)
    end
  end
  _M.fetchLeaderboards()
  _M.fetchLeaderboardWinner()
  _M.fetchFBLeaderboardWinner()
  _M.fetchGCLeaderboardWinner()
end
local function _add_std_log_fields(rec)
  local p = get_profile()
  rec._t = os.time()
  rec._udid = device.udid
  rec._utag = require("update").lastUpdateTag()
  rec._fbid = p.fbid
  return rec
end
function _M.postWaveResult(result)
  _add_std_log_fields(result)
  _push_req("WaveResult", "/moai/collections/log_waveresults", "POST", json.encode(result))
end
function _M.postGameResult(result)
  _add_std_log_fields(result)
  _push_req("GameResult", "/moai/collections/log_gameresults", "POST", json.encode(result))
end
function _M.postSurvivalGameResult(result)
  _add_std_log_fields(result)
  _push_req("SurvivalGameResult", "/moai/collections/log_survivalgameresults", "POST", json.encode(result))
end
function _M.injectHSUserData(score, omega13, deathBlossom, wave)
  local req = {}
  req.userid = device.udid
  req.omega = omega13
  req.blossom = deathBlossom
  req.wave = wave
  req.displayName = device.displayName
  req.db = "sbc.scores"
  req.inject = true
  _push_req("InjectHSScores", "/hbs/sbcleaderboard", "POST", json.encode(req))
end
function _M.postNewHighScore(score, alias, omega13, deathBlossom, wave, filter)
  local p = get_profile()
  local res = {}
  res.userid = device.udid
  res.unique = true
  res.score = score
  res.sort = desc
  res.username = p.highScoreAlias or alias or "?"
  res.wave = wave
  res.omega = omega13 or 0
  res.blossoms = deathBlossom or 0
  res.displayName = device.displayName or "Unknown"
  res.skipboard = filter
  if filter == "all" then
    _push_lb_req("PostHighScoreWeekly", "/hbs/sbcmultileaderboard", "POST", json.encode(res))
  else
    _push_lb_req("PostHighScore", "/hbs/sbcmultileaderboard", "POST", json.encode(res))
  end
end
function _M.postHighScore(score, alias, omega13, deathBlossom, wave)
  if not _postingScore or not _postingScore:empty() then
    return
  end
  local posting = {}
  local p = get_profile()
  local res = {}
  res.userid = device.udid
  res.unique = true
  res.score = score
  res.sort = desc
  res.username = p.highScoreAlias or alias or "?"
  posting.score = score
  posting.omega13 = omega13
  posting.deathBlossom = deathBlossom
  posting.wave = wave
  _M.mapGameCenterAccount()
  _M.mapFacebookAccount()
  _postingScore:add(posting)
  _push_req("PostHighScore", "/moai/leaderboard/sbc", "POST", json.encode(res))
end
function _M.updateCurrencyBalance(currencyType, amount, delta, note)
  local results = _add_std_log_fields({
    cur = currencyType,
    amt = amount,
    d = delta,
    n = note
  })
  _push_req("CurrencyBalance", "/moai/collections/log_currency", "POST", json.encode(results))
end
function _M.updateAchievementProgress(achievementId, progress, totalSteps)
  local p = get_profile()
  if p.udid == nil or p.udid == "UNKNOWN" then
    _warn("Cannot record achievement (" .. achievementId .. ") progress without UDID")
    return
  end
  local data = {
    achievementId = achievementId,
    stepscompleted = math.floor(progress * totalSteps)
  }
  _push_req("/moai/achievements/" .. p.udid, "POST", data)
end
function _M.checkForUserDataUpdates()
  if not device.udid or device.udid == "" or device.udid == "UNKNOWN" then
    return
  end
  _push_req("UDataCheck", "/hbs/udata/" .. url.encode(device.udid), "GET")
end
function _M.setLeaderboardCallback(callback)
  _leaderboardCallback = callback
end
function _M.setPostLeaderboardCallback(callback)
  _post_leaderboardCallback = callback
end
function _M.fetchLeaderboards()
  if _fetchingLB then
    return
  end
  _fetchingLB = true
  local numScores = LEADERBOARD_MAX_SCORES_TOP or 11
  local topBoard = string.format("page=%d&pagesize=%d&userid=", 1, numScores) .. device.udid
  _push_lb_req("GetLeaderboard_Top", "/moai/leaderboard/sbc", "GET", topBoard)
end
function _M.fetchFBLeaderboard()
  if not fb.isLoggedIn() or _fetchingLB_FB then
    return
  end
  _fetchingLB_FB = true
  local req = {}
  req.ids = {}
  local friends = fb.getFriendsList()
  for k, v in pairs(friends) do
    req.ids[#req.ids + 1] = v.id
  end
  req.ids[#req.ids + 1] = fb.getID()
  req.db = "sbc_facebook"
  _push_lb_req("GetLeaderboard_FB", "/hbs/sbcleaderboard", "POST", json.encode(req))
end
function _M.fetchGCLeaderboard()
  if not gamecenter.isLoggedIn() or _fetchingLB_GC then
    return
  end
  _fetchingLB_GC = true
  local req = {}
  req.ids = gamecenter.getFriendsList()
  req.ids[#req.ids + 1] = gamecenter.getID()
  req.db = "sbc_gamecenter"
  _push_lb_req("GetLeaderboard_GC", "/hbs/sbcleaderboard", "POST", json.encode(req))
end
function _M.fetchWeeklyLeaderboard()
  if _fetchingWLB then
    return
  end
  _fetchingWLB = true
  _M.fetchWeeklyBoardTime()
  _M.fetchLeaderboardWinner()
  local req = {}
  req.db = "sbc.week_scores"
  req.weeklytop = true
  req.pagesize = LEADERBOARD_MAX_SCORES_TOP or 11
  _push_lb_req("GetLeaderboard_WTop", "/hbs/sbcleaderboard", "POST", json.encode(req))
end
function _M.fetchWeeklyFBLeaderboard()
  if not fb.isLoggedIn() or _fetchingWLB_FB then
    return
  end
  _fetchingWLB_FB = true
  _M.fetchFBLeaderboardWinner()
  local req = {}
  req.ids = {}
  local friends = fb.getFriendsList()
  for k, v in pairs(friends) do
    req.ids[#req.ids + 1] = v.id
  end
  req.ids[#req.ids + 1] = fb.getID()
  req.db = "sbc_facebook"
  req.altdb = "sbc.week_scores"
  _push_lb_req("GetLeaderboard_WFB", "/hbs/sbcleaderboard", "POST", json.encode(req))
end
function _M.fetchWeeklyGCLeaderboard()
  if not gamecenter.isLoggedIn() or _fetchingWLB_GC then
    return
  end
  _fetchingWLB_GC = true
  _M.fetchGCLeaderboardWinner()
  local req = {}
  req.ids = gamecenter.getFriendsList()
  req.ids[#req.ids + 1] = gamecenter.getID()
  req.db = "sbc_gamecenter"
  req.altdb = "sbc.week_scores"
  _push_lb_req("GetLeaderboard_WGC", "/hbs/sbcleaderboard", "POST", json.encode(req))
end
function _M.getLeaderboardWinner()
  if not _fetchingWinner or type(_fetchingWinner) == "boolean" then
    return nil
  end
  return _fetchingWinner
end
function _M.fetchLeaderboardWinner()
  if _fetchingWinner then
    return
  end
  _fetchingWinner = true
  local req = {}
  req.db = "sbc.prev_week_scores"
  req.weeklytop = true
  req.pagesize = 1
  _push_lb_req("GetLeaderboardWinner_Top", "/hbs/sbcleaderboard", "POST", json.encode(req))
end
function _M.getFBLeaderboardWinner()
  if not _fetchingWinner_FB or type(_fetchingWinner_FB) == "boolean" then
    return nil
  end
  return _fetchingWinner_FB
end
function _M.fetchFBLeaderboardWinner()
  if not fb.isLoggedIn() or _fetchingWinner_FB then
    return
  end
  _fetchingWinner_FB = true
  local req = {}
  req.ids = {}
  local friends = fb.getFriendsList()
  for k, v in pairs(friends) do
    req.ids[#req.ids + 1] = v.id
  end
  req.ids[#req.ids + 1] = fb.getID()
  req.db = "sbc_facebook"
  req.altdb = "sbc.prev_week_scores"
  _push_lb_req("GetLeaderboardWinner_FB", "/hbs/sbcleaderboard", "POST", json.encode(req))
end
function _M.getGCLeaderboardWinner()
  if not _fetchingWinner_GC or type(_fetchingWinner_GC) == "boolean" then
    return nil
  end
  return _fetchingWinner_GC
end
function _M.fetchGCLeaderboardWinner()
  if not gamecenter.isLoggedIn() or _fetchingWinner_GC then
    return
  end
  _fetchingWinner_GC = true
  local req = {}
  req.ids = gamecenter.getFriendsList()
  req.ids[#req.ids + 1] = gamecenter.getID()
  req.db = "sbc_gamecenter"
  req.altdb = "sbc.prev_week_scores"
  _push_lb_req("GetLeaderboardWinner_GC", "/hbs/sbcleaderboard", "POST", json.encode(req))
end
function _M.mapFacebookAccount()
  if not fb.isLoggedIn() then
    return
  end
  local req = {}
  req._udid = device.udid
  req.account = fb.getID()
  req.alias = fb.getFullName()
  req.db = "sbc_facebook"
  req.code = "add"
  _push_req("MapFacebookAccount", "/hbs/accountmapper", "POST", json.encode(req))
end
function _M.mapFacebookAccount()
  if not fb.isLoggedIn() then
    return
  end
  local req = {}
  req._udid = device.udid
  req.account = fb.getID()
  req.alias = fb.getFullName()
  req.db = "sbc_facebook"
  req.code = "add"
  _push_req("MapFacebookAccount", "/hbs/accountmapper", "POST", json.encode(req))
end
function _M.unmapFacebookAccount()
  if not fb.isLoggedIn() then
    return
  end
  local req = {}
  req._udid = device.udid
  req.account = fb.getID()
  req.db = "sbc_facebook"
  req.code = "remove"
  _push_req("UnmapFacebookAccount", "/hbs/accountmapper", "POST", json.encode(req))
end
function _M.mapGameCenterAccount()
  if not gamecenter.isLoggedIn() then
    return
  end
  local req = {}
  req._udid = device.udid
  req.account = gamecenter.getID()
  req.alias = gamecenter.getAlias()
  req.db = "sbc_gamecenter"
  req.code = "add"
  _push_req("MapGameCenterAccount", "/hbs/accountmapper", "POST", json.encode(req))
end
function _M.unmapGameCenterAccount()
  if not gamecenter.isLoggedIn() then
    return
  end
  local req = {}
  req._udid = device.udid
  req.account = gamecenter.getID()
  req.db = "sbc_gamecenter"
  req.code = "remove"
  _push_req("UnmapGameCenterAccount", "/hbs/accountmapper", "POST", json.encode(req))
end
function _M.fetchWeeklyBoardTime()
  local req = {}
  req.timeType = "week"
  _push_lb_req("GetWeeklyBoardTime", "/hbs/timestamp", "POST", json.encode(req))
end
return _M
