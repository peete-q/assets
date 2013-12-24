require("constants")
local csv = require("csv")
local pkgutil = require("pkgutil")
local _debug, _warn, _error = require("qlog").loggers("pkg_dep_loaders")
local verbose = false
local _M = {}
local _nonEmptyOrNil = function(s)
  if s == "" then
    return nil
  else
    return s
  end
end
_M["ShipData-GalaxyLevels.csv"] = function(filename)
  pkgutil.replace("ShipData-GalaxyLevels", filename, function(filename, modname)
    local data = csv.file_torecordset(filename, nil, true)
    table.remove(data, 1)
    return data
  end)
end
local function _addEntityDef(defs, id, quiet)
  quiet = quiet or false
  if verbose then
    if quiet then
      _debug("\t\tdefining: " .. id .. " (auto)")
    else
      _debug("\t\tdefining: " .. id)
    end
  end
  if defs[id] ~= nil then
    defs[id]._id = id
    return defs[id]
  end
  if not quiet then
    _warn("new entity type: " .. id)
  end
  local d = {_id = id}
  defs[id] = d
  return d
end
local function _addCannonDefs(defs, id, row)
  local pd = _addEntityDef(defs, id .. "_projectile")
  pd.maxspeed = 1000
  pd.accel = 500
  pd.weaponRange = row["Cannon AOE"]
  pd.weaponDamage = row["Cannon Dmg"]
  pd.weaponPulses = 1
  pd.weaponPulseDelay = 0
  pd.weaponCooldown = 0
  pd.ai = "cannon_projectile"
  pd.resourceDropMod = _nonEmptyOrNil(row["Resource Drop Mod"])
  if row["Entity Type"] == "capitalship" then
    pd.type = "missile"
  else
    pd.type = "alien_missile"
  end
  local md = _addEntityDef(defs, id .. "_cannon")
  md.cannonProjectileType = pd._id
  md.cannonIcon = md.cannonIcon or "cannon_cooldown.png"
  md.cannonCooldown = 1 / row["Cannon ROF"]
  if id:find("Gunship_Tesla") then
    md.type = "tesla_cannon"
    md.teslaMode = true
    pd.teslaMode = true
    pd.teslaCooldown = 1 / row["Cannon ROF"]
    md.teslaCooldown = row["Cannon ROF"]
    md.turretOverlay = "hud.atlas.png#selectorGunship.png?scl=0.5&pri=4"
    md.moduleOverlay = "selectorGunshipReload.png"
    md.pathColor = UI_SHIP_COLOR_TESLA_HEX
    md.pathAlpha = 0.75
    md.ai = "tesla_module"
    md.weaponDamage = row["Cannon Dmg"]
    md.teslaFireTime = row["Cannon AOE"]
  else
    md.ai = "cannon_module"
    if row["Entity Type"] == "capitalship" then
      md.type = "cannon"
    else
      md.type = "alien_cannon"
    end
  end
  return md, pd
end
local function _addHangarModuleDefs(defs, id, subtype, row, storeTags)
  local sd = _addEntityDef(defs, id .. "_" .. subtype)
  local md = _addEntityDef(defs, id .. "_" .. subtype .. "_module", true)
  if storeTags then
    if storeTags.harvester then
      md.texture = "hud.atlas.png#selectorMiner.png"
    elseif storeTags.fighter then
      md.texture = "hud.atlas.png#selectorFighter.png"
    elseif storeTags.interceptor then
      md.texture = "hud.atlas.png#selectorInterceptor.png"
    elseif storeTags.bomber then
      md.texture = "hud.atlas.png#selectorBomber.png"
    else
      md.texture = "hud.atlas.png#selectorFighter.png"
    end
  elseif subtype == "harvester" then
    md.texture = "hud.atlas.png#selectorMiner.png"
  else
    md.texture = "hud.atlas.png#selectorFighter.png"
  end
  md.hangarInventoryType = sd._id
  md.pathingMode = true
  md.scl = 0.5
  if subtype == "harvester" then
    md.pathColor = UI_SHIP_COLOR_DEFENSE_HEX
  elseif subtype == "fighter" then
    if string.find(id, "Anti") then
      md.pathColor = UI_SHIP_COLOR_INTERCEPTORS_HEX
    elseif string.find(id, "Bomber") then
      md.pathColor = UI_SHIP_COLOR_BOMBERS_HEX
    else
      md.pathColor = UI_SHIP_COLOR_FIGHTERS_HEX
    end
  end
  md.pathAlpha = 0.75
  if subtype == "harvester" then
    if id:find("SPC") then
      md.commandModule = true
    end
    md.ai = "harvester_module"
  else
    md.ai = "hangar_module"
  end
  md.type = "module"
  return md, sd
end
local function _importEntityDef(defs, id, row)
  local d
  if verbose then
    _debug("\timporting " .. id .. ": " .. _nonEmptyOrNil(row.Name))
  end
  if row["Entity Type"] ~= "" then
    d = _addEntityDef(defs, id)
    d.type = row["Entity Type"]
    if row["Cost DC"] ~= "" then
      d.buildCost = {
        blue = row["Cost DC"]
      }
    end
    d.hp = _nonEmptyOrNil(row.HP)
    d.storePurchaseCost = _nonEmptyOrNil(row["Ingots Cost"])
    d.storePurchaseType = _nonEmptyOrNil(row["Purchase Type"])
    d.storeUnlockLevel = _nonEmptyOrNil(row["Unlock Level"])
    d.storeMinSystem = _nonEmptyOrNil(row["Min System Req"])
    d.storeMinWave = _nonEmptyOrNil(row["Min Wave Req"])
    d.storeGroup = _nonEmptyOrNil(row.Group)
    d.storeName = _nonEmptyOrNil(row.Name)
    d.storeClass = _nonEmptyOrNil(row.Class)
    d.storeDescription = _nonEmptyOrNil(row.Description)
    if row["Store Tags"] ~= "" then
      local tags = _nonEmptyOrNil(row["Store Tags"])
      if tags then
        local tt = {}
        local q = util.strsplit(",", tags)
        for k, v in pairs(q) do
          tt[v] = true
        end
        d.storeTags = tt
      end
    end
    if row["Resource Weight"] ~= "" then
      d.towedObjectWeight = row["Resource Weight"]
    end
    if row["Resource Value"] ~= "" then
      d.resourceValue = row["Resource Value"]
    end
    if row["Resource Drops"] ~= "" then
      if not d.lootDrop then
        d.lootDrop = {}
      end
      local resourceDropNum = row["Resource Drops"]
      d.lootDrop.Salvage_Lg = math.floor(resourceDropNum / 5)
      d.lootDrop.Salvage_Sm = resourceDropNum % 5
    end
    if row["Cred Drops"] ~= "" then
      if not d.lootDrop then
        d.lootDrop = {}
      end
      d.lootDrop.Salvage_Credit = row["Cred Drops"]
    end
    if row["Score Value"] ~= "" then
      d.scoreValue = row["Score Value"]
    end
    d.accel = _nonEmptyOrNil(row.Accel) or 10
    d.startDC = _nonEmptyOrNil(row["Starting DC"])
    d.maxDC = _nonEmptyOrNil(row["Max DC"])
  end
  if row["Cannon #"] ~= "" then
    local md, pd = _addCannonDefs(defs, id, row)
  end
  if row["Harv HP"] ~= "" and row["Harv DC Gen"] ~= "" then
    local md, sd
    if row["Entity Type"] == "capitalship" then
      md, sd = _addHangarModuleDefs(defs, id, "harvester", row, d.storeTags)
      md.hangarCapacity = row["Max Harv #"]
    else
      sd = d
    end
    sd.maxspeed = row["Harv Spd"]
    sd.accel = row["Harv Acc"]
    sd.turnSpeed = true
    sd.hp = row["Harv HP"]
    sd.hpHidden = true
    sd.targetTypes = {asteroid = true, survivor = true}
    sd.collectTypes = "resource"
    sd.fleeTypes = {enemyf = true, enemyb = true}
    if row["Harv Brave"] == "High" then
      sd.weaponRange = 150
      sd.fleeRange = 25
    else
      sd.weaponRange = 100
      sd.fleeRange = 150
    end
    sd.harvestResourceType = "blue"
    sd.harvestRate = 10 / (row["Harv DC Gen"] or 10)
    sd.towedObjectMax = row["Harv Haul Cap"]
    sd.buildCost = {
      blue = row["Harv Cost DC"]
    }
    sd.buildTime = row["Harv Build Time"] or 1
    sd.ai = "patrolling_miner"
    sd.type = "harvester"
  end
  if row["Fighter HP"] ~= "" then
    local md, sd
    if row["Entity Type"] == "capitalship" then
      md, sd = _addHangarModuleDefs(defs, id, "fighter", row, d.storeTags)
      md.hangarCapacity = row["Max Fighter #"]
    else
      sd = d
    end
    sd.maxspeed = row["Fighter Spd"]
    sd.accel = row["Fighter Acc"]
    sd.turnSpeed = true
    sd.hp = row["Fighter HP"]
    if row["Entity Type"] ~= "enemyc" then
      sd.hpHidden = true
    end
    sd.weaponRange = row["Fighter Rng"]
    sd.weaponDamage = row["Wpn Dmg"]
    sd.weaponPulses = row["Wpn Pulse"]
    sd.weaponPulseDelay = row["Wpn Pulse Delay"]
    sd.weaponCooldown = row["Wpn Cooldown"]
    sd.buildCost = {
      blue = row["Fighter Cost DC"]
    }
    sd.buildTime = row["Fighter Build Time"] or 1
    sd.ai = sd.ai or "patrolling_fighter"
    sd.type = sd.type or "fighter"
    local storeTags = d.storeTags
    if storeTags then
      if storeTags.fighter then
        sd.fighterType = "fighter"
      elseif storeTags.interceptor then
        sd.fighterType = "interceptor"
      elseif storeTags.bomber then
        sd.fighterType = "bomber"
      else
        sd.fighterType = "fighter"
      end
    else
      sd.fighterType = "fighter"
    end
    local ttypes = _nonEmptyOrNil(row["Fighter Target Types"])
    if ttypes then
      local tt = {}
      local q = util.strsplit(",", ttypes)
      for k, v in pairs(q) do
        local entry, def = util.breakstr(v, "=")
        tt[entry] = tonumber(def) or 1
      end
      sd.targetTypes = tt
    end
    local stypes = _nonEmptyOrNil(row.Shields)
    if stypes then
      local q = util.strsplit(",", stypes)
      for k, v in pairs(q) do
        local entry, def = util.breakstr(v, "=")
        if entry == "mod" then
          sd.shieldDamping = tonumber(def)
        elseif entry == "arc" then
          sd.shieldArc = tonumber(def)
        elseif entry == "angle" then
          sd.shieldAngle = tonumber(def)
        end
      end
    end
  end
end
_M["ShipData-ShipStats.csv"] = function(filename)
  pkgutil.replace("entitydef", filename, function(filename, modname)
    local sourcefile = SOURCE_ENTITY_LUA_FILE
    _debug("Importing " .. sourcefile .. " and " .. filename .. "...")
    local t0 = os.clock()
    local defs = dofile(sourcefile)
    local REQF = {
      "Group",
      "Name",
      "ID",
      "Cost DC"
    }
    local SPARSEF = {"Group", "Name"}
    for row in csv.file_listrows(filename, REQF, SPARSEF, nil, true) do
      if row.ID ~= nil and row.ID ~= "" then
        _importEntityDef(defs, row.ID, row)
      end
    end
    for k, v in pairs(defs) do
      v._id = k
      v._baseID = k:gsub("_%d+$", "")
      v._upgradeNum = tonumber(k:match("_(%d+)$"))
      if v.collisionRadius == nil then
      end
    end
    local t1 = os.clock()
    _debug(string.format("Loaded \"%s\" in %d ms", modname, (t1 - t0) * 1000))
    return defs
  end)
end
return _M
