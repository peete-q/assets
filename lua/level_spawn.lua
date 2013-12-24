require("constants")
local randutil = require("randutil")
local interpolate = require("interpolate")
local math2d = require("math2d")
local util = require("util")
local popups = require("popups")
local soundmanager = require("soundmanager")
local gfxutil = require("gfxutil")
local _debug, _warn, _error = require("qlog").loggers("level_spawn")
local _M = {}
local random = math.random
local table_insert = table.insert
local table_remove = table.remove
local PI = math.pi
local TWO_PI = math.pi * 2
local cos = math.cos
local sin = math.sin
local deg = math.deg
local rad = math.rad
local abs = math.abs
local normalize = math2d.normalize
local set_if_nil = util.set_if_nil
local DEFAULT_SURVIVAL_SEED = 3297444
local function vary(x, variance)
  return x + random() * variance * 2 - variance
end
local _sort_group_by_cost = function(a, b)
  return b.cost < a.cost
end
local _gen_spawn_group = function(group, groupsUsed)
  local g = {}
  local gid = group._id
  if groupsUsed[gid] == nil then
    groupsUsed[gid] = group.ships
  end
  g.move = "straight"
  g.gid = gid
  g.cost = group.cost
  return g
end
function _M.genWaveDefs(galaxyIndex, systemIndex, levelDef, arcDefs, groupDefs)
  local arcs = arcDefs or require("ShipData-SessionArc")
  local arc = arcs[levelDef["System Arc"]]
  if arc == nil then
    _warn("System Arc is invalid: " .. tostring(levelDef["System Arc"]) .. " (using a default)")
    arc = arcs[0]
  end
  levelWidth = levelDef["System Radius"] or DEFAULT_LEVEL_SIZE
  levelHeight = levelWidth
  local groupdefs = groupDefs or require("ShipData-GroupDefs")
  local groupsUsed = {}
  local availableGroups = {}
  local table_insert = table.insert
  for k, group in pairs(groupdefs) do
    local spans = group.ranges[galaxyIndex]
    if spans ~= nil then
      local ok = false
      for j = 1, #spans, 2 do
        if systemIndex >= spans[j] and systemIndex <= spans[j + 1] then
          ok = true
          break
        end
      end
      if ok then
        table_insert(availableGroups, group)
      end
    end
  end
  _debug(string.format("Generating Wave definitions for Galaxy=%d System=%d Arc=%d [Seed = %d, Env Seed = %d]:", galaxyIndex, systemIndex, levelDef["System Arc"], levelDef.Seed, levelDef["Environment Seed"]))
  randutil.randomseed(levelDef.Seed, 3)
  local spawns = {}
  local survivors = {}
  local saucers = {}
  local waveCount = 0
  for waveNum = 1, WAVE_COUNT do
    local waveDef = {}
    local points = levelDef[tostring(waveNum)]
    if points > 0 then
      waveCount = waveNum
    end
    waveDef.t = (waveNum - 1) * WAVE_TIME
    waveDef.relt = (waveNum - 1) / WAVE_COUNT
    waveDef.points = points
    local theta_a = math.floor(random() * 360)
    local theta_b = math.floor(random() * 360)
    local theta_c = math.floor(random() * 360)
    local wavegroups = {}
    local kinds = arc[waveNum].types
    local availableGroupsA
    local minCostA = points * 0.5
    local maxCostA = points * 0.8
    for i = 1, #availableGroups do
      local group = availableGroups[i]
      if kinds[group.kind] then
        local cost = group.cost
        if minCostA <= cost and maxCostA >= cost then
          if availableGroupsA == nil then
            availableGroupsA = {}
          end
          table_insert(availableGroupsA, group)
        end
      end
    end
    if availableGroupsA ~= nil then
      local g = availableGroupsA[random(1, #availableGroupsA)]
      table_insert(wavegroups, _gen_spawn_group(g, groupsUsed))
      points = points - g.cost
    end
    local availableGroupsB
    local minCostB = points * 0.25
    local maxCostB = points * 0.5
    for i = 1, #availableGroups do
      local group = availableGroups[i]
      if kinds[group.kind] then
        local cost = group.cost
        if minCostB <= cost and maxCostB >= cost then
          if availableGroupsB == nil then
            availableGroupsB = {}
          end
          table_insert(availableGroupsB, group)
        end
      end
    end
    if availableGroupsB ~= nil then
      local g = availableGroupsB[random(1, #availableGroupsB)]
      table_insert(wavegroups, _gen_spawn_group(g, groupsUsed))
      points = points - g.cost
    end
    local availableGroupsC
    for i = 1, #availableGroups do
      local group = availableGroups[i]
      if kinds[group.kind] and points >= group.cost then
        if availableGroupsC == nil then
          availableGroupsC = {}
        end
        table_insert(availableGroupsC, group)
      end
    end
    if availableGroupsC ~= nil then
      local found = true
      while points > 0 and #availableGroupsC > 0 do
        local k = random(1, #availableGroupsC)
        local g = availableGroupsC[k]
        if points < g.cost then
          table_remove(availableGroupsC, k)
        else
          table_insert(wavegroups, _gen_spawn_group(g, groupsUsed))
          points = points - g.cost
        end
      end
    end
    if #wavegroups <= 2 then
      waveDef.spawns = {
        [theta_a] = wavegroups
      }
    else
      local a = {}
      local b = {}
      local c = {}
      table.sort(wavegroups, _sort_group_by_cost)
      table_insert(a, wavegroups[1])
      table_insert(b, wavegroups[2])
      table_insert(b, wavegroups[#wavegroups])
      for i = 3, #wavegroups - 2 do
        local roll = random()
        if roll <= 0.33 then
          table_insert(a, wavegroups[i])
        elseif roll <= 0.66 then
          table_insert(b, wavegroups[i])
        else
          table_insert(c, wavegroups[i])
        end
      end
      if #c > 0 then
        waveDef.spawns = {
          [theta_a] = a,
          [theta_b] = b,
          [theta_c] = c
        }
      else
        waveDef.spawns = {
          [theta_a] = a,
          [theta_b] = b
        }
      end
    end
    local groupids = {}
    for _, g in ipairs(wavegroups) do
      g.cost = nil
      table_insert(groupids, g.gid)
    end
    _debug(string.format("\tWave %2d [%3d]: %s", waveNum, levelDef[tostring(waveNum)], table.concat(groupids, " ")))
    table_insert(spawns, waveDef)
  end
  local asteroids = {}
  randutil.randomseed(levelDef["Environment Seed"] or levelDef.Seed, 3)
  local N = tonumber(levelDef["# Asteroids"])
  if not N or N < 0 then
    N = 1
  end
  for i = 1, N do
    local _type
    if random() < 0.5 then
      _type = "Asteroid_Lg"
    else
      _type = "Asteroid_Med"
    end
    local rdir
    if random() > 0.5 then
      rdir = 1
    else
      rdir = -1
    end
    local theta = vary(i / N * TWO_PI, PI / 8)
    if theta < 0 then
      theta = theta + TWO_PI
    end
    if theta > TWO_PI then
      theta = theta - TWO_PI
    end
    table_insert(asteroids, {
      _type,
      random(6, 18),
      rdir,
      theta,
      random()
    })
  end
  local saucerSpawnChance = levelDef["Flying Saucer % per wave"]
  if saucerSpawnChance and saucerSpawnChance:sub(saucerSpawnChance:len()) == "%" then
    saucerSpawnChance = saucerSpawnChance:sub(1, saucerSpawnChance:len() - 1)
  end
  saucerSpawnChance = (tonumber(saucerSpawnChance) or 0) / 100
  for waveNum = 1, WAVE_COUNT do
    local kinds = arc[waveNum].types
    local survivorDef = {}
    for k, v in pairs(kinds) do
      if k:len() == 2 and k:find("%a%d") then
        table_insert(survivorDef, {
          k,
          random(levelWidth * 0.8, levelWidth * 0.92),
          random(TWO_PI)
        })
      end
    end
    table_insert(survivors, survivorDef)
    local saucerDef
    if saucerSpawnChance > random() then
      saucerDef = {
        random(TWO_PI)
      }
    else
      saucerDef = {}
    end
    table_insert(saucers, saucerDef)
  end
  spawns._asteroids = asteroids
  spawns._groups = groupsUsed
  spawns._survivors = survivors
  spawns._saucers = saucers
  spawns._waveCount = waveCount
  return spawns
end
function _M.genSurvivalDefSet(spawnList, galaxyStrength, firstArc)
  galaxyStrength = galaxyStrength or 10
  local survivalDefs = require("ShipData-Survival")
  local def
  if firstArc == nil then
    def = survivalDefs[math.random(#survivalDefs - 1) + 1]
  else
    def = survivalDefs[1]
  end
  local numArcs = #def.arcs
  local roundedStrength = util.roundNumber(galaxyStrength)
  for i = 1, numArcs do
    table_insert(spawnList, _M.genSurvivalDefs(def.arcs, nil, nil, i, roundedStrength, def.seed))
  end
  randutil.randomseed(randutil.seed_timelo(), 3)
  if firstArc == nil then
    galaxyStrength = math.min(galaxyStrength + galaxyStrength * SURVIVAL_MODE_DIFFICULTY_RAMP, SURVIVAL_MODE_DIFFICULTY_CAP or 50)
  end
  return galaxyStrength
end
function _M.genSurvivalDefs(arcDef, arcsDef, groupDefs, setIndex, galaxyStrength, seed)
  local arcs = arcDefs or require("ShipData-SessionArc")
  local arc = arcs[arcDef[setIndex].arc]
  if arc == nil then
    _warn("Survial Arc is invalid: (using a default)")
    arc = arcs[0]
  end
  levelWidth = DEFAULT_LEVEL_SIZE
  levelHeight = levelWidth
  local groupdefs = groupDefs or require("ShipData-GroupDefs")
  local groupsUsed = {}
  local availableGroups = {}
  local table_insert = table.insert
  for k, group in pairs(groupdefs) do
    local minArc = group.minSurvialArc
    if minArc ~= nil and galaxyStrength >= minArc[1] and galaxyStrength <= minArc[2] then
      table_insert(availableGroups, group)
    end
  end
  randutil.randomseed(arcDef[setIndex].seed or seed, 3)
  local spawns = {}
  local survivors = {}
  local saucers = {}
  local waveCount = 0
  local galStrength = galaxyStrength or 10
  for waveNum = 1, WAVE_COUNT do
    local waveDef = {}
    local points = galStrength * arc[waveNum].value
    if points > 0 then
      waveCount = waveNum
    end
    waveDef.t = (waveNum - 1) * WAVE_TIME
    waveDef.relt = (waveNum - 1) / WAVE_COUNT
    waveDef.points = points
    local theta_a = math.floor(random() * 360)
    local theta_b = math.floor(random() * 360)
    local theta_c = math.floor(random() * 360)
    local wavegroups = {}
    local kinds = arc[waveNum].types
    local availableGroupsA
    local minCostA = points * 0.5
    local maxCostA = points * 0.8
    for i = 1, #availableGroups do
      local group = availableGroups[i]
      if kinds[group.kind] then
        local cost = group.cost
        if minCostA <= cost and maxCostA >= cost then
          if availableGroupsA == nil then
            availableGroupsA = {}
          end
          table_insert(availableGroupsA, group)
        end
      end
    end
    if availableGroupsA ~= nil then
      local g = availableGroupsA[random(1, #availableGroupsA)]
      table_insert(wavegroups, _gen_spawn_group(g, groupsUsed))
      points = points - g.cost
    end
    local availableGroupsB
    local minCostB = points * 0.25
    local maxCostB = points * 0.5
    for i = 1, #availableGroups do
      local group = availableGroups[i]
      if kinds[group.kind] then
        local cost = group.cost
        if minCostB <= cost and maxCostB >= cost then
          if availableGroupsB == nil then
            availableGroupsB = {}
          end
          table_insert(availableGroupsB, group)
        end
      end
    end
    if availableGroupsB ~= nil then
      local g = availableGroupsB[random(1, #availableGroupsB)]
      table_insert(wavegroups, _gen_spawn_group(g, groupsUsed))
      points = points - g.cost
    end
    local availableGroupsC
    for i = 1, #availableGroups do
      local group = availableGroups[i]
      if kinds[group.kind] and points >= group.cost then
        if availableGroupsC == nil then
          availableGroupsC = {}
        end
        table_insert(availableGroupsC, group)
      end
    end
    if availableGroupsC ~= nil then
      local found = true
      while points > 0 and #availableGroupsC > 0 do
        local k = random(1, #availableGroupsC)
        local g = availableGroupsC[k]
        if points < g.cost then
          table_remove(availableGroupsC, k)
        else
          table_insert(wavegroups, _gen_spawn_group(g, groupsUsed))
          points = points - g.cost
        end
      end
    end
    if #wavegroups <= 2 then
      waveDef.spawns = {
        [theta_a] = wavegroups
      }
    else
      local a = {}
      local b = {}
      local c = {}
      table.sort(wavegroups, _sort_group_by_cost)
      table_insert(a, wavegroups[1])
      table_insert(b, wavegroups[2])
      table_insert(b, wavegroups[#wavegroups])
      for i = 3, #wavegroups - 2 do
        local roll = random()
        if roll <= 0.33 then
          table_insert(a, wavegroups[i])
        elseif roll <= 0.66 then
          table_insert(b, wavegroups[i])
        else
          table_insert(c, wavegroups[i])
        end
      end
      if #c > 0 then
        waveDef.spawns = {
          [theta_a] = a,
          [theta_b] = b,
          [theta_c] = c
        }
      else
        waveDef.spawns = {
          [theta_a] = a,
          [theta_b] = b
        }
      end
    end
    local groupids = {}
    for _, g in ipairs(wavegroups) do
      g.cost = nil
      table_insert(groupids, g.gid)
    end
    table_insert(spawns, waveDef)
  end
  local asteroids = {}
  randutil.randomseed(arcDef[setIndex].seed or seed, 3)
  local saucerSpawnChance = arcDef[setIndex].saucerChance or "0%"
  if saucerSpawnChance and saucerSpawnChance:sub(saucerSpawnChance:len()) == "%" then
    saucerSpawnChance = saucerSpawnChance:sub(1, saucerSpawnChance:len() - 1)
  end
  saucerSpawnChance = (tonumber(saucerSpawnChance) or 0) / 100
  for waveNum = 1, WAVE_COUNT do
    local kinds = arc[waveNum].types
    local survivorDef = {}
    for k, v in pairs(kinds) do
      if k:len() == 2 and k:find("%a%d") then
        table_insert(survivorDef, {
          k,
          random(levelWidth * 0.8, levelWidth * 0.92),
          random(TWO_PI)
        })
      end
    end
    table_insert(survivors, survivorDef)
    local asteroidDef = {}
    local asteroidArcs = arcDef[setIndex].asteroidPlacement
    if asteroidArcs and asteroidArcs[waveNum] then
      local numAsteroids = asteroidArcs[waveNum]
      for i = 1, numAsteroids do
        local _type
        if random() < 0.5 then
          _type = "Asteroid_Lg"
        else
          _type = "Asteroid_Med"
        end
        local rdir
        if random() > 0.5 then
          rdir = 1
        else
          rdir = -1
        end
        local rSpeed = random(6, 18)
        local dir
        if random() > 0.5 then
          dir = 1
        else
          dir = -1
        end
        table_insert(asteroidDef, {
          _type,
          rSpeed,
          rdir,
          dir
        })
      end
    end
    table_insert(asteroids, asteroidDef)
    local saucerDef
    if saucerSpawnChance > random() then
      saucerDef = {
        random(TWO_PI)
      }
    else
      saucerDef = {}
    end
    table_insert(saucers, saucerDef)
  end
  spawns._asteroids = asteroids
  spawns._groups = groupsUsed
  spawns._survivors = survivors
  spawns._saucers = saucers
  spawns._waveCount = waveCount
  spawns._arc = arcDef[setIndex].arc
  spawns._galStrength = galaxyStrength
  return spawns
end
function _M.spawnAsteroids(asteroidsDef)
  for _, adef in ipairs(asteroidsDef) do
    local o = level_spawn_object(adef[1], mothershipLayer)
    o.driftX = 0
    o.driftY = 0
    o.rotSpeed = adef[2]
    o.rotDir = adef[3]
    local theta = adef[4]
    local rn = 0.4 * (adef[5] - 0.5)
    local x = cos(theta) * (stageWidth * rn + stageWidth * 0.75)
    local y = sin(theta) * (levelHeight * rn + levelHeight)
    o:setLoc(x, y)
    o.moduleType = "mineblank"
  end
end
function _M.spawnSurvivalModeAsteroid(asteroidDef, wave)
  if not asteroidDef or not asteroidDef[wave] or not asteroidDef[wave][1] then
    return
  end
  for k, v in pairs(asteroidDef[wave]) do
    local launchHeight = math.max(stageHeight * 0.5 + levelHeight * 0.5, levelHeight)
    local shipWidth = CAPITAL_SHIP_SPAWN_RADIUS + 75
    local launchWidth = stageWidth - (shipWidth + 50)
    local def = asteroidDef[wave][k]
    local o = level_spawn_object(def[1], mothershipLayer)
    o.driftX = 0
    o.driftY = SURVIVAL_MODE_ASTEROID_DRIFT or -0.4
    o.rotSpeed = def[2]
    o.rotDir = def[3]
    table_insert(asteroidDef, {
      _type,
      rSpeed,
      rdir,
      dir
    })
    local x = (shipWidth + random(launchWidth)) * def[4]
    local y = launchHeight
    o:setLoc(x, y)
    o.moduleType = "mineblank"
    local function collisionResolution(self, o)
      if self == o then
        return
      end
      local x1, y1 = self:getLoc()
      local x2, y2 = o:getLoc()
      local vecX = x2 - x1
      local vecY = y2 - y1
      local vecXN, vecYN, dist = normalize(vecX, vecY)
      local d = self.collisionRadius + o.collisionRadius + 1 - dist
      o:setLoc(x2 + vecXN * d, y2 + vecYN * d)
      return true
    end
    local collision = true
    while collision do
      local x, y = o:getLoc()
      collision = level_foreach_object_of_type_in_circle({asteroid = true}, x, y, o.collisionRadius, collisionResolution, o)
    end
  end
end
function _M.spawnSaucer(saucerDef, wave)
  if not saucerDef or not saucerDef[wave] or not saucerDef[wave][1] then
    return
  end
  local def = saucerDef[wave]
  local o = level_spawn_object("Alien_Credit_Saucer", mothershipLayer)
  local pad = 1.2
  local theta = def[1]
  local sx = levelWidth * pad * cos(theta)
  local sy = levelHeight * pad * sin(theta)
  o:setLoc(sx, sy)
  local dir = math.atan2(-sy, -sx)
  o.startRot = deg(dir) + math.random(-30, 30)
  o:setRot(o.startRot)
end
function _M.spawnSurvivor(survivorDef, wave)
  if not survivorDef[wave] then
    return
  end
  for k, v in pairs(survivorDef[wave]) do
    do
      local scl = v[2]
      local theta = v[3]
      local sx = scl * cos(theta)
      local sy = scl * sin(theta)
      local sType, sVal = v[1]:match("(%a)(%d)")
      if sType == "a" then
        sType = "Mn"
      else
        sType = "Egn"
      end
      if sVal == "9" then
        sVal = "Lg"
      elseif sVal == "6" then
        sVal = "Med"
      else
        sVal = "Sm"
      end
      local o = level_spawn_object(string.format("Escape_Pod_%s_%s", sType, sVal), mothershipLayer, sx, sy, true)
      local function collisionResolution(self, o)
        if self == o then
          return
        end
        local x1, y1 = self:getLoc()
        local x2, y2 = o:getLoc()
        local vecX = x2 - x1
        local vecY = y2 - y1
        local vecXN, vecYN, dist = normalize(vecX, vecY)
        local d = self.collisionRadius + o.collisionRadius + 1 - dist
        o:setLoc(x2 + vecXN * d, y2 + vecYN * d)
        return true
      end
      local collision = true
      while collision do
        local x, y = o:getLoc()
        collision = level_foreach_object_of_type_in_circle({
          asteroid = true,
          survivor = true,
          enemyc = true,
          capitalship = true
        }, x, y, o.collisionRadius, collisionResolution, o)
      end
      local x, y = o:getLoc()
      local scl = o.sprite:getScl()
      o.sprite:setScl(0, 0)
      soundmanager.onSFX("onWarp")
      level_fx_explosion(x, y - 50, 0, nil, "warpIn.pex")
      gfxutil.playAssets(o.sprite)
      levelAS:delaycall(0.2, function()
        o:setLoc(x, y)
        o.sprite:setLoc(0, -o.def.collisionRadius)
        levelAS:wrap(o.sprite:seekLoc(0, 0, 0.7, MOAIEaseType.LINEAR))
        levelAS:wrap(o.sprite:seekScl(scl, scl, 0.5, MOAIEaseType.EASE_IN))
      end)
      set_if_nil(gameSessionAnalytics, "rescues", {})
      gameSessionAnalytics.rescues.spawned = (gameSessionAnalytics.rescues.spawned or 0) + 1
    end
  end
end
function _M.spawnWave(wavesDef, wave)
  local waveDef = wavesDef[wave]
  if waveDef == nil then
    return
  end
  local padMult = 1
  local randPoint = math2d.randomPointInCircle
  local spawn_obj = level_spawn_object
  local behaviors = require("behavior")
  local DISC = behaviors.DISCIPLINE_VALUES
  local launchWidth = math.max(stageWidth * 0.5 + levelWidth * 0.5, levelWidth)
  local launchHeight = math.max(stageHeight * 0.5 + levelHeight * 0.5, levelHeight)
  for theta, groups in pairs(waveDef.spawns) do
    local vr = groups.vr or DEFAULT_LOC_VARIANCE
    theta = rad(theta)
    local sx = (launchWidth * padMult + vr) * cos(theta)
    local sy = (launchHeight * padMult + vr) * sin(theta)
    for _, grp in ipairs(groups) do
      local ships = wavesDef._groups[grp.gid]
      local moveVal = math.random()
      local moveDirV = math.random()
      local move = "straight"
      local moveDir
      local squad = setmetatable({}, {__mode = "k"})
      local n = 1
      local squad_points = 0
      for _, rec in ipairs(ships) do
        for j = 1, rec.qty do
          local success, result = pcall(spawn_obj, rec.id)
          if success then
            do
              local o = result
              local x, y = randPoint(sx, sy, vr)
              if x > -launchWidth and launchWidth > x and y > -launchHeight and launchHeight > y then
                if abs(x) > abs(y) then
                  if x < 0 then
                    x = -launchWidth
                  else
                    x = launchWidth
                  end
                elseif y < 0 then
                  y = -launchHeight
                else
                  y = launchHeight
                end
              end
              o:setLoc(x, y)
              o.discipline = DISC[rec.disc] or 1
              o.bravery = rec.brv / 100
              o.squad = squad
              n = n + 1
              squad[o] = n
              squad_points = squad_points + o.def.scoreValue
              local tickfn = behaviors[rec.eng]
              if tickfn ~= nil then
                o.tickfn = tickfn
              end
            end
          else
            _error(tostring(result))
          end
        end
      end
      squad.totalpoints = squad_points
      squad.curpoints = squad_points
      squad.move = move
      squad.moveDir = moveDir
    end
  end
end
return _M
