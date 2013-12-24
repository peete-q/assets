local soundmanager = require("soundmanager")
local device = require("device")
local util = require("util")
local url = require("url")
local breakstr = util.breakstr
local header = "sfx/"
local ext = ".wav"
local SoundInstance = {}
if device.hasCAF then
  ext = ".caf"
end
SoundInstance.__index = SoundInstance
function SoundInstance.new(path, music, streaming, softenAndroid)
  local newpath, queryStr = breakstr(path, "?")
  local sample
  if streaming then
    sample = header .. newpath .. ext
  else
    sample = soundmanager.loadSample(header .. newpath .. ext)
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
  o.destroy = SoundInstance.destroy
  o.play = SoundInstance.play
  o.loop = SoundInstance.loop
  return o
end
function SoundInstance:play(loop)
  if soundmanager.getMute(self.isMusic) then
    if loop then
      self.sound:setVolume(0)
    else
      return
    end
  end
  self.sound:setLooping(loop)
  self.sound:play()
end
function SoundInstance:loop()
  if self.looping then
    return
  end
  self.looping = true
  soundmanager.addLoopingSound(self)
  self:play(true)
end
function SoundInstance:stop()
  self.sound:stop()
  if self.looping then
    self.looping = false
    soundmanager.removeLoopingSound(self)
    self.sound:setVolume(o.volume)
  end
end
return SoundInstance
