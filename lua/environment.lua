local device = require("device")
local ui = require("ui")
local resource = require("resource")
local math2d = require("math2d")
local gfxutil = require("gfxutil")
local util = require("util")
local math = math
local random = math.random
local deg = math.deg
local sqrt = math.sqrt
local atan2 = math.atan2
local normalize = math2d.normalize
local distance = math2d.distance
local dot = math2d.dot
local dot = math2d.dot
local PI = math.pi
local cos = math.cos
local sin = math.sin
local floor = math.floor
local abs = math.abs
local table_insert = table.insert
local table_remove = table.remove
local breakstr = util.breakstr
local bucket = resource.bucket
local fogProp, bgProp, junkList, galaxyName, systemName, minJunkScale, maxJunkScale, minJunkRotSpeed, maxJunkRotSpeed, minJunkDir, maxJunkDir, junkSpeed, junkVariance
local function vary(x, variance)
  return x + random() * variance * 2 - variance
end
local _destroy_junk_object = function(junk)
  if junk.action then
    junk.action:stop()
    junk.action = nil
  end
  junk:remove()
end
local function _reset_junk_object(junk)
  if junk.type == "dust" then
    do
      local speed = vary(SPACE_DUST_SPEED, SPACE_DUST_VARIANCE)
      if random() < 0.5 then
        bgLayer2:add(junk)
        junk:setScl(1.25, 2.5)
      else
        mothershipLayer:add(junk)
        junk:setScl(1, 1.5)
        speed = speed / 2
      end
      local rot = random(MIN_DUST_DIR, MAX_DUST_DIR)
      junk:setRot(rot - 90)
      rot = math.rad(rot)
      junk.dx = cos(rot) * speed
      junk.dy = sin(rot) * speed
      local a = MIN_SPACE_DUST_OPACITY + random() * (MAX_SPACE_DUST_OPACITY - MIN_SPACE_DUST_OPACITY)
      junk:setColor(a, a, a, 0)
    end
  elseif junk.type == "fog" then
    do
      local speed = vary(FOG_SPEED, FOG_VARIANCE)
      bgLayer2:add(junk)
      junk:setIndex(random(junk.numFrames))
      scl = MIN_FOG_SCALE + random() * (MAX_FOG_SCALE / MIN_FOG_SCALE)
      junk:setScl(scl, scl)
      junk:setRot(random(360))
      junk.rotSpeed = random(MIN_FOG_ROT_SPEED, MAX_FOG_ROT_SPEED)
      junk.rotDir = 1
      if random() < 0.5 then
        junk.rotDir = -1
      end
      local rot = random(MIN_FOG_DIR, MAX_FOG_DIR)
      rot = math.rad(rot)
      junk.dx = cos(rot) * speed
      junk.dy = sin(rot) * speed
      local a = MIN_FOG_OPACITY + random() * (MAX_FOG_OPACITY - MIN_FOG_OPACITY)
      junk:setColor(a, a, a, 0)
    end
  else
    junkLayer:add(junk)
    junk:setIndex(random(junk.numFrames))
    junk:setRot(random(360))
    scl = minJunkScale + random() * (maxJunkScale / minJunkScale)
    junk:setScl(scl, scl)
    junk.rotSpeed = random(minJunkRotSpeed, maxJunkRotSpeed)
    junk.rotDir = 1
    if random() < 0.5 then
      junk.rotDir = -1
    end
    local rot = math.rad(random(minJunkDir, maxJunkDir))
    local speed = vary(junkSpeed, junkVariance)
    junk.dx, junk.dy = cos(rot) * speed, sin(rot) * speed
  end
  junk:setLoc(random(-junk.boundx, junk.boundx), junk.boundy)
  if junk.action then
    junk.action:stop()
    junk.action = nil
  end
end
local function _delay_reset_junk(junk)
  junk:remove()
  junk.action = environmentAS:delaycall(junk.resetMin + random() * (junk.resetMax - junk.resetMin), function()
    _reset_junk_object(junk)
  end)
end
local function _gen_junk(levelDef, galaxyIndex, systemIndex)
  local junk = {}
  local levelStr = string.format("GALAXY_%d_", galaxyIndex)
  local numDust = random(MIN_SPACE_DUST, MAX_SPACE_DUST)
  local minJunkObjects = 0
  local maxJunkObjects = 0
  if levelDef["Midground Objects"] and levelDef["Midground Objects"]:lower() == "yes" then
    minJunkObjects = _G[levelStr .. "MIN_JUNK_OBJECTS"] or MIN_JUNK_OBJECTS
    maxJunkObjects = _G[levelStr .. "MAX_JUNK_OBJECTS"] or MAX_JUNK_OBJECTS
  end
  local numJunk = random(minJunkObjects, maxJunkObjects)
  local numFog = random(MIN_FOG_OBJECTS, MAX_FOG_OBJECTS)
  local maxVal = math.max(numDust, numJunk)
  maxVal = math.max(maxVal, numFog)
  local filepath = string.format("galaxy%02dmid.atlas.png", galaxyIndex)
  local fogFilepath = "galaxy01fog.atlas.png"
  local minJunkResetTime = _G[levelStr .. "MIN_JUNK_RESET_TIME"] or MIN_JUNK_RESET_TIME
  local maxJunkResetTime = _G[levelStr .. "MAX_JUNK_RESET_TIME"] or MAX_JUNK_RESET_TIME
  minJunkScale = _G[levelStr .. "MIN_JUNK_SCALE"] or MIN_JUNK_SCALE
  maxJunkScale = _G[levelStr .. "MAX_JUNK_SCALE"] or MAX_JUNK_SCALE
  minJunkRotSpeed = _G[levelStr .. "MIN_JUNK_ROT_SPEED"] or MIN_JUNK_ROT_SPEED
  maxJunkRotSpeed = _G[levelStr .. "MAX_JUNK_ROT_SPEED"] or MAX_JUNK_ROT_SPEED
  minJunkDir = _G[levelStr .. "MIN_JUNK_DIR"] or MIN_JUNK_DIR
  maxJunkDir = _G[levelStr .. "MAX_JUNK_DIR"] or MAX_JUNK_DIR
  junkSpeed = _G[levelStr .. "JUNK_SPEED"] or JUNK_SPEED
  junkVariance = _G[levelStr .. "JUNK_VARIANCE"] or JUNK_VARIANCE
  bucket.push("JUNK_OBJECTS")
  for i = 1, maxVal do
    if i <= numDust then
      local dustObj = ui.Image.new("spaceDustStreak.png")
      dustObj.type = "dust"
      dustObj.boundx = stageHeight
      dustObj.boundy = stageHeight + 350
      dustObj.resetMin = MIN_DUST_RESET_TIME
      dustObj.resetMax = MAX_DUST_RESET_TIME
      dustObj.destroy = _destroy_junk_object
      dustObj.reset = _delay_reset_junk
      junk[#junk + 1] = dustObj
      dustObj:reset()
    end
    if i <= numFog then
      local fogObj = ui.Image.new(fogFilepath)
      local index = fogObj._deck.numFrames
      fogObj.numFrames = index
      fogObj.type = "fog"
      fogObj.boundx = stageHeight + 500
      fogObj.boundy = stageHeight + 500
      fogObj.resetMin = MIN_FOG_RESET_TIME
      fogObj.resetMax = MAX_FOG_RESET_TIME
      fogObj.destroy = _destroy_junk_object
      fogObj.reset = _delay_reset_junk
      junk[#junk + 1] = fogObj
      _reset_junk_object(fogObj)
      local x, y = fogObj:getLoc()
      fogObj:setLoc(x, random(-fogObj.boundy, fogObj.boundy))
    end
    if i <= numJunk then
      local junkObj = ui.Image.new(filepath)
      local index = junkObj._deck.numFrames
      junkObj.numFrames = index
      junkObj.type = "junk"
      local boundx = stageWidth
      junkObj.boundx = boundx
      local boundy = (stageHeight + 600) / 2
      junkObj.boundy = boundy
      junkObj.resetMin = minJunkResetTime
      junkObj.resetMax = maxJunkResetTime
      junkObj.destroy = _destroy_junk_object
      junkObj.reset = _delay_reset_junk
      junk[#junk + 1] = junkObj
      _reset_junk_object(junkObj)
      junkObj:setLoc(random(-boundx, boundx), random(-boundy, boundy))
    end
  end
  bucket.pop()
  return junk
end
local function _destroy_junk()
  for k, v in pairs(junkList) do
    v:destroy()
  end
  junkList = nil
  bucket.release("JUNK_OBJECTS")
end
local function _environment_tick(dt)
  bgProp:addLoc(0, dt * BG_PIXELS_PER_SECOND)
  for k, v in pairs(junkList) do
    if not v.action then
      v:addLoc(v.dx * dt, v.dy * dt)
      if v.rotSpeed then
        v:addRot(v.rotSpeed * v.rotDir * dt)
      end
      local x, y = v:getLoc()
      local boundx, boundy = v.boundx, v.boundy
      if x < -boundx or x > boundx or y < -boundy then
        v:reset()
      end
    end
  end
end
function environment_clear()
  environmentAS:stop()
  environmentAS:clear()
  bucket.release("LEVEL_BG")
  _destroy_junk()
  bgLayer1:clear()
  bgLayer2:clear()
end
local _nonempty = function(x, def)
  if x ~= nil and x ~= "" then
    return x
  else
    return def
  end
end
function environment_load(galaxyIndex, systemIndex)
  local idx = (galaxyIndex - 1) * 40 + systemIndex
  bucket.push("LEVEL_BG")
  assert(GALAXY_DATA[idx] ~= nil, "Invalid galaxy index: " .. tostring(galaxyIndex) .. "." .. tostring(systemIndex))
  local levelDef = GALAXY_DATA[idx]
  if bgProp then
    bgProp:remove()
  end
  if gameMode == "galaxy" then
    bgProp = gfxutil.createTilingBG(_nonempty(levelDef["BG Image"], "galaxy01BG.png"))
  elseif gameMode == "survival" then
    bgProp = gfxutil.createTilingBG(SURVIVAL_MODE_SYSTEM_BG)
  end
  local bgScale = 1.75
  if device.ui_assetrez == device.ASSET_MODE_LO then
    bgScale = bgScale * 2
  elseif device.ui_assetrez == device.ASSET_MODE_X_HI then
    bgScale = bgScale / 1.5
  end
  local randY = random(bgProp.height * bgScale)
  if idx == 1 then
    randY = -540
  end
  bgProp:setLoc(-bgProp.width / 2 * bgScale, randY)
  bgProp:setScl(bgScale, bgScale)
  bgLayer1:add(bgProp)
  bucket.pop()
  junkList = _gen_junk(levelDef, galaxyIndex, systemIndex)
  if gameMode == "galaxy" then
    galaxyName = _nonempty(levelDef["Galaxy Name"], "Galaxy")
    systemName = _nonempty(levelDef["System Name"], "System")
  elseif gameMode == "survival" then
    galaxyName = SURVIVAL_MODE_1_GALAXY
    systemName = SURVIVAL_MODE_1_SYSTEM
  end
  environmentAS:start()
  environmentAS:run(_environment_tick)
end
function environment_getlevelstring()
  return string.format([[
%s
%s]], galaxyName, systemName)
end
