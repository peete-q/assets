local _M = {}
local _debug, _warn, _error = require("qlog").loggers("analytics")
local Flurry = Flurry
if Flurry == nil then
  do
    local util = require("util")
    Flurry = {
      logEvent = function(evt, args)
        if args ~= nil then
          _debug(evt, util.tostr(args))
        else
          _debug(evt)
        end
      end,
      logError = function(errId, msg)
        _error(errId, msg)
      end
    }
  end
end
local _logEvent = Flurry.logEvent
function _M.error(errorId, message)
  Flurry.logError(errorId, message)
end
function _M.levelStart(levelId, time)
  _logEvent("LEVEL_START", {levelId = levelId, time = time})
end
function _M.levelProgress(levelId, time, progress)
  _logEvent("LEVEL_PROGRESS", {
    levelId = levelId,
    time = time,
    progress = progress
  })
end
function _M.levelEnd(levelId, result, progress)
  _logEvent("LEVEL_END", {
    levelId = levelId,
    result = result,
    progress = progress
  })
end
function _M.tutorialStep(step)
  _logEvent("TUTORIAL_STEP", {step = step})
end
function _M.tutorialComplete(skipped)
  if skipped then
    _logEvent("TUTORIAL_END", {skipped = true})
  else
    _logEvent("TUTORIAL_END", {skipped = false})
  end
end
function _M.moreGamesPressed()
  _logEvent("XSELL_MORE_GAMES")
end
function _M.rateAppRequest(ratedApp)
  _logEvent("RATE_APP", {rated = ratedApp})
end
function _M.versionAvailableRequest(result)
  _logEvent("VERSION_AVAILABLE", {result = result})
end
function _M.storeVisited(referer)
  _logEvent("STORE_VISITED", {referer = referer})
end
function _M.storePurchaseSuccess(itemId, currencyType, amount, levelId, extra)
  assert(currencyType ~= nil, "currencyType must be provided")
  assert(amount ~= nil, "amount must be provided")
  _logEvent("STORE_BUY", {
    itemId = itemId,
    cur = currencyType,
    amt = amount,
    levelId = levelId,
    extra = extra
  })
end
function _M.storePurchaseCancel(itemId, currencyType, amount, levelId)
  assert(currencyType ~= nil, "currencyType must be provided")
  assert(amount ~= nil, "amount must be provided")
  _logEvent("STORE_CANCEL", {
    itemId = itemId,
    cur = currencyType,
    amt = amount,
    levelId = levelId
  })
end
function _M.storePurchaseFailed(itemId, errorStr)
  _logEvent("STORE_FAIL", {itemId = itemId, error = errorStr})
end
function _M.socialPost(channel, storyType)
  assert(channel ~= nil, "Must provide a channel type (e.g. \"FB\")")
  _logEvent("SOCIAL_POST", {channel = channel, storyType = storyType})
end
function _M.currencyBalance(currencyType, amount, delta, note)
  _logEvent("CURRENCY_BALANCE", {
    cur = currencyType,
    amt = amount,
    d = delta,
    note = note
  })
end
function _M.gameShopPurchaseSuccess(itemId, currencyType, amount, levelId)
  assert(currencyType ~= nil, "currencyType must be provided")
  assert(amount ~= nil, "amount must be provided")
  _logEvent("SHOP_BUY", {
    itemId = itemId,
    cur = currencyType,
    amt = amount,
    levelId = levelId
  })
end
function _M.gameShopPurchaseCancel(itemId, currencyType, amount, levelId)
  _logEvent("SHOP_CANCEL", {
    itemId = itemId,
    cur = currencyType,
    amt = amount,
    levelId = levelId
  })
end
function _M.customEvent(name, args)
  assert(name ~= nil, "Must provide an event name")
  assert(name:len() < 250, "Name is invalid")
  _logEvent(name, args)
end
return _M
