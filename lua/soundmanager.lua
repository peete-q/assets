require("profile")
local device = require("device")
local util = require("util")
local url = require("url")
local breakstr = util.breakstr
local profile = get_profile()
local _sound_system
local _sample_table = {}
local _sound_table = {}
local _looping_sounds = {}
local _M = {}
local header = "sfx/"
local ext = ".wav"
local soundMute, musicMute
if device.hasOGG then
  ext = ".ogg"
end
if device.hasCAF then
  ext = ".caf"
end
local function onSoundCalled(id)
  if _sound_table[id] and not soundMute then
    _sound_table[id]:play()
  end
end
local function loadSound(path, streaming)
  local newpath, queryStr = breakstr(path, "?")
  local sample
  if streaming then
    sample = header .. newpath .. ext
  else
    sample = _M.loadSample(header .. newpath .. ext)
  end
  if not sample then
    return nil
  end
  local o = MOAIUntzSound.new()
  if streaming then
    o:load(sample, false)
  else
    o:load(sample)
  end
  o.volume = 1
  if queryStr ~= nil then
    local q = url.parse_query(queryStr)
    if q.volume then
      o.volume = tonumber(q.volume)
    end
  end
  o:setVolume(o.volume)
  return o
end
local function initBaseSounds()
  _sound_table.onClick = loadSound("ui_click_01?volume=0.6")
  _sound_table.onMenu = loadSound("ui_achievementwindow_01")
  _sound_table.onMessage = loadSound("ui_messageopen")
  _sound_table.onMessagePage = loadSound("ui_swipe_back_01?volume=0.6")
  _sound_table.onMessageEnd = loadSound("ui_messageend?volume=0.6")
  _sound_table.onSetPatrol = loadSound("uiSetPatrol?volume=0.3")
  _sound_table.onUnavailable = loadSound("ui_incorrectselect_01")
  _sound_table.onFinalWave = loadSound("ui_finalwave_notification_0")
  _sound_table.onCapShipRebirth = loadSound("game_spc_reverse_01", true)
  _sound_table.onDefeat = loadSound("HBSF_stinger_defeat", true)
  _sound_table.onVictory = loadSound("HBSF_stinger_victory", true)
  _sound_table.onCountdown = loadSound("ui_countdown_01")
  _sound_table.onWarp = loadSound("game_shipwarping_01?volume=0.7")
  _sound_table.onUpgradeAnticipation = loadSound("ui_upgrade_anticipate_01")
  _sound_table.onUpgradeSelect = loadSound("ui_upgrade_select_01")
  _sound_table.onPointCount = loadSound("ui_pointcount_sfx_01?volume=0.8")
  _sound_table.onAlloyCount = loadSound("ui_alloycount?volume=0.1")
  _sound_table.onPageSwipeForward = loadSound("ui_swipe_forward_01?volume=0.5")
  _sound_table.onPageSwipeBack = loadSound("ui_swipe_back_01?volume=0.3")
  _sound_table.onDeathBlossomAnticipation = loadSound("game_blossomanticipation_01?volume=0.9")
  _sound_table.onDeathBlossomChargeup = loadSound("game_blossomanchargeup?volume=0.4")
  _sound_table.onDeathBlossom = loadSound("game_deathblossom_explosion")
  _sound_table.onPurchase = loadSound("ui_upgrade_select_01?volume=0.9")
  _sound_table.onPerkSelect = loadSound("ui_perk_select_01?volume=0.6")
  _sound_table.onAwardpickup = loadSound("game_awardpickup_01?volume=0.5")
  _sound_table.onStar = loadSound("ui_star_01?volume=0.4")
  _sound_table.onConstruction = loadSound("game_enemyconstruction_01?volume=0.2")
  _sound_table.onSystemSelect = loadSound("ui_messageprompt_01")
  _sound_table.onLevelUp = loadSound("ui_levelup_stinger")
  _sound_table.artilleryFire1 = loadSound("game_artillerylaunch_01?volume=0.4")
  _sound_table.artilleryFire2 = loadSound("game_artillerylaunch_01?volume=0.4")
  _sound_table.artilleryImpact1 = loadSound("game_artillaryimpact_01")
  _sound_table.artilleryImpact2 = loadSound("game_artillaryimpact_02")
  _sound_table.impact1 = loadSound("game_explosion_01")
  _sound_table.impact2 = loadSound("game_explosion_02")
  _sound_table.impact3 = loadSound("game_explosion_03")
  _sound_table.laser1 = loadSound("game_fighterlaser_01?volume=0.2")
  _sound_table.laser2 = loadSound("game_fighterlaser_02?volume=0.2")
  _sound_table.laser3 = loadSound("game_fighterlaser_03?volume=0.2")
end
function _M.init()
  if not MOAIUntzSystem or _sound_system then
    return
  end
  MOAIUntzSystem.initialize()
  _sound_system = true
  _sample_table = {}
  _sound_table = {}
  initBaseSounds()
  _M.setMute(not profile.sound)
  _M.setMute(not profile.music, true)
end
function _M.deinit()
  _sound_system = nil
  _sample_table = nil
end
function _M.loadSample(path)
  if not MOAIUntzSystem or not _sound_system then
    return nil
  end
  local sample = _sample_table[path]
  if sample then
    return sample
  end
  sample = MOAIUntzSampleBuffer.new()
  sample:load(path)
  _sample_table[path] = sample
  return sample
end
function _M.getMute(isMusic)
  if isMusic then
    return musicMute
  end
  return soundMute
end
function _M.setMute(isMute, isMusic)
  if isMusic then
    if isMute == musicMute then
      return
    end
    musicMute = isMute
  else
    if isMute == soundMute then
      return
    end
    soundMute = isMute
    local vol = 1
    if isMute then
      vol = 0
    end
    local numSounds = #_looping_sounds
    for i = 1, numSounds do
      local instance = _looping_sounds[i]
      instance.sound:setVolume(vol)
    end
  end
end
function _M.toggleMute(isMusic)
  if isMute then
    _M.setMute(not musicMute, true)
  else
    _M.setMute(not soundMute, true)
  end
end
function _M.addLoopingSound(instance)
  _looping_sounds[#_looping_sounds + 1] = instance
end
function _M.removeLoopingSound(instance)
  local numSounds = #_looping_sounds
  for i = 1, numSounds do
    local _sound = _looping_sounds[i]
    if _sound == instance then
      table.remove(_looping_sounds, i)
      return
    end
  end
end
function _M.onSFX(sfx)
  onSoundCalled(sfx)
end
function _M.onClick()
  onSoundCalled("onClick")
end
function _M.onMenu()
  onSoundCalled("onMenu")
end
function _M.onMessage()
  onSoundCalled("onMessage")
end
function _M.onNoCash()
  onSoundCalled("onNoCash")
end
function _M.onSelect()
  onSoundCalled("onSelect")
end
function _M.onSetPatrol()
  onSoundCalled("onSetPatrol")
end
function _M.onUnavailable()
  onSoundCalled("onUnavailable")
end
local _numArtFireSounds = 2
function _M.onArtilleryFire()
  local idx = math.random(1, _numArtFireSounds)
  onSoundCalled(string.format("artilleryFire%d", idx))
end
local _numArtHitSounds = 2
function _M.onArtilleryImpact()
  local idx = math.random(1, _numArtHitSounds)
  onSoundCalled(string.format("artilleryImpact%d", idx))
end
local _numGunFireSounds = 3
function _M.onGunfire()
  local idx = math.random(1, _numGunFireSounds)
  onSoundCalled(string.format("laser%d", idx))
end
local _numImpactSounds = 3
function _M.onImpact()
  local idx = math.random(1, _numImpactSounds)
  onSoundCalled(string.format("impact%d", idx))
end
return _M
