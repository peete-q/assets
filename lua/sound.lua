local device = require("device")
local util = require("util")
local url = require("url")
local breakstr = util.breakstr
local header = "sfx/"
local ext = ".wav"
local sound = {}
if device.hasCAF then
  ext = ".caf"
end

local _sample_table = {}
local _looping_sounds = {}
local _M = {}
function _M.init()
  if not MOAIUntzSystem or _sound_system then
    return
  end
  MOAIUntzSystem.initialize()
  _sound_system = true
  _sample_table = {}
  _M.setMute(soundMute)
  _M.setMute(musicMute, true)
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

sound.__index = sound
sound.setMute = _M.setMute
function sound.new(path, music, streaming, softenAndroid)
  _M.init()
  
  local newpath, queryStr = breakstr(path, "?")
  local sample
  if streaming then
    sample = header .. newpath .. ext
  else
    sample = _M.loadSample(header .. newpath .. ext)
  end
  if not sample or not MOAIUntzSystem then
    return
  end
  local o = {}
  o.sound = MOAIUntzSound.new()
  if streaming then
    o.sound:load(sample, false)
  else
    o.sound:load(sample)
  end
  o.volume = 1
  if queryStr ~= nil then
    local q = url.parse_query(queryStr)
    if q.volume then
      o.volume = tonumber(q.volume)
    end
  end
  if (softenAndroid or newpath == "alienBomber") and device.os == device.OS_ANDROID then
    print("Softening android from", o.volume, "To", o.volume * 0.15)
    o.volume = o.volume * 0.15
  end
  o.sound:setVolume(o.volume)
  o.isMusic = music
  o.destroy = sound.destroy
  o.play = sound.play
  o.loop = sound.loop
  return o
end
function sound:play(loop)
  if _M.getMute(self.isMusic) then
    if loop then
      self.sound:setVolume(0)
    else
      return
    end
  end
  self.sound:setLooping(loop)
  self.sound:play()
end
function sound:loop()
  if self.looping then
    return
  end
  self.looping = true
  _M.addLoopingSound(self)
  self:play(true)
end
function sound:stop()
  self.sound:stop()
  if self.looping then
    self.looping = false
    _M.removeLoopingSound(self)
    self.sound:setVolume(o.volume)
  end
end
return sound
