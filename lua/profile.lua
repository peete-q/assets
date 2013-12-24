local file = require("file")
local util = require("util")
local device = require("device")
local entitydef = require("entitydef")
local PersistentTable = require("PersistentTable")
local analytics = require("analytics")
local cloud = require("cloud")
local keys = require("keys")
local set_if_nil = util.set_if_nil
local profile
local profileIndex = PersistentTable.new(device.getDocumentsPath() .. "/user_index.lua")
local function _load_profile(profileId, createIfNeeded)
  local userFile = device.getDocumentsPath() .. "/" .. string.format("user_%d.lua", profileId)
  local exists = file.exists(userFile)
  if not createIfNeeded and not exists then
    return nil
  end
  local profile = PersistentTable.new(userFile, nil, keys.v0)
  set_if_nil(profile, "alloy", STARTING_ALLOY)
  set_if_nil(profile, "creds", STARTING_CREDS)
  set_if_nil(profile, "level", 1)
  set_if_nil(profile, "xp", 0)
  set_if_nil(profile, "rated", false)
  set_if_nil(profile, "unlocks", {})
  local unlocks = {}
  for i, v in pairs(entitydef) do
    if v.type == "capitalship" and v.storeUnlockLevel == 0 and v._upgradeNum == 0 then
      unlocks[v._baseID] = v
    end
  end
  for k, v in pairs(unlocks) do
    set_if_nil(profile.unlocks, k, {})
    set_if_nil(profile.unlocks[k], "unlocked", true)
    set_if_nil(profile.unlocks[k], "currentUpgrade", 0)
    set_if_nil(profile.unlocks[k], "popupUnlock", true)
  end
  set_if_nil(profile.unlocks, "SPC", {})
  set_if_nil(profile.unlocks.SPC, "unlocked", true)
  set_if_nil(profile.unlocks.SPC, "currentUpgrade", 0)
  set_if_nil(profile.unlocks.SPC, "popupUnlock", true)
  set_if_nil(profile, "levels", {})
  set_if_nil(profile.levels, 1, {})
  set_if_nil(profile.levels[1], "kills", 0)
  set_if_nil(profile, "levelSurvivorWave", 0)
  set_if_nil(profile, "survivalHighScore", 0)
  set_if_nil(profile, "survivalHighScoreWave", 0)
  set_if_nil(profile, "survivalOmega13", 0)
  set_if_nil(profile, "survivalDeathBlossom", 0)
  set_if_nil(profile, "survivalWHighScore", 0)
  set_if_nil(profile, "survivalWHighScoreWave", 0)
  set_if_nil(profile, "profile.survivalWOmega13", 0)
  set_if_nil(profile, "survivalWDeathBlossom", 0)
  set_if_nil(profile, "lastLeaderboardBtn", "top")
  set_if_nil(profile, "achievements", {})
  set_if_nil(profile, "popups", {})
  set_if_nil(profile, "purchases", {})
  if not profile.purchases then
    profile.purchases = {}
  end
  if device.os ~= device.OS_ANDROID then
    set_if_nil(profile, "excludeAds", false)
  end
  set_if_nil(profile, "sound", true)
  set_if_nil(profile, "music", true)
  set_if_nil(profile, "name", string.format("Player %d", profileId))
  set_if_nil(profile, "profileId", profileId)
  if device.os == device.OS_ANDROID then
    set_if_nil(profile, "excludeAds", true)
    set_if_nil(profile.purchases, "ads.1", true)
  end
  profile:save()
  if not exists then
    print("Profile: Creating User Profile " .. profileId)
    profileIndex:push(profileId)
    profileIndex:save()
  end
  return profile
end
local function _create_new_profile()
  local maxid = 0
  for i, id in ipairs(profileIndex) do
    maxid = math.max(id, maxid)
  end
  return _load_profile(maxid + 1, true)
end
local function _select_profile(newProfile)
  if profile ~= nil and profile.profileId == newProfile.profileId then
    return
  end
  profile = newProfile
  profileIndex.currentProfileId = profile.profileId
  profileIndex:save()
  print("Profile: Selecting user profile #" .. profile.profileId .. " (" .. profile.name .. ")")
end
function profile_init()
  _select_profile(_load_profile(profileIndex.currentProfileId or 1, true))
end
function get_profile()
  return profile
end
function profile_currency_txn(currencyType, amount, note, saveNow)
  assert(note ~= nil and note ~= "", "invalid note (must be non-empty string)")
  assert(type(amount) == "number", "currency txn amount must be a number")
  if amount == 0 and not note:find("Session Start") then
    return
  end
  profile[currencyType] = profile[currencyType] + amount
  if saveNow == nil or saveNow then
    profile:save()
  end
  cloud.updateCurrencyBalance(currencyType, profile[currencyType], amount, note)
  analytics.currencyBalance(currencyType, profile[currencyType], amount, note)
end
function profile_get_level_id()
  local lastCompletedGalaxy = 0
  local lastCompletedSystem = 0
  local stop
  for i, galaxy in ipairs(profile.levels) do
    lastCompletedGalaxy = lastCompletedGalaxy + 1
    lastCompletedSystem = 0
    for j, system in ipairs(galaxy) do
      if system.stars ~= nil then
        lastCompletedSystem = lastCompletedSystem + 1
      else
        stop = true
        break
      end
    end
    if stop then
      break
    end
  end
  return profile.level .. "-G" .. lastCompletedGalaxy .. "-S" .. lastCompletedSystem
end
