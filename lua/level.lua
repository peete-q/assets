require("levelui")
require("profile")
local Entity = require("Entity")
local device = require("device")
local ui = require("ui")
local entitydef = require("entitydef")
local math2d = require("math2d")
local gfxutil = require("gfxutil")
local behavior = require("behavior")
local interpolate = require("interpolate")
local randutil = require("randutil")
local soundmanager = require("soundmanager")
local util = require("util")
local url = require("url")
local Particle = require("Particle")
local memory = require("memory")
local spawn = require("level_spawn")
local update = require("update")
local fxdef = require("FxDef")
local popups = require("popups")
local achievements = require("achievements")
local analytics = require("analytics")
local cloud = require("cloud")
local fb = require("fb")
local gamecenter = require("gamecenter")
local math = math
local random = math.random
local deg = math.deg
local sqrt = math.sqrt
local atan2 = math.atan2
local normalize = math2d.normalize
local distance = math2d.distance
local dot = math2d.dot
local dot = math2d.dot
local ptSegDistSq = math2d.pointSegmentDistanceSq
local PI = math.pi
local cos = math.cos
local sin = math.sin
local floor = math.floor
local ceil = math.ceil
local abs = math.abs
local table_insert = table.insert
local table_remove = table.remove
local breakstr = util.breakstr
local set_if_nil = util.set_if_nil
local bucket = resource.bucket
local profile = get_profile()
local _debug, _warn, _error = require("qlog").loggers("level")
local levelDef, levelEnemyDefList, listHead
local camScrollX = 0
local camScrollY = 0
local camShakes = {}
local camShakeX = 0
local camShakeY = 0
local oobmult = 2
local ll = -levelWidth * oobmult
local rr = levelWidth * oobmult
local bb = -levelHeight * oobmult
local tt = levelHeight * oobmult
local indmult = 1.15
local offl = -levelWidth * indmult
local offr = levelWidth * indmult
local offb = -levelHeight * indmult
local offt = levelHeight * indmult
local introShipList, levelGalaxySystemIndex, levelGalaxyIndex, levelSystemIndex, levelSpawns, curLevelGalaxyIndex, curLevelSystemIndex, levelDone, levelOver, levelOverText, levelWave, wave, maxWave, levelStartTime, levelCheapestWarpItem, resourceAccum
local _entity_id = 0
local lastCannonHitWave = 0
local cannonHitEnemy = false
local cannons = {}
local levelWarpAvailable, spawns, spawnSaucer
local pinching = false
gameSessionAnalytics = {}
gameMode = "galaxy"
function level_get_galaxy_system()
  return levelGalaxyIndex, levelSystemIndex, levelGalaxySystemIndex
end
local P = function(x, y)
  return "(" .. tostring(x) .. "," .. tostring(y) .. ")"
end
local clampToLevelBounds = function(x, y, margin)
  margin = margin or levelWidth / 2
  if x < -levelWidth + margin then
    x = -levelWidth + margin
  elseif x > levelWidth - margin then
    x = levelWidth - margin
  end
  if y < -levelHeight + margin then
    y = -levelHeight + margin
  elseif y > levelHeight - margin then
    y = levelHeight - margin
  end
  return x, y
end
local _accumulate_max_dc = function(obj, startDC)
  if not obj:isAlive() or obj.hp <= 0 then
    return
  end
  if obj.def.maxDC then
    maxDC = maxDC + obj.def.maxDC
  end
  if startDC and obj.def.startDC then
    scores.blue = scores.blue + obj.def.startDC
  end
end
local function _closest_object(obj, x, y, closest)
  local _x, _y = obj:getLoc()
  local d = distance(x, y, _x, _y)
  if closest.dist == nil or d < closest.dist then
    closest.target = obj
    closest.dist = d
  end
end
local function _it_table_insert(obj, t)
  table_insert(t, obj)
end
local function _fillbar_seek_fill(actionset, fillbar, startValLeft, startValRight, endValLeft, endValRight, length, sound)
  local runtime = 0
  local leftNum, prevLeftNum, rightNum, prevRightNum, action
  action = actionset:run(function(dt)
    if runtime < length then
      runtime = runtime + dt
      if runtime > length then
        runtime = length
      end
      leftNum = interpolate.lerp(startValLeft, endValLeft, runtime / length)
      rightNum = interpolate.lerp(startValRight, endValRight, runtime / length)
      fillbar:setFill(leftNum, rightNum)
      if prevLeftNum ~= nil and floor(prevLeftNum * 100) ~= floor(leftNum * 100) or prevRightNum ~= nil and floor(prevRightNum * 100) ~= floor(rightNum * 100) then
        if sound and sound ~= false then
          soundmanager.onSFX(sound)
        elseif sound == nil then
          soundmanager.onSFX("onPointCount")
        end
      end
      prevLeftNum = leftNum
      prevRightNum = rightNum
    else
      action:stop()
    end
  end)
end
local function _particle_explosion(x, y, layer, textureName, override)
  if not layer then
    return
  end
  if MOAIPexPlugin then
    local system = layer:add(Particle.new(textureName, levelAS, override))
    system:setLoc(x, y)
    system:setPriority(10)
    system:updateSystem()
    system:begin(true)
    return
  end
  local system = levelAS:wrap(layer:add(ui.ParticleSystem.new("particles/" .. textureName, nil, override)))
  system:setLoc(x, y)
  system:setPriority(10)
  system:startSystem(true)
  system:updateSystem()
  local poll = MOAIThread.new()
  poll:run(function()
    system:surgeSystem()
    while not system:isIdle() do
      coroutine.yield()
    end
    system:stopSystem()
    system:remove()
    system = nil
  end)
end
local function _flipbook_explosion(x, y, layer, textureName)
  local _, queryStr = breakstr(textureName, "?")
  local anim
  if queryStr ~= nil then
    local q = url.parse_query(queryStr)
    anim = q.anim
  end
  if not anim then
    return
  end
  local p = ui.Anim.new(textureName)
  layer:insertProp(p)
  p:setLoc(x, y)
  p:setPriority(10)
  levelAS:wrap(p:play(anim, function()
    layer:removeProp(p)
    p = nil
  end))
end
local function _explosion(x, y, size, layer, textureName)
  size = size or 16
  local TIME = 1.5
  local SCL = size / 7
  local p = ui.Image.new(textureName or "fireball.png")
  layer:insertProp(p)
  p:setLoc(x, y)
  p:setScl(0, 0)
  p:setPriority(10)
  levelAS:wrap(p:seek(x, y, math.random(90) - 180, SCL, SCL, TIME, MOAIEaseType.EASE_IN), function()
    layer:removeProp(p)
  end)
end
function level_fx_explosion(x, y, size, layer, textureName)
  if type(textureName) == "table" then
    for k, v in ipairs(textureName) do
      if type(v) == "string" then
        level_fx_explosion(x, y, size, layer, v)
      end
    end
    return
  end
  local texName, queryStr = breakstr(textureName, "?")
  local args
  local delay = 0
  local override
  if queryStr ~= nil then
    args = url.parse_query(queryStr)
    if args.delay ~= nil then
      delay = args.delay
    end
    if args.override ~= nil then
      override = true
    end
  end
  levelAS:delaycall(delay, function()
    if texName and string.find(texName, ".pex") then
      _particle_explosion(x, y, layer or mainLayer, textureName, override)
    elseif texName and args ~= nil and args.anim then
      _flipbook_explosion(x, y, layer or mainLayer, textureName)
    elseif texName == "cameraShake" then
      if args then
        level_fx_camera_shake(args.strength or 50)
      end
    else
      _explosion(x, y, size, layer or mainLayer, texName)
    end
    if size > 25 then
      level_fx_camera_shake(size * 0.25)
    end
  end)
end
function level_fx_explosion_blue(x, y, size, layer)
  _explosion(x, y, size, layer or mainLayer, "fireball_blue.png")
end
function level_fx_explosion_from_list(x, y, width, height, layer, list)
  local hw = width / 2
  local hh = width / 2
  local fxlist = list or fxdef
  local locX = x + math.random(-hw, hw)
  local locY = y + math.random(-hh, hh)
  local fx = math.random(#fxlist)
  level_fx_explosion(locX, locY, 1, layer, fxlist[fx])
end
function level_fx_floatie(x, y, str, color, icon, font, t)
  local time = t or 2
  local f = hudLayer:add(ui.TextBox.new(str, font or FONT_MEDIUM, color or "ff0000", "center", nil, nil, true))
  f:setLoc(x, y)
  f:seekColor(1, 1, 1, 0, time, MOAIEaseType.EASE_OUT)
  levelAS:wrap(f:seekLoc(x, y + 70, time, MOAIEaseType.SOFT_EASE_IN), function()
    f:remove()
  end)
  if not icon then
    return
  end
  local ico = hudLayer:add(ui.Image.new(icon))
  local xMin, yMin, xMax, yMax = f:getStringBounds(1, string.len(str))
  local w = ico:getSize()
  local newX = x + xMax + w / 2
  local newY = y - (yMin + yMax) / 2
  ico:setLoc(newX, newY)
  ico:seekColor(0, 0, 0, 0, time, MOAIEaseType.EASE_OUT)
  levelAS:wrap(ico:seekLoc(newX, newY + 70, time, MOAIEaseType.SOFT_EASE_IN), function()
    ico:remove()
  end)
end
function level_fx_reloading_nav(x, y)
  local time = 0.15
  local icon = hudLayer:add(ui.Image.new("hud.atlas.png#cannonReticleX.png"))
  icon:setLoc(x, y)
  icon.spawnTime = levelAS:getTime()
  levelAS:wrap(icon:seekColor(0, 0, 0, 0, time, MOAIEaseType.EASE_OUT), function()
    icon:remove()
  end)
  level_fx_floatie(x, y, _("Reloading"), nil, nil, nil, time * 5)
end
function level_fx_warp(x, y, layer, fx, entity, callback)
  if not entity then
    return
  end
  local sclX, sclY = entity.sprite:getScl()
  entity.warping = true
  if entity.subentities then
    for k, v in pairs(entity.subentities) do
      v.warping = true
    end
  end
  local delay = 0
  local warpGate
  local travelDist = 150
  entity.sprite:setParent(nil)
  local ex, ey = entity:getLoc()
  local height = 100
  local edef = entity.def
  local dif
  if edef and edef.collisionRadius then
    height = edef.collisionRadius
  end
  entity:setLoc(x, y)
  entity.sprite:setLoc(ex, ey)
  entity.sprite:forceUpdate()
  levelAS:delaycall(delay, function()
    soundmanager.onSFX("onWarp")
    local trail
    levelAS:wrap(entity.sprite:seekLoc(x, y - (travelDist + height), 0.1, MOAIEaseType.LINEAR))
    levelAS:wrap(entity.sprite:seekScl(sclX, sclY * 2, 0.1, MOAIEaseType.EASE_IN), function()
      levelAS:wrap(entity.sprite:seekLoc(x, y - travelDist / 2, 0.125, MOAIEaseType.SOFT_EASE_IN))
      levelAS:wrap(entity.sprite:seekScl(sclX, sclY, 0.125, MOAIEaseType.SOFT_EASE_IN), function()
        levelAS:wrap(entity.sprite:seekLoc(x, y, 1, MOAIEaseType.SOFT_EASE_IN), function()
          entity.sprite:setParent(entity)
          entity.warping = false
          if entity.subentities then
            for k, v in pairs(entity.subentities) do
              v.warping = false
            end
          end
          if callback then
            callback(entity)
          end
        end)
      end)
    end)
  end)
end
local function _calc_camera_shake(t)
  local strength = 0
  for driver, v in pairs(camShakes) do
    local str = driver(t)
    if str == nil then
      camShakes[driver] = nil
    else
      strength = strength + str
    end
  end
  return strength
end
function level_fx_camera_shake(strength, duration)
  if strength == nil then
    strength = 50
  end
  if duration == nil then
    duration = 1
  end
  local startTime = levelAS:getTime()
  local pow = math.pow
  local function fn(t)
    local a = (t - startTime) / duration
    if a > 1 then
      return nil
    end
    return strength - strength * (-pow(2, -10 * a) + 1)
  end
  camShakes[fn] = true
end
local function _update_cannon_icons()
  for i, c in ipairs(cannons) do
    if c.cooldownIndicator then
      c.cooldownIndicator:remove()
      c.cooldownIndicator = nil
    end
  end
  cannons = {}
  level_foreach_object_of_type("cannon", _it_table_insert, cannons)
  local uiScl = device.ui_scale
  local deviceWidth = device.width * uiScl
  local deviceHeight = device.height * uiScl
  local x = -deviceWidth / 2
  local y = -deviceHeight / 2 + 50
  if not levelUI.blossomInactive then
    if blossomCharges > 0 then
      levelUI.cannonGroup:add(levelUI.blossomGroup)
      levelUI.blossomBtn:showPage("down")
      levelUI.blossomBtn:showPage("up")
      do
        local w, h = levelUI.blossomBtn._up:getSize()
        levelUI.blossomBtn:setLoc(x + w / 2 + 18, -deviceHeight / 2 + h / 2 + 18)
        x = x + w
      end
    else
      levelUI.blossomGroup:remove()
    end
  end
end
local function _find_cheapest_warp_item()
  levelCheapestWarpItem = 9999
  for i, def in pairs(entitydef) do
    if def.type == "capitalship" then
      local upgradeNum = def._upgradeNum
      local baseID = def._baseID
      if upgradeNum == 0 and def.storeTexture and not def.excludeWarpMenu and profile.unlocks[baseID] and profile.unlocks[baseID].unlocked then
        local curDef = entitydef[baseID .. "_" .. profile.unlocks[baseID].currentUpgrade]
        if curDef.buildCost.blue < levelCheapestWarpItem then
          levelCheapestWarpItem = curDef.buildCost.blue
        end
      end
    end
  end
end
function update_cannon_icons()
  _update_cannon_icons()
end
function level_cannon_hit_enemy()
  lastCannonHitWave = 0
  cannonHitEnemy = true
end
local function _calculate_scores(victory)
  scores.alloy = scores.alloy or 0
  scores.xp = scores.xp or 0
  scores.creds = scores.creds or 0
  scores.score = scores.score or 0
  scores.blue = scores.blue or 0
  enemies_destroyed.enemyf = enemies_destroyed.enemyf or 0
  enemies_destroyed.enemyb = enemies_destroyed.enemyb or 0
  enemies_destroyed.enemyc = enemies_destroyed.enemyc or 0
  enemies_destroyed.via_artillery = enemies_destroyed.via_artillery or 0
  enemies_destroyed.via_beam = enemies_destroyed.via_beam or 0
  local levelDef = GALAXY_DATA[levelGalaxySystemIndex]
  local profileLevelDef
  if gameMode ~= "survival" then
    profileLevelDef = profile.levels[levelGalaxyIndex][levelSystemIndex]
  end
  endGameStats = {}
  endGameStats.baseAlloy = profile.alloy
  endGameStats.baseCreds = profile.creds
  endGameStats.baseLevel = profile.level
  endGameStats.baseXP = profile.xp
  endGameStats.basePlusAlloy = scores.alloy
  endGameStats.basePlusXP = scores.xp
  endGameStats.baseStars = 0
  if profileLevelDef ~= nil and profileLevelDef.stars ~= nil then
    endGameStats.baseStars = profileLevelDef.stars
  end
  endGameStats.baseScore = scores.score
  if gameMode == "survival" then
    endGameStats.baseHighScore = profile.survivalHighScore
    endGameStats.baseLevelSurvivorWave = profile.levelSurvivorWave
    endGameStats.levelSurvivorWave = levelSurvivorWave
  end
  if gameMode ~= "survival" then
    endGameStats.baseKillsGalaxy = profile.levels[levelGalaxyIndex].kills
  end
  if not victory then
    if gameMode == "galaxy" then
      endGameStats.levelWave = levelWave
      do
        local maxWave = levelSpawns._waveCount or WAVE_COUNT
        endGameStats.levelSpawns = maxWave
      end
    elseif gameMode == "survival" then
      endGameStats.levelWave = levelSurvivorWave
    end
  end
  endGameStats.killsSystem = enemies_destroyed.enemyf + enemies_destroyed.enemyb + enemies_destroyed.enemyc
  if gameMode ~= "survival" then
    endGameStats.killsGalaxy = endGameStats.baseKillsGalaxy + endGameStats.killsSystem
  end
  if gameMode == "galaxy" then
    do
      local plusScoreCrystals = scores.blue
      endGameStats.plusScoreCrystals = plusScoreCrystals
      scores.score = math.floor(endGameStats.baseScore + plusScoreCrystals)
    end
  elseif gameMode == "survival" then
    local spentScoreCrystals = gameSessionAnalytics.currency.crystals.spent or 0
    endGameStats.spentScoreCrystals = spentScoreCrystals
    scores.score = math.floor(endGameStats.baseScore + math.floor(endGameStats.levelWave * SURVIVAL_MODE_SCORE_WAVE_MULTIPLIER) - spentScoreCrystals)
  end
  if victory then
    if scores.score < levelDef["2 Star Score"] then
      endGameStats.stars = 1
    elseif scores.score < levelDef["3 Star Score"] then
      endGameStats.stars = 2
    else
      endGameStats.stars = 3
    end
  end
  local victoryBonusAlloy = 0
  local victoryBonusXP = 0
  if victory then
    if profileLevelDef ~= nil and profileLevelDef.stars < endGameStats.stars then
      do
        local previousVictoryBonusAlloy = levelDef["Alloy " .. profileLevelDef.stars .. " Star"] or 0
        local levelDefStars = math.max(1, profileLevelDef.stars or 1)
        local previousVictoryBonusXP = endGameStats.basePlusXP * levelDef[levelDefStars .. " Star Bonus"] - endGameStats.basePlusXP
        local endGameStars = math.max(1, endGameStats.stars or 1)
        victoryBonusAlloy = floor(levelDef["Alloy " .. endGameStats.stars .. " Star"] - previousVictoryBonusAlloy)
        victoryBonusXP = floor(endGameStats.basePlusXP * levelDef[endGameStars .. " Star Bonus"] - endGameStats.basePlusXP - previousVictoryBonusXP)
      end
    elseif profileLevelDef == nil or profileLevelDef ~= nil and profileLevelDef.stars == nil then
      local endGameStars = math.max(1, endGameStats.stars)
      victoryBonusAlloy = floor(levelDef["Alloy " .. endGameStats.stars .. " Star"])
      victoryBonusXP = floor(endGameStats.basePlusXP * levelDef[endGameStars .. " Star Bonus"] - endGameStats.basePlusXP)
    end
    endGameStats.victoryBonusAlloy = victoryBonusAlloy
    endGameStats.victoryBonusXP = victoryBonusXP
  end
  local survivalBonusAlloy = 0
  if gameMode == "survival" then
    survivalBonusAlloy = scores.bonusAlloy or 0
    endGameStats.survivalBonusAlloy = survivalBonusAlloy
  end
  local perkBonusXP = 0
  if gameMode == "galaxy" and active_perks.plusXP then
    perkBonusXP = floor(endGameStats.basePlusXP * active_perks.plusXP.modifier)
    endGameStats.perkBonusXP = perkBonusXP
  end
  scores.alloy = scores.alloy + victoryBonusAlloy + survivalBonusAlloy
  scores.xp = scores.xp + victoryBonusXP + perkBonusXP
  endGameStats.plusAlloy = victoryBonusAlloy + survivalBonusAlloy
  endGameStats.plusXP = scores.xp + victoryBonusXP + perkBonusXP
  print("==================")
  print("Calculating Scores")
  print("Alloy: " .. scores.alloy)
  print("XP: " .. scores.xp)
  print("Creds: " .. scores.creds)
  print("Score: " .. scores.score)
  print("==================")
end
local function _update_achievements(victory)
  local defs = achievements.get_defs()
  for i, def in pairs(defs) do
    if def.systemLevelUnlock ~= nil and gameMode ~= "survival" and levelGalaxySystemIndex < def.systemLevelUnlock then
      achievements.checklist_fail(i)
    end
  end
  if victory then
    if achievements.checklist_get("warp_capship") then
      achievements.update("warp_capship", 1)
    end
    if achievements.checklist_get("nodamage") then
      achievements.update("nodamage", 1)
    end
    if achievements.checklist_get("warp_all") then
      achievements.update("warp_all", 1)
    end
    if achievements.checklist_get("warp_all_max") then
      achievements.update("warp_all_max", 1)
    end
    if achievements.checklist_get("turkey") then
      achievements.update("turkey", 1)
    else
      achievements.set("turkey", 0)
    end
    if achievements.checklist_get("turkey_noomega") then
      achievements.update("turkey_noomega", 1)
    else
      achievements.set("turkey_noomega", 0)
    end
    if achievements.checklist_get("turkey_plain") then
      achievements.update("turkey_plain", 1)
    else
      achievements.set("turkey_plain", 0)
    end
    if achievements.checklist_get("finished_g1") then
      achievements.update("finished_g1", 1)
    end
    if achievements.checklist_get("finished_g2") then
      achievements.update("finished_g2", 1)
    end
    if achievements.checklist_get("completionist_g1") then
      achievements.update("completionist_g1", 1)
    end
    if achievements.checklist_get("completionist_g2") then
      achievements.update("completionist_g2", 1)
    end
    if endGameStats.baseStars < endGameStats.stars then
      achievements.update("collect_60_stars", endGameStats.stars - endGameStats.baseStars)
      achievements.update("collect_120_stars", endGameStats.stars - endGameStats.baseStars)
      achievements.update("collect_240_stars", endGameStats.stars - endGameStats.baseStars)
    end
    if achievements.checklist_get("great_game") then
      achievements.update("great_game", 1)
    end
    if achievements.checklist_get("fast_forward") then
      achievements.update("fast_forward", 1)
    end
    if (achievements.checklist_get("marksman") or 0) >= 5 then
      achievements.update("marksman", 1)
    end
    if achievements.checklist_get("deaths_door") then
      achievements.update("deaths_door", 1)
    end
  else
    achievements.set("turkey", 0)
    achievements.set("turkey_noomega", 0)
    achievements.set("turkey_plain", 0)
  end
  if 0 < enemies_destroyed.enemyf then
    achievements.update("kill_300_fighters", enemies_destroyed.enemyf)
  end
  if 0 < enemies_destroyed.enemyb then
    achievements.update("kill_100_bombers", enemies_destroyed.enemyb)
  end
  if 0 < enemies_destroyed.enemyc then
    achievements.update("kill_100_constructs", enemies_destroyed.enemyc)
  end
  if 0 < enemies_destroyed.via_artillery then
    achievements.update("kill_100_via_artillery", enemies_destroyed.via_artillery)
  end
  if 0 < enemies_destroyed.via_beam then
    achievements.update("kill_50_via_beam", enemies_destroyed.via_beam)
  end
  if 0 < scores.alloy then
    achievements.update("collect_alloy_1", scores.alloy)
  end
  if 0 < scores.creds then
    achievements.update("collect_creds_1", scores.creds)
  end
  if gameMode == "survival" then
    if endGameStats.baseLevelSurvivorWave < endGameStats.levelSurvivorWave then
      achievements.set("survival_wave_1", endGameStats.levelSurvivorWave)
      achievements.set("survival_wave_2", endGameStats.levelSurvivorWave)
      achievements.set("survival_wave_3", endGameStats.levelSurvivorWave)
    end
    if achievements.checklist_get("survival_survive_1") then
      achievements.update("survival_survive_1", 1)
    end
    if achievements.checklist_get("survival_kill_1") then
      achievements.update("survival_kill_1", 1)
    end
  end
end
function clear_game(endReason)
  assert(type(endReason) == "string", "you must provide a reason the previous game is done")
  print("Clearing game")
  if gameMode ~= "survival" then
    gameSessionAnalytics.wave = levelWave
  else
    gameSessionAnalytics.wave = levelSurvivorWave
  end
  gameSessionAnalytics.duration = levelAS:getTime() - levelStartTime
  gameSessionAnalytics.result = endReason
  if gameMode ~= "survival" then
    gameSessionAnalytics.totalWaves = levelSpawns._waveCount or WAVE_COUNT
  end
  local flatGameSession = {}
  util.flatten_table(flatGameSession, gameSessionAnalytics)
  for i, v in pairs(flatGameSession) do
    print("Game session: " .. i, v)
  end
  if gameMode ~= "survival" then
    analytics.customEvent("GAME_SESSION", flatGameSession)
    analytics.customEvent(string.format("GAME_SESSION_G%d_S%d", curLevelGalaxyIndex, curLevelSystemIndex), flatGameSession)
    do
      local sessionString = string.format("GAMERESULT_SAMPLE_G%d_S%d", curLevelGalaxyIndex, curLevelSystemIndex)
      local sampleResult = _G[sessionString] or 0
      local sampleRoll = math.random()
      _debug(string.format("Rolling %f against %f", sampleRoll, sampleResult))
      if sampleResult > sampleRoll then
        cloud.postGameResult(gameSessionAnalytics)
      end
    end
  else
    analytics.customEvent(string.format("GAME_SESSION_SURVIVAL", curLevelGalaxyIndex, curLevelSystemIndex), flatGameSession)
    local sampleRoll = math.random()
    _debug(string.format("Rolling %f against %f", sampleRoll, GAMERESULT_SAMPLE_SURVIVAL or 0))
    if sampleRoll < (GAMERESULT_SAMPLE_SURVIVAL or 0) then
      cloud.postSurvivalGameResult(gameSessionAnalytics)
    end
    if endReason == "defeat" then
      if profile.survivalHighScore then
        if not (profile.survivalHighScore < (scores.score or 0)) and profile.survivalWHighScore then
        end
      elseif profile.survivalWHighScore < (scores.score or 0) then
        local score = scores.score or 0
        local deathBlossom = 0
        local omega13 = 0
        local wave = levelSurvivorWave
        local allTime = false
        if profile.survivalHighScore then
        elseif profile.survivalHighScore < (scores.score or 0) then
          allTime = true
        end
        if gameSessionAnalytics.specialAbilities then
          deathBlossom = gameSessionAnalytics.specialAbilities.deathblossom or 0
          omega13 = gameSessionAnalytics.specialAbilities.omega or 0
        end
        if allTime and (not profile.survivalHighScore or score > profile.survivalHighScore) then
          profile.survivalHighScore = score
          profile.survivalHighScoreWave = wave
          profile.survivalOmega13 = omega13
          profile.survivalDeathBlossom = deathBlossom
          profile:save()
        end
        if not profile.survivalWHighScore or score > profile.survivalWHighScore then
          profile.survivalWHighScore = score
          profile.survivalWHighScoreWave = wave
          profile.survivalWOmega13 = omega13
          profile.survivalWDeathBlossom = deathBlossom
          profile.survivalWTimeStamp = nil
          profile:save()
        end
        if allTime then
          PromptUserForHighScore(score, omega13, deathBlossom, wave)
        else
          PromptUserForHighScore(score, omega13, deathBlossom, wave, nil, "all")
        end
        if gamecenter.isLoggedIn() then
          gamecenter.reportScore(score, SIXWAVES_GC_LEADERBOARDS)
        end
      end
    end
  end
  levelDone = true
  level_foreach_object(Entity.destroy)
  commandShip = nil
  commandShipParts = nil
  levelOver = nil
  camShakes = {}
  deinitialize_level_ui()
  if levelGalaxySystemIndex == TUT_MIN_BLOSSOM_SYSTEM and endReason ~= "victory" and not profile.levels[curLevelGalaxyIndex][curLevelSystemIndex] and 0 < blossomUsed then
    profile.blossomGift = false
    profile:save()
  end
  if scores.creds and 0 < scores.creds then
    if gameMode == "galaxy" then
      set_if_nil(profile, "saucers", {})
      profile.saucers[levelGalaxySystemIndex] = true
      profile:save()
    else
      profile.survivalSaucer = os.date("%X")
      profile:save()
    end
  end
  popupsLayer:clear()
  uiAS:throttle(1)
  active_perks = {}
  if bucket.current() == "LEVEL" then
    bucket.pop()
  end
  bucket.release("LEVEL")
  bucket.release("POPUPS")
  memory.fullgc()
end
function end_game(victory)
  print("Ending game")
  _calculate_scores(victory)
  gameSessionAnalytics.score = {
    killValue = endGameStats.baseScore,
    endScore = endGameStats.score
  }
  gameSessionAnalytics.currency.crystals.remaining = scores.blue
  gameSessionAnalytics.currency.crystals.total = (gameSessionAnalytics.currency.crystals.remaining or 0) + (gameSessionAnalytics.currency.crystals.spent or 0)
  gameSessionAnalytics.currency.alloy.awarded = (endGameStats.victoryBonusAlloy or 0) + (endGameStats.perkBonusAlloy or 0)
  if gameMode == "survival" then
    gameSessionAnalytics.currency.alloy.bonus = endGameStats.survivalBonusAlloy or 0
  end
  gameSessionAnalytics.currency.alloy.total = (gameSessionAnalytics.currency.alloy.earned or 0) + (gameSessionAnalytics.currency.alloy.awarded or 0) + (gameSessionAnalytics.currency.alloy.bonus or 0) - (gameSessionAnalytics.currency.alloy.spent or 0)
  gameSessionAnalytics.currency.creds.total = (gameSessionAnalytics.currency.creds.earned or 0) + (gameSessionAnalytics.currency.creds.awarded or 0) - (gameSessionAnalytics.currency.creds.spent or 0)
  gameSessionAnalytics.currency.xp.earned = endGameStats.basePlusXP
  gameSessionAnalytics.currency.xp.awarded = (endGameStats.victoryBonusXP or 0) + (endGameStats.perkBonusXP or 0)
  gameSessionAnalytics.currency.xp.total = (gameSessionAnalytics.currency.xp.earned or 0) + (gameSessionAnalytics.currency.xp.awarded or 0)
  gameSessionAnalytics.currency.xp.preBalance = endGameStats.baseXP
  gameSessionAnalytics.currency.xp.postBalance = (gameSessionAnalytics.currency.xp.preBalance or 0) + (gameSessionAnalytics.currency.xp.total or 0)
  if gameMode == "galaxy" then
    profile.levels[levelGalaxyIndex].kills = endGameStats.killsGalaxy
  elseif gameMode == "survival" and (not profile.levelSurvivorWave or profile.levelSurvivorWave < levelSurvivorWave) then
    profile.levelSurvivorWave = levelSurvivorWave
  end
  local note
  if victory then
    note = "Victory"
  else
    note = "Defeat"
  end
  if gameMode ~= "survival" then
    note = string.format("%s: G%02d-S%02d", note, levelGalaxyIndex, levelSystemIndex)
  else
    note = string.format("%s: Survival Mode", note)
  end
  if victory and SixWaves and levelGalaxySystemIndex <= TUT_MIN_WARP_SYSTEM then
    local step
    if levelGalaxySystemIndex < TUT_MIN_WARP_SYSTEM then
      step = string.format("%d", levelGalaxySystemIndex)
    else
      step = "Complete"
    end
    SixWaves.trackTutorialEvent(step)
  end
  if lootPickupTimer[ALLOY_NAME] ~= nil then
    profile_currency_txn(ALLOY_NAME, lootPickupTimer[ALLOY_NAME].resValue, "Salvage", false)
    lootPickupTimer[ALLOY_NAME] = nil
  end
  if lootPickupTimer[CREDS_NAME] ~= nil then
    profile_currency_txn(CREDS_NAME, lootPickupTimer[CREDS_NAME].resValue, "Salvage", false)
    lootPickupTimer[CREDS_NAME] = nil
  end
  if endGameStats.victoryBonusAlloy then
    profile_currency_txn(ALLOY_NAME, endGameStats.victoryBonusAlloy, note, false)
  end
  if endGameStats.survivalBonusAlloy then
    profile_currency_txn(ALLOY_NAME, endGameStats.survivalBonusAlloy, note, false)
  end
  profile.xp = profile.xp + scores.xp
  local levelup = true
  while levelup do
    local xpDef = require("ShipData-ExpDef")
    local xpLevelDef = xpDef[profile.level]
    local xpToNextLevel
    if xpLevelDef ~= nil then
      xpToNextLevel = xpLevelDef.xpToAdvance
    end
    if xpToNextLevel ~= nil and xpToNextLevel ~= 0 then
      if xpToNextLevel and xpToNextLevel <= profile.xp then
        profile.level = profile.level + 1
        profile.xp = profile.xp - xpToNextLevel
        if xpLevelDef.bonusAlloy ~= 0 then
          profile_currency_txn(ALLOY_NAME, xpLevelDef.bonusAlloy, "Level Up Bonus " .. profile.level, false)
        end
      else
        levelup = false
      end
    else
      levelup = false
    end
  end
  if victory then
    set_if_nil(profile.levels[levelGalaxyIndex], levelSystemIndex, {})
    local profileLevelDef = profile.levels[levelGalaxyIndex][levelSystemIndex]
    if profileLevelDef.stars == nil then
      profileLevelDef.stars = 0
      achievements.checklist_check("finished_g" .. levelGalaxyIndex)
    end
    if profileLevelDef.stars < endGameStats.stars then
      profileLevelDef.stars = endGameStats.stars
      if endGameStats.stars == 3 then
        achievements.checklist_check("great_game")
        achievements.checklist_check("completionist_g" .. levelGalaxyIndex)
      end
    end
    gameSessionAnalytics.stars = endGameStats.stars
    levelSystemIndex = levelSystemIndex + 1
    if levelSystemIndex > 40 then
      set_if_nil(profile.levels, levelGalaxyIndex + 1, {})
      set_if_nil(profile.levels[levelGalaxyIndex + 1], "kills", 0)
      local nextGalaxyDef = GALAXY_DATA[levelGalaxyIndex * 40 + 1]
      if nextGalaxyDef ~= nil and nextGalaxyDef["Intencity / Wave"] ~= "" then
        levelGalaxyIndex = levelGalaxyIndex + 1
        levelSystemIndex = 1
      end
    end
  end
  _update_achievements(victory)
  profile:save()
  gameSessionAnalytics.currency.alloy.postBalance = profile.alloy
  gameSessionAnalytics.currency.creds.postBalance = profile.creds
  if victory then
    clear_game("victory")
  else
    clear_game("defeat")
  end
  if victory and levelGalaxySystemIndex >= RATE_APP_MIN_SYSTEM then
    RateAppCheck()
  end
  update.check()
end
function reset_game()
  print("Initializing level")
  gameSessionAnalytics = {}
  gameSessionAnalytics.profile = profile.profileId
  gameSessionAnalytics.data = update.debugStatus()
  gameSessionAnalytics.ABTest = gameSessionAnalytics.data:match("-(%a+)$")
  gameSessionAnalytics.galaxy = levelGalaxyIndex
  gameSessionAnalytics.system = levelSystemIndex
  gameSessionAnalytics.userlevel = profile.level
  gameSessionAnalytics.levelSeed = levelDef.Seed
  gameSessionAnalytics.levelIntensity = levelDef["3 Star Score"]
  set_if_nil(gameSessionAnalytics, "currency", {})
  set_if_nil(gameSessionAnalytics.currency, "crystals", {})
  set_if_nil(gameSessionAnalytics.currency, "alloy", {})
  set_if_nil(gameSessionAnalytics.currency, "creds", {})
  set_if_nil(gameSessionAnalytics.currency, "xp", {})
  gameSessionAnalytics.currency.alloy.preBalance = profile.alloy
  gameSessionAnalytics.currency.creds.preBalance = profile.creds
  achievements.checklist_reset()
  if #active_perks > 0 then
    gameSessionAnalytics.perks = {}
  end
  local new_perks = {}
  local perkdef = require("ShipData-Perks")
  for i, v in ipairs(active_perks) do
    new_perks[v] = util.table_copy(perkdef[v])
    new_perks[v].order = i
    gameSessionAnalytics.perks[i] = v
    gameSessionAnalytics[string.format("perks_%s", v)] = 1
  end
  active_perks = new_perks
  if device.os == device.OS_ANDROID then
    android_back_button_queue = {}
    android_pause_queue = {}
    MOAIApp.setListener(MOAIApp.BACK_BUTTON_PRESSED, nil)
    MOAIApp.setListener(MOAIApp.ON_PAUSE_CALLED, nil)
  end
  _entity_id = 0
  levelWave = 0
  levelStartTime = levelAS:getTime()
  enemies_destroyed = {}
  stage:setLoc(0, 0)
  resourceAccum = 0
  omegaUsed = 0
  blossomCharges = BLOSSOM_CHARGES
  blossomUsed = 0
  initialize_level_ui()
  camera:setLoc(0, 0)
  local radius = CAPITAL_SHIP_SPAWN_RADIUS or 220
  local posX, posY = math2d.cartesian(math.rad(60), radius)
  commandShip = level_spawn_object(string.format("SPC_%d", profile.unlocks.SPC.currentUpgrade), mothershipLayer, 0, -levelHeight * 1.2)
  level_spawn_object("spawning_module", mothershipLayer, radius, 0)
  level_spawn_object("spawning_module", mothershipLayer, -radius, 0)
  level_spawn_object("spawning_module", mothershipLayer, posX, posY)
  level_spawn_object("spawning_module", mothershipLayer, -posX, posY)
  level_spawn_object("spawning_module", mothershipLayer, posX, -posY)
  level_spawn_object("spawning_module", mothershipLayer, -posX, -posY)
  level_fx_warp(0, 0, mothershipLayer, true, commandShip, nil)
  if active_perks.regenShip then
    commandShip.regenPerSecond = 1 / active_perks.regenShip.modifier
    commandShip.tickfn = behavior.spc_regen
  end
  maxDC = 0
  scores = {
    blue = 0,
    alloy = 0,
    xp = 0,
    creds = 0
  }
  level_foreach_object_of_type("capitalship", _accumulate_max_dc, true)
  if gameMode == "galaxy" then
    if profile.saucers and profile.saucers[levelGalaxySystemIndex] then
      spawnSaucer = false
    else
      spawnSaucer = true
    end
  elseif gameMode == "survival" then
    if SURVIVAL_MODE_DAILY_SAUCERS == nil or SURVIVAL_MODE_DAILY_SAUCERS ~= nil and SURVIVAL_MODE_DAILY_SAUCERS == 0 then
      spawnSaucer = true
    elseif 0 < SURVIVAL_MODE_DAILY_SAUCERS then
      if profile.survivalSaucer ~= nil then
        do
          local hour, minute, second = profile.survivalSaucer:match("^(%d+):(%d+):(%d+)$")
          local prevtime = tonumber(hour) * 60 * 60 + tonumber(minute) * 60 + tonumber(second)
          hour, minute, second = os.date("%X"):match("^(%d+):(%d+):(%d+)$")
          local nowtime = tonumber(hour) * 60 * 60 + tonumber(minute) * 60 + tonumber(second)
          local dailyHours = SURVIVAL_MODE_DAILY_SAUCERS * 60 * 60
          if dailyHours <= nowtime - prevtime then
            spawnSaucer = true
          else
            spawnSaucer = false
          end
        end
      else
        spawnSaucer = true
      end
    end
    cloud.fetchWeeklyBoardTime()
  end
  if gameMode == "galaxy" then
    levelSpawns = spawn.genWaveDefs(levelGalaxyIndex, levelSystemIndex, levelDef)
  else
    survivalSpawnList = {}
    curLevelGalaxyStrength = 10
    levelGalaxyStrength = spawn.genSurvivalDefSet(survivalSpawnList, 10, true)
    levelSurvivorWave = 0
    levelSurvivorArc = 1
    levelSpawns = survivalSpawnList[1]
    DEBUG_SURVIVAL_ARC = levelSpawns._arc
  end
  spawnWidth = math.max(stageWidth * 0.5 + levelWidth * 0.5, levelWidth) + DEFAULT_LOC_VARIANCE
  spawnHeight = math.max(stageHeight * 0.5 + levelHeight * 0.5, levelHeight) + DEFAULT_LOC_VARIANCE
  ll = -spawnWidth * oobmult
  rr = spawnWidth * oobmult
  bb = -spawnHeight * oobmult
  tt = spawnHeight * oobmult
  spawnWidth = spawnWidth - DEFAULT_LOC_VARIANCE
  spawnHeight = spawnHeight - DEFAULT_LOC_VARIANCE
  offl = -spawnWidth * indmult
  offr = spawnWidth * indmult
  offb = -spawnHeight * indmult
  offt = spawnHeight * indmult
  if DEBUG_CONSTRUCTION_SPAWN then
    local theta = math.rad(30)
    local vr = 150
    local randPoint = math2d.randomPointInCircle
    for i = 0, 2 do
      local x, y = randPoint(sin(theta) * levelWidth * 1.2, cos(theta) * levelWidth * 1.2, vr)
      local o = level_spawn_object("Alien_Con_Catapult", nil, x, y)
    end
  end
  if levelGalaxySystemIndex == TUT_INTRO_SYSTEM then
    introShipList = util.strsplit(",", TUT_INTRO_SHIPS)
  else
    introShipList = nil
  end
  randutil.randomseed(randutil.seed_timelo(), 3)
  if gameMode ~= "survival" then
    spawn.spawnAsteroids(levelSpawns._asteroids)
  end
  if resetting then
    resetting:remove()
    resetting = nil
    levelUI.pauseScreen:remove()
    levelUI.resetting = false
  end
  lastCannonHitWave = 0
  cannonHitEnemy = false
  _update_cannon_icons()
  start_levelstart_ui()
  local preload = ui.NinePatch.new("glassyBoxWithHeader9p.lua")
  preload = nil
  lootPickupTimer = {}
  levelOver = nil
  levelDone = nil
end
function level_update_max_dc()
  maxDC = 0
  level_foreach_object_of_type("capitalship", _accumulate_max_dc)
  if scores.blue and scores.blue > maxDC then
    scores.blue = maxDC
  end
end
function level_closest_object_of_type(_type, x, y, maxDist)
  local closest = {dist = maxDist}
  level_foreach_object_of_type(_type, _closest_object, x, y, closest)
  return closest.target, closest.dist
end
local function _spawn_lifetime_blink(self, dt, t)
  local expireTime = self.spawnExpirationTime
  if expireTime == nil then
    return
  end
  local timeLeft = expireTime - t
  local blinkTime = self.def.spawnLifetime / 2
  if timeLeft > blinkTime then
    return
  end
  local blinkms
  if floor(t * 1000) % 4 == 0 then
    self.sprite:setColor(0, 0, 0, 0)
  else
    self.sprite:setColor(1, 1, 1, 1)
  end
end
function level_foreach_object_of_type_in_circle(_type, x, y, r, fn, ...)
  if listHead == nil then
    return false
  end
  local tt = type(_type)
  if tt == "table" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        if _type[i.def.type] then
          local _x, _y = i:getLoc()
          local _r = i.collisionRadius
          if distance(x, y, _x, _y) <= r + _r then
            local bail, value = fn(i, ...)
            if bail then
              return true, value
            end
          end
        end
        i = next
      end
    end
  elseif tt == "function" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        if _type(i.def.type) then
          local _x, _y = i:getLoc()
          local _r = i.collisionRadius
          if distance(x, y, _x, _y) <= r + _r then
            local bail, value = fn(i, ...)
            if bail then
              return true, value
            end
          end
        end
        i = next
      end
    end
  elseif tt == "string" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        if _type == i.def.type then
          local _x, _y = i:getLoc()
          local _r = i.collisionRadius
          if distance(x, y, _x, _y) <= r + _r then
            local bail, value = fn(i, ...)
            if bail then
              return true, value
            end
          end
        end
        i = next
      end
    end
  elseif tt == "nil" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        local _x, _y = i:getLoc()
        local _r = i.collisionRadius
        if distance(x, y, _x, _y) <= r + _r then
          local bail, value = fn(i, ...)
          if bail then
            return true, value
          end
        end
        i = next
      end
    end
  else
    assert(false, "Invalid type discriminator: " .. tostring(tt))
  end
  return nil
end
function level_foreach_object_of_type_in_capsule(_type, x0, y0, x1, y1, r, fn, ...)
  if listHead == nil then
    return false
  end
  local tt = type(_type)
  r = r ^ 2
  if tt == "table" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        if _type[i.def.type] then
          local _x, _y = i:getLoc()
          local _r = i.collisionRadius ^ 2
          if ptSegDistSq(_x, _y, x0, y0, x1, y1) <= r + _r then
            local bail, value = fn(i, ...)
            if bail then
              return true, value
            end
          end
        end
        i = next
      end
    end
  elseif tt == "function" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        if _type(i.def.type) then
          local _x, _y = i:getLoc()
          local _r = i.collisionRadius ^ 2
          if ptSegDistSq(_x, _y, x0, y0, x1, y1) <= r + _r then
            local bail, value = fn(i, ...)
            if bail then
              return true, value
            end
          end
        end
        i = next
      end
    end
  elseif tt == "string" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        if _type == i.def.type then
          local _x, _y = i:getLoc()
          local _r = i.collisionRadius ^ 2
          if ptSegDistSq(_x, _y, x0, y0, x1, y1) <= r + _r then
            local bail, value = fn(i, ...)
            if bail then
              return true, value
            end
          end
        end
        i = next
      end
    end
  elseif tt == "nil" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        local _x, _y = i:getLoc()
        local _r = i.collisionRadius
        if ptSegDistSq(_x, _y, x0, y0, x1, y1) <= r + _r then
          local bail, value = fn(i, ...)
          if bail then
            return true, value
          end
        end
        i = next
      end
    end
  else
    assert(false, "Invalid type discriminator: " .. tostring(tt))
  end
  return nil
end
function level_foreach_object_of_type(_type, fn, ...)
  if listHead == nil then
    return false
  end
  local tt = type(_type)
  if tt == "table" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        if _type[i.def.type] then
          local bail, value = fn(i, ...)
          if bail then
            return true, value
          end
        end
        i = next
      end
    end
  elseif tt == "function" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        if _type(i.def.type) then
          local bail, value = fn(i, ...)
          if bail then
            return true, value
          end
        end
        i = next
      end
    end
  elseif tt == "string" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        if i.def.type == _type then
          local bail, value = fn(i, ...)
          if bail then
            return true, value
          end
        end
        i = next
      end
    end
  elseif tt == "nil" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        local bail, value = fn(i, ...)
        if bail then
          return true, value
        end
        i = next
      end
    end
  else
    assert(false, "Invalid type discriminator: " .. tostring(tt))
  end
  return nil
end
function level_foreach_object(fn, ...)
  return level_foreach_object_of_type(nil, fn, ...)
end
function level_count_objects_of_type(_type)
  if listHead == nil then
    return 0
  end
  local tt = type(_type)
  local count = 0
  if tt == "table" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        if _type[i.def.type] then
          count = count + 1
        end
        i = next
      end
    end
  elseif tt == "function" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        if _type(i.def.type) then
          count = count + 1
        end
        i = next
      end
    end
  elseif tt == "string" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        if i.def.type == _type then
          count = count + 1
        end
        i = next
      end
    end
  elseif tt == "nil" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        count = count + 1
        i = next
      end
    end
  else
    assert(false, "Invalid type discriminator: " .. tostring(tt))
  end
  return count
end
function level_foreach_object_of_entityid(id, fn, ...)
  if listHead == nil then
    return false
  end
  local tt = type(id)
  if tt == "string" then
    local i = listHead._next
    while i do
      local next = i._next
      if i.def._id == id then
        local bail, value = fn(i, ...)
        if bail then
          return true, value
        end
      end
      i = next
    end
  end
  return nil
end
function level_count_objects_of_entityid(id)
  if listHead == nil then
    return 0
  end
  local tt = type(id)
  local count = 0
  if tt == "table" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        if id[i.def._id] then
          count = count + 1
        end
        i = next
      end
    end
  elseif tt == "function" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        if id(i.def._id) then
          count = count + 1
        end
        i = next
      end
    end
  elseif tt == "string" then
    do
      local i = listHead._next
      while i do
        local next = i._next
        if i.def._id == id then
          count = count + 1
        end
        i = next
      end
    end
  else
    assert(false, "Invalid type discriminator: " .. tostring(tt))
  end
  return count
end
function level_clear()
  if levelDef == nil then
    return
  end
  levelAS:stop()
  levelAS:clear()
  camShakes = {}
  mainLayer:clear()
  mothershipLayer:clear()
  uiLayer:clear()
  listHead = nil
  levelDef = nil
end
local ll_remove = function(self)
  if self._prev then
    self._prev._next = self._next
  end
  if self._next then
    self._next._prev = self._prev
  end
end
local ll_add = function(self, o)
  if self._next then
    self._next._prev = o
  end
  o._prev = self
  o._next = self._next
  self._next = o
end
local entityMgr = {
  getTime = function(self)
    return levelAS:getTime()
  end,
  _nextEntityId = function(self)
    _entity_id = _entity_id + 1
    return _entity_id
  end,
  _addEntityToIndex = function(self, e)
    ll_add(listHead, e)
    if e.def.type == "cannon" then
      _update_cannon_icons()
    end
    levelSpace:insertPrim(e)
  end,
  _removeEntityFromIndex = function(self, e, fx)
    ll_remove(e)
    if e.def.type == "cannon" then
      _update_cannon_icons()
    elseif e.def.type == "module" and e.def.hangarInventoryType ~= nil then
      level_foreach_object(function(obj)
        if obj.launchBay == e then
          obj:destroy(fx)
        end
      end)
    end
    e:setRemoveFlag(MOAICpBody.REMOVE_BODY_AND_SHAPES)
  end
}
function level_spawn_object(idOrDef, layer, x, y, stopAssets)
  local def
  if type(idOrDef) == "string" then
    def = entitydef[idOrDef]
  elseif type(idOrDef) == "table" then
    def = idOrDef
  else
    print(debug.traceback())
    error("Invalid object ID or Def: " .. tostring(idOrDef))
  end
  assert(def ~= nil and def._id ~= nil, "invalid entity type: " .. tostring(idOrDef))
  local ship = Entity.new(entityMgr, def)
  layer = layer or mainLayer
  layer:add(ship.sprite)
  ship.sprite:setParent(ship)
  if not stopAssets then
    gfxutil.playAssets(ship.sprite)
  end
  if x ~= nil and y ~= nil then
    ship:setLoc(x, y)
  end
  if ship.nitro then
    levelAS:delaycall(0.1, function()
      ship.nitro:updateSystem()
      ship.nitro:begin()
    end)
  end
  return ship
end
local _it_first_ready_cannon = function(obj, t, kind)
  if t >= (obj.nextCannonFireTime or 0) and (kind == nil or kind == obj.def.cannonType) then
    return true, obj
  end
end
function level_fire_cannon_at(x, y, kind)
  local t = levelAS:getTime()
  set_if_nil(gameSessionAnalytics, "cannonsFired", {})
  if levelUI.blossomActive then
    return false
  end
  local found, cannon = level_foreach_object_of_type("cannon", _it_first_ready_cannon, t, kind)
  if not found then
    if #cannons <= 0 then
      return false
    end
    level_fx_reloading_nav(x, y)
    soundmanager:onUnavailable()
    gameSessionAnalytics.cannonsReloading = (gameSessionAnalytics.cannonsReloading or 0) + 1
    return false
  end
  cannon.nextCannonFireTime = t + cannon.def.cannonCooldown
  local o = level_spawn_object(cannon.def.cannonProjectileType)
  local _x, _y
  _x, _y = cannon:getWorldLoc()
  o:setNavPoint(x, y)
  o.cannon = cannon
  o:loopAnim()
  cannon.turret:setRot(deg(atan2(y - _y, x - _x)) - 90)
  if cannon.def.weaponLoc then
    cannon.turret:forceUpdate()
    _x, _y = cannon.turret:modelToWorld(unpack(cannon.def.weaponLoc))
  end
  local muzzleFlash = cannon.muzzleFlash
  if muzzleFlash then
    cannon.turret:add(muzzleFlash)
    muzzleFlash:playAssets()
  end
  soundmanager.onArtilleryFire()
  o:setLoc(_x, _y)
  levelAS:delaycall(cannon.def.cannonCooldown / 4, function()
    if cannon and cannon.turret then
      local curRot = cannon.turret:getRot()
      local tarRot = 0
      if curRot < -180 then
        tarRot = -360
      end
      levelAS:wrap(cannon.turret:seekRot(tarRot, cannon.def.cannonCooldown / 4, MOAIEaseType.EASE_IN))
    end
  end)
  achievements.checklist_fail("turkey")
  achievements.checklist_fail("turkey_noomega")
  achievements.checklist_fail("turkey_plain")
  set_if_nil(gameSessionAnalytics.cannonsFired, cannon.def.cannonProjectileType, {})
  gameSessionAnalytics.cannonsFired[cannon.def.cannonProjectileType].fire = (gameSessionAnalytics.cannonsFired[cannon.def.cannonProjectileType].fire or 0) + 1
  return true
end
lootPickupTimer = {}
function level_spawn_loot_at(dropTable, modifier, x, y, r)
  if dropTable == nil or modifier == 0 or gameMode ~= "survival" and levelGalaxySystemIndex < TUT_MIN_LOOT_DROP_SYSTEM then
    return
  end
  r = r or 0
  if type(dropTable) == "table" then
    for ttype, count in pairs(dropTable) do
      local nCount = math.floor((modifier or 1) * count)
      for i = 1, nCount do
        local nType = ttype
        local o = level_spawn_object(nType)
        local _x, _y = math2d.randomPointInCircle(x, y, r)
        o:setLoc(_x, _y)
        o.sprite:forceUpdate()
      end
    end
  else
    local o = level_spawn_object(dropTable)
    local _x, _y = math2d.randomPointInCircle(x, y, r)
    o:setLoc(_x, _y)
    o.sprite:forceUpdate()
  end
end
local function _level_tick(dt)
  local camScl = camera:getScl()
  local sw = stageWidth * camScl
  local sh = stageHeight * camScl
  local uiBarHeight
  if gameMode == "galaxy" then
    uiBarHeight = UI_BAR_HEIGHT
  elseif gameMode == "survival" then
    uiBarHeight = UI_BAR_HEIGHT_SURVIVAL
  end
  local l = -sw / 2
  local r = sw / 2
  local b = -sh / 2
  local t = sh / 2 - (uiBarHeight - 25)
  local ttime = levelAS:getTime()
  if levelDone then
    return
  end
  if dt > 0 then
    local camShakeStrength = _calc_camera_shake(ttime)
    camera:addLoc(-camShakeX, -camShakeY)
    camShakeX = (math.random() - 0.5) * camShakeStrength
    camShakeY = (math.random() - 0.5) * camShakeStrength
    camera:addLoc(camShakeX, camShakeY)
  end
  if activePathCapturer ~= nil then
    local dx, dy = camScrollX * dt, camScrollY * dt
    local cx, cy = camera:getLoc()
    camera:setLoc(clampToLevelBounds(cx + dx, cy + dy))
    activePathCapturer:pathCaptureInject(dx, dy)
  end
  if commandShip and 0 < commandShip.hp then
    resourceAccum = resourceAccum + dt * RESOURCE_GENERATION_RATE
    if resourceAccum > 1 then
      if (scores.blue or 0) < maxDC then
        local count = math.floor(resourceAccum)
        scores.blue = (scores.blue or 0) + count
        resourceAccum = resourceAccum - count
      end
    end
    if levelUI ~= nil then
      if levelUI.resourceText ~= nil then
        local warpRes = scores.blue or 0
        local text = util.commasInNumbers(warpRes) .. " <c:7fc3de>/ " .. util.commasInNumbers(maxDC)
        levelUI.resourceText:setString(text)
        local strLen = "" .. maxDC:len()
        local width
        if strLen >= 4 then
          width = 140
        elseif strLen == 3 then
          width = 115
        else
          width = 90
        end
        local barStartPos = device.ui_height / 2 - uiBarHeight / 2
        levelUI.resourceAreaBox:setSize(64 + width, uiBarHeight)
        levelUI.resourceAreaBox:setLoc(-device.ui_width / 2 + (64 + width) / 2, barStartPos)
        local x, y = levelUI.resourceAreaBox:getLoc()
        levelUI.alloyIcon:setLoc(x + (64 + width) / 2 + 32, barStartPos + 26)
        local x, y = levelUI.alloyIcon:getLoc()
        levelUI.alloyText:setLoc(x + 26 + 45, barStartPos + 24)
        local x, y = levelUI.alloyText:getLoc()
        levelUI.credsIcon:setLoc(x + width / 2 + 16, barStartPos + 26)
        local x, y = levelUI.credsIcon:getLoc()
        levelUI.credsText:setLoc(x + 26 + 45, barStartPos + 24)
      end
      if levelUI.alloyText ~= nil then
        local text = util.commasInNumbers(profile.alloy)
        levelUI.alloyText:setString(text)
        local xmin, ymin, xmax, ymax = levelUI.alloyText:getStringBounds(1, text:len())
        local width = util.roundNumber(xmax - xmin)
        local barStartPos = device.ui_height / 2 - uiBarHeight / 2
        local x, y = levelUI.alloyText:getLoc()
        levelUI.credsIcon:setLoc(x + width / 2 + 16, barStartPos + 26)
        local x, y = levelUI.credsIcon:getLoc()
        levelUI.credsText:setLoc(x + 26 + 45, barStartPos + 24)
      end
      if levelUI.credsText ~= nil then
        local text = util.commasInNumbers(profile.creds)
        levelUI.credsText:setString(text)
      end
      if gameMode == "survival" then
        set_if_nil(gameSessionAnalytics, "currency", {})
        set_if_nil(gameSessionAnalytics.currency, "crystals", {})
        local spentScoreCrystals = gameSessionAnalytics.currency.crystals.spent or 0
        local score = math.floor((scores.score or 0) + math.floor(levelSurvivorWave * SURVIVAL_MODE_SCORE_WAVE_MULTIPLIER) - spentScoreCrystals)
        if levelUI.scoreText ~= nil then
          local text = string.format(_("<c:a6a6a6>SCORE <c:ffffff>%s"), util.commasInNumbers(score))
          levelUI.scoreText:setString(text)
        end
        if levelUI.highScoreText ~= nil then
          local num = profile.survivalHighScore
          if score > num then
            num = score
          end
          local text = string.format(_("<c:a6a6a6>HIGH SCORE <c:ffffff>%s"), util.commasInNumbers(num))
          levelUI.highScoreText:setString(text)
        end
      end
    end
  elseif not resetting then
    resetting = true
    start_defeated_ui()
  end
  local prof
  if level_profiling_flag then
    local profiler = require("profiler")
    prof = profiler.new("call")
    prof:start()
    level_profiling_flag = false
  end
  local i = listHead._next
  while i do
    local next = i._next
    local expireTime = i.spawnExpirationTime
    if expireTime ~= nil then
      if ttime >= expireTime then
        i:destroy(i.def.deathfx)
      else
        if not i.def.noBlink then
          _spawn_lifetime_blink(i, dt, ttime)
        end
        local tickfn = i.tickfn
        if tickfn ~= nil then
          tickfn(i, dt, ttime)
        end
      end
    else
      local tickfn = i.tickfn
      if tickfn ~= nil then
        tickfn(i, dt, ttime)
      end
    end
    i = next
  end
  local indicatorMargin = 16
  local min = math.min
  local max = math.max
  local cx, cy = camera:getLoc()
  i = listHead._next
  while i do
    local next = i._next
    local x, y = i:getLoc()
    local ox, oy = x, y
    x = x - cx
    y = y - cy
    if not DEBUG_HIDE_HUD and not levelUI.inStoreMenu and (l > x or r < x or b > y or t < y) then
      if x < ll or x > rr or y < bb or y > tt then
        i:destroy()
      elseif x < offl or x > offr or y < offb or y > offt then
        do
          local ind = i.offscreenIndicator
          if ind ~= nil then
            i:clearOffscreenIndicator()
          end
        end
      else
        local indicatorTex = i.def.offscreenIndicatorTexture
        if indicatorTex ~= nil then
          local ind = i:affirmOffscreenIndicator()
          local rot = 0
          if l > x then
            x = l + ind.w
            rot = 90
          elseif r < x then
            x = r - ind.w
            rot = -90
          end
          if b > y then
            y = b + ind.h
            rot = 180
          elseif t < y then
            y = t - ind.h
          end
          if not i.def.offscreenIndicatorNoRot then
            ind:setRot(rot)
          end
          if ox < -spawnWidth or ox > spawnWidth or oy < -spawnHeight or oy > spawnHeight then
            if ind.offscreenIndicatorColor ~= 0 then
              ind:setColor(unpack(UI_OFFSCREEN_OFF_COLOR))
              ind.offscreenIndicatorColor = 0
            end
          elseif ind.offscreenIndicatorColor ~= 1 then
            ind:setColor(unpack(i.def.offscreenIndicatorColor or UI_FILL_RED_COLOR))
            ind.offscreenIndicatorColor = 1
          end
          local pulseRate = i.def.offscreenIndicatorPulseRate
          if pulseRate ~= nil then
            local s = sin((levelAS:getTime() - i.spawnTime) * 8) * 0.08 + 1
            ind:setScl(s, s)
          end
          ind:setLoc(x, y)
        end
      end
    else
      local ind = i.offscreenIndicator
      if ind ~= nil then
        i:clearOffscreenIndicator()
      end
    end
    if i.hp ~= nil and not i.def.hpHidden then
      i.sprite.hpBarContainer:setLoc(i:getPos())
    end
    i = next
  end
  if prof then
    prof:stop()
    prof:report(io.stdout)
  end
end
local function _capship_warpout(obj, t, skip)
  if obj == commandShip and skip then
    return
  else
    levelAS:delaycall(t[1] + 1, obj.warpOut, obj)
  end
  levelAS:delaycall(t[1], obj.startAfterBurner, obj)
  t[1] = t[1] + 0.25 + math.random() * 0.75
end
function survival_next_iteration()
  levelSurvivorArc = levelSurvivorArc + 1
  table.remove(survivalSpawnList, 1)
  if #survivalSpawnList == 0 then
    levelGalaxyStrength = spawn.genSurvivalDefSet(survivalSpawnList, levelGalaxyStrength)
  end
  levelSpawns = survivalSpawnList[1]
  curLevelGalaxyStrength = levelSpawns._galStrength
  DEBUG_SURVIVAL_ARC = levelSpawns._arc
  levelWave = 0
  DEBUG_SURVIVAL_WAVE = levelWave
  wave = 0
  levelStartTime = levelAS:getTime()
  maxWave = levelSpawns._waveCount or WAVE_COUNT
end
local function _spawn_baddies()
  local enemyCount = level_count_objects_of_type(ALL_ENEMY_TARGET_TYPES)
  local waveTime = WAVE_TIME
  local w = (levelAS:getTime() - levelStartTime) / waveTime + 1
  local BOMBER_WAVE = 8
  local ARTILLERY_WAVE = 12
  maxWave = levelSpawns._waveCount or WAVE_COUNT
  wave = math.floor(w)
  if gameMode == "galaxy" then
    if resetting then
    elseif wave < maxWave then
      levelUI.waveText:setString(string.format("%d/%d", wave, maxWave))
    elseif enemyCount > 0 then
      if not levelUI.finalWave then
        levelUI.finalWave = true
        if levelGalaxySystemIndex == TUT_INTRO_SYSTEM then
          do
            local levelDef = GALAXY_DATA[levelGalaxySystemIndex]
            scores.score = levelDef["3 Star Score"]
            enemyCount = 0
            levelOver = true
          end
        else
          start_finalwave_ui()
        end
      end
      do
        local curTime = waveTime - waveTime * (w - wave)
        levelUI.waveText:setString(string.format(_("%d Left"), enemyCount))
      end
    else
      levelUI.waveText:setString(_("WARPING!"))
    end
  elseif gameMode == "survival" then
    local uiBarHeight
    if gameMode == "galaxy" then
      uiBarHeight = UI_BAR_HEIGHT
    elseif gameMode == "survival" then
      uiBarHeight = UI_BAR_HEIGHT_SURVIVAL
    end
    local barStartPos = device.ui_height / 2 - uiBarHeight / 2
    local text = string.format(_("<c:a6a6a6>WAVE <c:ffffff>%d"), levelSurvivorWave)
    levelUI.waveText:setString(text)
    local xmin, ymin, xmax, ymax = levelUI.waveText:getStringBounds(1, text:len())
    local width = xmax - xmin
    levelUI.scoreText:setLoc(width + 24, barStartPos - 20)
  end
  if wave > levelWave then
    local tempWave = levelWave
    levelWave = wave
    if gameMode == "survival" then
      levelSurvivorWave = levelSurvivorWave + 1
      DEBUG_SURVIVAL_WAVE = levelWave
      if wave > maxWave then
        survival_next_iteration()
      end
    end
    if gameMode == "galaxy" then
      _fillbar_seek_fill(uiAS, levelUI.progressFill, 0, math.min(1, tempWave / maxWave), 0, math.min(1, wave / maxWave), 0.75, false)
    end
    if wave <= maxWave then
      spawn.spawnWave(levelSpawns, levelWave)
      spawn.spawnSurvivor(levelSpawns._survivors, levelWave)
      if spawnSaucer then
        spawn.spawnSaucer(levelSpawns._saucers, levelWave)
      end
      if gameMode == "survival" then
        spawn.spawnSurvivalModeAsteroid(levelSpawns._asteroids, levelWave)
      end
    end
    popups.show("on_g" .. levelGalaxyIndex .. "_s" .. levelSystemIndex .. "_w" .. levelWave)
    if gameMode == "galaxy" then
      if levelGalaxySystemIndex <= (TUT_MIN_ANALYTICS_SYSTEM or 0) then
        if levelWave <= (levelSpawns._waveCount or WAVE_COUNT) then
          if device.os == device.OS_ANDROID then
            analytics.customEvent(string.format("G%d_S%d_W%d_PASS", levelGalaxyIndex, levelSystemIndex, levelWave), nil)
          else
            analytics.customEvent(string.format("G%d_S%d_W%d_PASS", levelGalaxyIndex, levelSystemIndex, levelWave), {
              totalWaves = levelSpawns._waveCount or WAVE_COUNT,
              userlevel = profile.level
            })
          end
        end
      end
    end
    if levelGalaxySystemIndex == TUT_INTRO_SYSTEM then
      if levelWave == TUT_INTRO_UNKILLABLE_WAVE then
        commandShip.unkillable = true
      end
      if levelWave == TUT_INTRO_WARP_WAVE then
        local waitTimes = {}
        waitTimes[1] = 0.2
        for i = 2, 6 do
          waitTimes[i] = waitTimes[i - 1] + 0.25 + math.random() * 0.75
        end
        local count = 1
        for k, v in pairs(introShipList) do
          do
            local waitTime = waitTimes[count]
            count = count + 1
            local dam = TUT_INTRO_SHIP_DAM or 0.5
            levelAS:delaycall(waitTime, function()
              local result, module = level_foreach_object_of_type("warp_module", function(self)
                if not self.inventoryCount or self.inventoryCount == 0 then
                  return true, self
                end
              end)
              if module then
                module.warpDamage = dam
                module.warpType = v
                module:addInventoryCount(1)
              end
            end)
          end
        end
      end
      if levelWave >= TUT_INTRO_NOXP_WAVE then
        level_foreach_object_of_type(ALL_ENEMY_TARGET_TYPES, function(self)
          if self.def.scoreValue ~= nil then
            self.noXP = true
          end
        end)
      end
    elseif levelGalaxySystemIndex == TUT_MIN_BLOSSOM_SYSTEM and levelWave == TUT_MIN_BLOSSOM_WAVE then
      ui_toggle_blossom_button(true)
      levelUI.blossomInactive = false
      popups.show("on_blossom_ready")
      if not profile.blossomGift then
        profile.blossomGift = true
        profile:save()
        profile_currency_txn(BLOSSOM_RESOURCE_TYPE, BLOSSOM_COST, string.format("Tutorial: deathblossom"), true)
      end
    end
    if cannons and #cannons > 0 and not cannonHitEnemy then
      lastCannonHitWave = lastCannonHitWave + 1
      if lastCannonHitWave >= 3 then
        popups.show("on_no_artillery_hits")
      end
    end
    if levelWave == #levelSpawns then
      levelUI.progressFill:setFill(0, 1)
    elseif levelWave > maxWave and commandShip ~= nil and 0 < commandShip.hp then
      levelOver = true
    end
    if wave == 2 and not levelUI.ffing then
      achievements.checklist_fail("fast_forward")
    end
    if gameMode == "survival" then
      set_if_nil(gameSessionAnalytics, "currency", {})
      set_if_nil(gameSessionAnalytics.currency, "crystals", {})
      local spentScoreCrystals = gameSessionAnalytics.currency.crystals.spent or 0
      if levelSurvivorWave == ACHIEVEMENTS_SURVIVAL_SURVIVE_1_WAVE and spentScoreCrystals < ACHIEVEMENTS_SURVIVAL_SURVIVE_1_SPENT then
        achievements.checklist_check("survival_survive_1")
      end
    end
  end
  if levelOver and not levelOverText and enemyCount == 0 then
    levelOver = nil
    popups.show("on_g" .. levelGalaxyIndex .. "_s" .. levelSystemIndex .. "_victory")
    soundmanager.onSFX("onVictory")
    commandShip.unkillable = true
    levelAS:delaycall(0.05, function()
      local winString = _("System Complete!")
      if levelGalaxySystemIndex == TUT_INTRO_SYSTEM then
        winString = _(TUT_INTRO_VICTORY_MESSAGE)
      end
      levelOverText = uiLayer:add(ui.TextBox.new(winString, FONT_XLARGE, "ff0000", "center", device.width, 120, true))
      levelUI.resetting = true
      levelUI.ffbtn:onClick()
      levelui_hide_hud_buttons()
      local waitTime = {0.5}
      level_foreach_object_of_type("capitalship", _capship_warpout, waitTime, true)
      _capship_warpout(commandShip, waitTime)
      levelAS:wrap(levelOverText:seekColor(1, 1, 1, 0, waitTime[1] + 2, MOAIEaseType.SHARP_EASE_OUT), function()
        levelAS:delaycall(0.1, function()
          popups.show("on_g" .. levelGalaxyIndex .. "_s" .. levelSystemIndex .. "_end")
          levelAS:delaycall(0.1, function()
            if levelGalaxySystemIndex == TUT_INTRO_SYSTEM then
              levelAS:delaycall(2, function()
                levelAS:delaycall(0.1, function()
                  popup_intro_show()
                  levelAS:delaycall(0.1, function()
                    popups.clear_queue()
                    end_game(true)
                    level_clear()
                    menu_show("victory")
                    levelOverText:remove()
                    levelOverText = nil
                  end)
                end)
              end)
            else
              popups.clear_queue()
              end_game(true)
              level_clear()
              menu_show("victory")
              levelOverText:remove()
              levelOverText = nil
            end
          end)
        end)
      end)
    end)
  end
end
local _nonempty = function(x, def)
  if x ~= nil and x ~= "" then
    return x
  else
    return def
  end
end
function level_load(galaxyIndex, systemIndex, mode)
  print("Loading Level: ", galaxyIndex, systemIndex)
  environment_clear()
  if mode == "galaxy" then
    gameMode = "galaxy"
    environment_load(galaxyIndex, systemIndex)
    do
      local idx = (galaxyIndex - 1) * 40 + systemIndex
      assert(GALAXY_DATA[idx] ~= nil, "Invalid galaxy index: " .. tostring(galaxyIndex) .. "." .. tostring(systemIndex))
      levelGalaxySystemIndex = idx
      levelGalaxyIndex = galaxyIndex
      levelSystemIndex = systemIndex
      curLevelGalaxyIndex = galaxyIndex
      curLevelSystemIndex = systemIndex
      level_clear()
      levelDef = GALAXY_DATA[idx]
    end
  elseif mode == "survival" then
    gameMode = "survival"
    environment_load(1, math.random(2, 39))
    levelGalaxySystemIndex = "Survival"
    levelGalaxyIndex = "Survival"
    levelSystemIndex = "Survival"
    curLevelGalaxyIndex = "Survival"
    curLevelSystemIndex = "Survival"
    level_clear()
    levelDef = {}
  end
  bucket.push("LEVEL")
  listHead = {}
  levelAS:start()
  levelAS:run(_level_tick)
  if ENEMY_SPAWN_PULSE > 0 then
    levelAS:repeatcall(ENEMY_SPAWN_PULSE, _spawn_baddies)
  end
  levelAS:throttle(1)
  environmentAS:throttle(1)
  levelSpace = MOAICpSpace.new()
  levelSpace:setIterations(4)
  levelAS:wrap(levelSpace)
  if DEBUG_PHYSICS then
    mothershipLayer:setCpSpace(levelSpace)
  end
  reset_game()
end
function level_run(galaxyIndex, systemIndex)
  level_load(galaxyIndex, systemIndex, gameMode)
end
local startTouchX, startTouchY, startTouchX2, startTouchY2, curTouchX2, curTouchY2, pinchAction, pinchDist, curTouchX, curTouchY, lastTouchX, lastTouchY, dragStartWX, dragStartWY, camStartWX, camStartWY
local CAM_SCROLL_SPEED = 600
local CAM_SCROLL_MARGIN = 150
local CAM_SCROLL_T = device.height * device.ui_scale / 2 - CAM_SCROLL_MARGIN
local CAM_SCROLL_B = -CAM_SCROLL_T
local CAM_SCROLL_R = device.width * device.ui_scale / 2 - CAM_SCROLL_MARGIN
local CAM_SCROLL_L = -CAM_SCROLL_R
local function updateCameraScrollDir(x, y)
  if x == nil or y == nil then
    camScrollX = 0
    camScrollY = 0
    return
  end
  x, y = uiLayer:wndToWorld(x, y)
  local scroll = false
  local magX = 0
  local magY = 0
  if x > CAM_SCROLL_R then
    scroll = true
    magX = x - CAM_SCROLL_R
  elseif x < CAM_SCROLL_L then
    scroll = true
    magX = x - CAM_SCROLL_L
  end
  if y > CAM_SCROLL_T then
    scroll = true
    magY = y - CAM_SCROLL_T
  elseif y < CAM_SCROLL_B then
    scroll = true
    magY = y - CAM_SCROLL_B
  end
  if scroll then
    do
      local mx, my, mlen = normalize(magX, magY)
      local dx, dy, len = normalize(x, y)
      local mag = CAM_SCROLL_SPEED * math.min(mlen, CAM_SCROLL_MARGIN) / CAM_SCROLL_MARGIN
      camScrollX = dx * mag
      camScrollY = dy * mag
    end
  else
    camScrollX = 0
    camScrollY = 0
  end
end
function level_touch_filter(eventType, touchIdx, x, y, tapCount)
  if activePathCapturer ~= nil then
    updateCameraScrollDir(x, y)
  end
end
function level_default_touch(eventType, touchIdx, x, y, tapCount)
  local TOUCH_ONE = ui.TOUCH_ONE
  if levelDef == nil or touchIdx > TOUCH_ONE then
    if not levelDef then
      ui.capture(nil, level_default_touch)
    end
    return
  end
  local wx, wy = camera:modelToWorld(uiLayer:wndToWorld(x, y))
  if eventType == ui.TOUCH_DOWN then
    startTouchX = x
    startTouchY = y
    curTouchX, curTouchY = x, y
    camStartWX, camStartWY = camera:getLoc()
    return true
  elseif eventType == ui.TOUCH_MOVE then
    if startTouchX ~= nil and startTouchY ~= nil then
      lastTouchX, lastTouchY = curTouchX, curTouchY
      curTouchX, curTouchY = x, y
      if dragStartWX == nil then
      elseif distance(x, y, startTouchX or x, startTouchY or y) >= ui.DRAG_THRESHOLD * 2 then
        if dragStartWX == nil then
          ui.capture(level_default_touch)
        end
        dragStartWX, dragStartWY = camera:modelToWorld(uiLayer:wndToWorld(startTouchX, startTouchY))
        camera:setLoc(clampToLevelBounds(dragStartWX - wx + camStartWX, dragStartWY - wy + camStartWY))
        return true
      end
    end
  elseif eventType == ui.TOUCH_UP then
    startTouchX = nil
    startTouchY = nil
    ui.capture(nil, level_default_touch)
    if dragStartWX == nil then
      level_fire_cannon_at(wx, wy)
    else
      lastTouchX, lastTouchY = camera:modelToWorld(uiLayer:wndToWorld(lastTouchX, lastTouchY))
      local mag = distance(wx, wy, lastTouchX, lastTouchY) * 4
      local dirX, dirY = normalize(lastTouchX - wx, lastTouchY - wy)
      dirX = dirX * mag
      dirY = dirY * mag
      local camCurX, camCurY = camera:getLoc()
      if mag > 100 then
        local nx, ny = clampToLevelBounds(camCurX + dirX, camCurY + dirY)
        camera:seekLoc(nx, ny, 1.5, MOAIEaseType.SHARP_EASE_IN)
      end
      dragStartWX = nil
      dragStartWY = nil
      curTouchX = nil
      curTouchY = nil
      lastTouchX = nil
      lastTouchY = nil
    end
    return true
  end
end
function tostr(e, visited)
  if type(e) == "table" then
    visited = visited or {}
    return tablestr(e, visited)
  else
    return tostring(e)
  end
end
function printfln(fmt, ...)
  print(fmt:format(...))
end
