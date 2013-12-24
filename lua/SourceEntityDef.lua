local _M = {}
local function _deepcopy(tt)
  if type(tt) == "table" then
    do
      local vv = {}
      for k, v in pairs(tt) do
        vv[k] = _deepcopy(v)
      end
      return vv
    end
  else
    return tt
  end
end
local CLONE_SUFFIXES = {
  "",
  "_fighter",
  "_harvester",
  "_cannon",
  "_projectile"
}
local PROJECTILE_TARGETS = {
  enemyf = true,
  enemyb = true,
  enemyc = true,
  saucer = true
}
local ALIEN_PROJECTILE_TARGETS = {
  capitalship = true,
  harvester = true,
  fighter = true
}
local function _cloneup(basename, n)
  for i = 1, n do
    for _, sfx in ipairs(CLONE_SUFFIXES) do
      if _M[basename .. "_" .. i - 1 .. sfx] ~= nil then
        _M[basename .. "_" .. i .. sfx] = _deepcopy(_M[basename .. "_" .. i - 1 .. sfx])
        local sub = _M[basename .. "_" .. i .. sfx].subentities
        if sub then
          for k, v in pairs(sub) do
            sub[k] = sub[k]:gsub(basename .. "_" .. i - 1, basename .. "_" .. i)
          end
        end
      end
    end
  end
end
_M.SPC_0 = {
  texture = {
    "capShipTrail.pex?loc=-25,-128&looping=true",
    "capShipTrail.pex?loc=-40,-126&looping=true",
    "capShipTrail.pex?loc=25,-128&looping=true",
    "capShipTrail.pex?loc=40,-126&looping=true",
    "StarPatrolOne.atlas.png#ship01.png",
    "invisible.png?loc=0,-120&pri=-1&looping=true",
    "StarPatrolOne.atlas.png?loc=-69,-87&anim=runningLightGold&looping=true",
    "StarPatrolOne.atlas.png?loc=69,-87&anim=runningLightGold&looping=true"
  },
  damageTextures = {
    {
      "StarPatrolOne.atlas.png#dmgState01.png",
      "shipDeathExplosion.pex?loc=-29,48",
      "shipDeathExplosion.pex?loc=-22,88",
      "shipFire03.pex?loc=-29,48&looping=true",
      "shipFire03.pex?loc=22,88&looping=true",
      "shipFire03.pex?loc=-26,70&looping=true",
      "shipDeathExplosion.pex?loc=26,88",
      "shipFire.pex?loc=22,88&looping=true",
      "capShipSparks.pex?loc=22,88&looping=true",
      "shipFire.pex?loc=28,110&looping=true",
      "shipFire.pex?loc=-29,48&looping=true",
      "shipFire.pex?loc=-26,70&looping=true"
    },
    {
      "StarPatrolOne.atlas.png#dmgState02.png",
      "shipDeathExplosion.pex?loc=-29,48",
      "shipDeathExplosion.pex?loc=26,88",
      "shipDeathExplosion.pex?loc=-10,88",
      "shipDeathExplosion.pex?loc=35,8",
      "shipFire03.pex?loc=-29,48&looping=true",
      "shipFire03.pex?loc=26,88&looping=true",
      "shipFire03.pex?loc=-26,70&looping=true",
      "shipFire03.pex?loc=35,-115&looping=true",
      "shipFire.pex?loc=22,88&looping=true",
      "shipFire.pex?loc=26,88&looping=true",
      "shipFire.pex?loc=-26,70&looping=true",
      "shipFire.pex?loc=-29,48&looping=true",
      "shipFire.pex?loc=-10,-5&looping=true",
      "shipFire.pex?loc=5,4&looping=true",
      "shipFire.pex?loc=35,-115&looping=true",
      "capShipSparks.pex?loc=-10,-15&looping=true",
      "capShipSparks.pex?loc=22,88&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#StarPatrolOne.png"
  },
  subentities = {
    "SPC_0_fighter_module?loc=-50,0",
    "SPC_0_harvester_module?loc=50,0"
  },
  deathfx = {
    "explosionCapitalShipSmoke.pex",
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex",
    "alienExplosionMed.pex?loc=-20,-50",
    "alienExplosionSparksLarge.pex?loc=-20,90",
    "alienExplosionSparksLarge.pex?loc=30,20",
    "alienExplosionSparksLarge.pex?loc=-18,-50",
    "cameraShake?strenth=50,delay=1"
  },
  deathObjs = {
    "StarPatrolOne.atlas.png#deathPart01.png?lifetime=3.5&dir=135&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "StarPatrolOne.atlas.png#deathPart02.png?lifetime=3&dir=60&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "StarPatrolOne.atlas.png#deathPart03.png?lifetime=2.8&dir=-20&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40",
    "StarPatrolOne.atlas.png#deathPart04.png?lifetime=4.5&dir=-100&fxrate=0.25,0.75&fxorigin=-8,-70&fxbounds=30,80"
  },
  warpEffect = "warpOut88.pex?loc=0,-126&looping=true&pri=-1",
  deathSfx = "game_spc_death_01",
  hpBarLarge = true,
  hpBarFlash = true,
  collisionRadius = 170,
  collisionWidth = 60,
  excludeWarpMenu = true
}
_M.SPC_0_fighter = {
  texture = "fighterBasic.atlas.png#ship00.png?rot=-90",
  storeTexture = "fighterBasic.atlas.png#ship00.png",
  collisionRadius = 25,
  weaponLoc = {8, 0},
  weaponFireSfx = "game_fighterlaser_01?volume=0.2",
  weaponFireTexture = "fighterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "fighterWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "fighterImpactSmall.pex",
    high = "fighterImpactLarge.pex",
    bonus = "fighterImpactHigh.pex"
  },
  weaponTexture = "fighterWeaponBasic.atlas.png?anim=projectile",
  weaponFOV = math.cos(45),
  weaponTravelTime = 0.15,
  ribbon = "smallGreenRibbon",
  nitroTexture = "fighterNitro.pex?looping=true",
  deathfx = {
    "fighterExplosionSmall.pex",
    "fighterExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_M.SPC_0_harvester = {
  texture = "harvesterBasic.atlas.png#ship01.png?rot=-90",
  storeTexture = "harvesterBasic.atlas.png#ship01.png",
  collisionRadius = 14,
  ribbon = "smallBlueRibbon",
  nitroTexture = "harvesterNitro.pex?looping=true",
  depositSfx = "game_resourcecollect_01?volume=0.6",
  weaponFireTexture = "harvesterImpactLarge.pex",
  weaponLoc = {18, 0},
  deathfx = {
    "harvesterExplosionSmall.pex",
    "harvesterExplosionSparksSmall.pex"
  },
  deathSfx = "game_miner_destruction_01"
}
_M.SPC_0_cannon = {
  turretTexture = "gunshipTurretBasic.atlas.png#ship01.png",
  weaponFireTexture = "gunshipWeaponBasic.atlas.png?anim=muzzleFlash",
  weaponFireSfx = "game_artillerylaunch_01",
  cannonIcon = "cannonIcon.png",
  weaponLoc = {0, 50}
}
_M.SPC_0_projectile = {
  anim = "gunshipWeaponBasic.atlas.png?anim=projectile&rot=-90",
  weaponImpactTexture = {
    "artilleryImpactRing01.pex",
    "artilleryImpactCenter01.pex"
  },
  targetTypes = PROJECTILE_TARGETS,
  weaponImpactSfx = "game_artillaryimpact_01",
  navPointTexture = "nav_marker.png",
  collisionRadius = 88,
  shieldRadius = 22
}
_cloneup("SPC", 8)
_M.Gunship_Basic_0 = {
  texture = {
    "capShipTrail.pex?loc=0,-40&looping=true",
    "gunshipNobel.atlas.png#ship01.png"
  },
  damageTextures = {
    {
      "gunshipNobel.atlas.png#dmgState02.png",
      "shipFire03.pex?loc= -5,10&looping=true",
      "shipFire04.pex?loc=5,-20&looping=true",
      "shipFire04.pex?loc= -6,-32&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#gunshipNobel.png"
  },
  subentities = {
    "Gunship_Basic_0_cannon?loc=0,0"
  },
  collisionRadius = 66,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "gunshipNobel.atlas.png#deathPart01.png?lifetime=2.5&dir=-10&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "gunshipNobel.atlas.png#deathPart02.png?lifetime=2&dir=160&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut15.pex?loc=0,-40&looping=true&pri=-1"
}
_M.Gunship_Basic_0_cannon = {
  turretTexture = "gunshipTurretBasic.atlas.png#ship01.png",
  weaponFireTexture = "gunshipWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash&loc=22,-31",
  weaponFireSfx = "game_artillerylaunch_01",
  cannonIcon = "cannonIcon.png",
  weaponLoc = {0, 60}
}
_M.Gunship_Basic_0_projectile = {
  anim = "gunshipWeaponBasic.atlas.png?anim=projectile&rot=-90",
  weaponImpactTexture = {
    "artilleryImpactRing01.pex",
    "artilleryImpactCenter01.pex"
  },
  targetTypes = PROJECTILE_TARGETS,
  navPointTexture = "nav_marker.png",
  weaponImpactSfx = "game_artillaryimpact_01",
  collisionRadius = 88,
  shieldRadius = 22
}
_cloneup("Gunship_Basic", 3)
_M.Gunship_Atomic_0 = {
  texture = {
    "capShipTrail.pex?loc=0,-50&looping=true",
    "gunshipAtomic.atlas.png#ship01.png"
  },
  damageTextures = {
    {
      "gunshipAtomic.atlas.png#dmgState02.png",
      "shipFire04.pex?loc= -10,-47&looping=true",
      "shipFire04.pex?loc= 20,-32&looping=true",
      "shipFire02.pex?loc=-5,-20&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#gunshipAtomic.png"
  },
  subentities = {
    "Gunship_Atomic_0_cannon?loc=0,-16",
    "Gunship_Atomic_0_cannon?loc=0,16"
  },
  collisionRadius = 72,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "gunshipAtomic.atlas.png#deathPart01.png?lifetime=2.5&dir=-30&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "gunshipAtomic.atlas.png#deathPart02.png?lifetime=2&dir=-120&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "gunshipAtomic.atlas.png#deathPart03.png?lifetime=2&dir=85&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut15.pex?loc=0,-50&looping=true&pri=-1"
}
_M.Gunship_Atomic_0_cannon = {
  turretTexture = "gunshipTurretBasic.atlas.png#ship01.png",
  weaponFireTexture = "gunshipWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash&loc=22,-31",
  weaponFireSfx = "game_artillerylaunch_01",
  cannonIcon = "cannonIcon.png",
  weaponLoc = {0, 60}
}
_M.Gunship_Atomic_0_projectile = {
  anim = "gunshipWeaponBasic.atlas.png?anim=projectile&rot=-90",
  weaponImpactTexture = {
    "artilleryImpactRing01.pex",
    "artilleryImpactCenter01.pex"
  },
  targetTypes = PROJECTILE_TARGETS,
  navPointTexture = "nav_marker.png",
  collisionRadius = 88,
  shieldRadius = 22
}
_cloneup("Gunship_Atomic", 3)
_M.Gunship_Fission_0 = {
  texture = {
    "capShipTrail.pex?loc=41,-58&looping=true",
    "capShipTrail.pex?loc=1,-94&looping=true",
    "capShipTrail.pex?loc=-40,-58&looping=true",
    "gunshipAssault.atlas.png#ship01.png"
  },
  damageTextures = {
    {
      "gunshipAssault.atlas.png#dmgState02.png",
      "shipFire04.pex?loc= -10,-47&looping=true",
      "shipFire.pex?loc=52,-12&looping=true",
      "shipFire.pex?loc=-52,-12&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#gunshipAssault.png"
  },
  subentities = {
    "Gunship_Fission_0_cannon?loc=20,24",
    "Gunship_Fission_0_cannon?loc=-20,24",
    "Gunship_Fission_0_cannon?loc=0,-44"
  },
  collisionRadius = 72,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "gunshipAssault.atlas.png#deathPart01.png?lifetime=2.5&dir=352&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "gunshipAssault.atlas.png#deathPart02.png?lifetime=2&dir=-120&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "gunshipAssault.atlas.png#deathPart03.png?lifetime=2&dir=52&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut15.pex?loc=0,-50&looping=true&pri=-1"
}
_M.Gunship_Fission_0_cannon = {
  turretTexture = "gunshipAssault.atlas.png#turret01.png",
  weaponFireTexture = "gunshipWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash&loc=22,-31",
  weaponFireSfx = "game_artillerylaunch_01",
  cannonIcon = "cannonIcon.png",
  weaponLoc = {0, 60}
}
_M.Gunship_Fission_0_projectile = {
  anim = "gunshipWeaponBasic.atlas.png?anim=projectile&rot=-90",
  weaponImpactTexture = {
    "artilleryImpactRing01.pex",
    "artilleryImpactCenter01.pex"
  },
  targetTypes = PROJECTILE_TARGETS,
  navPointTexture = "nav_marker.png",
  collisionRadius = 88,
  shieldRadius = 22
}
_cloneup("Gunship_Fission", 3)
_M.Gunship_Tesla_0 = {
  texture = {
    "gunshipTesla.atlas.png#ship01.png",
    "invisible.png?loc=0,-48&pri=-1"
  },
  damageTextures = {
    {
      "gunshipTesla.atlas.png#dmgState02.png",
      "shipFire02.pex?loc= -10,-47&looping=true",
      "shipFire02.pex?loc=5,-20&looping=true",
      "shipFire04.pex?loc= -6,-32&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#gunshipTesla.png"
  },
  subentities = {
    "Gunship_Tesla_0_cannon?loc=0,0"
  },
  collisionRadius = 87,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "gunshipTesla.atlas.png#deathPart01.png?lifetime=2.5&dir=-35&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "gunshipTesla.atlas.png#deathPart02.png?lifetime=2&dir=160&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "gunshipTesla.atlas.png#deathPart03.png?lifetime=1.8&dir=110&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut40.pex?loc=0,-40&looping=true&pri=-1"
}
_M.Gunship_Tesla_0_cannon = {
  turretTexture = "gunshipTesla.atlas.png#shipTurret01.png",
  teslaParticleTexture = "lineofdeath.lua?looping=true",
  teslaMuzzleFlash = "LODmuzzleFlash.pex?looping=true",
  teslaFireEnd = "LODtermination.pex?looping=true",
  tesslaMuzzleFlashPos = 50,
  weaponFireTexture = "gunshipWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash&loc=22,-31",
  weaponTexture = "lineofdeath.png",
  weaponFireSfx = "uiUnavailable",
  cannonIcon = "cannonIcon.png",
  collisionRadius = 40,
  chargeTime = 0.8,
  fireUpTime = 0.1,
  weaponLoc = {0, 60}
}
_M.Gunship_Tesla_0_projectile = {
  anim = "gunshipWeaponBasic.atlas.png?anim=projectile&rot=-90",
  weaponImpactTexture = "artilleryImpactRing01.pex",
  targetTypes = PROJECTILE_TARGETS,
  navPointTexture = "nav_marker.png",
  collisionRadius = 88,
  shieldRadius = 22
}
_cloneup("Gunship_Tesla", 3)
_M.Fighter_Basic_0 = {
  texture = {
    "capShipTrail.pex?loc=-17,-78&looping=true",
    "capShipTrail.pex?loc=3,-78&looping=true",
    "fighterCarrierPatrol.atlas.png#ship01.png"
  },
  damageTextures = {
    {
      "fighterCarrierPatrol.atlas.png#dmgState02.png",
      "shipFire03.pex?loc= -20,-77&looping=true",
      "shipFire.pex?loc=42,-19&looping=true",
      "shipFire04.pex?loc=-15,-50&looping=true",
      "shipFire04.pex?loc= -20,-77&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#fighterCarrierPatrol.png"
  },
  subentities = {
    "Fighter_Basic_0_fighter_module?loc=0,0"
  },
  collisionRadius = 88,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "fighterCarrierPatrol.atlas.png#deathPart01.png?lifetime=2.5&dir=-110&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "fighterCarrierPatrol.atlas.png#deathPart02.png?lifetime=2&dir=25&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "fighterCarrierPatrol.atlas.png#deathPart03.png?lifetime=1.8&dir=120&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut40.pex?loc=-8,-78&looping=true&pri=-1"
}
_M.Fighter_Basic_0_fighter = {
  texture = "fighterBasic.atlas.png#ship00.png?rot=-90",
  storeTexture = "fighterBasic.atlas.png#ship00.png",
  collisionRadius = 25,
  weaponLoc = {18, 0},
  weaponFireSfx = "game_fighterlaser_01?volume=0.2",
  weaponFireTexture = "fighterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "fighterWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "fighterImpactSmall.pex",
    high = "fighterImpactLarge.pex",
    bonus = "fighterImpactHigh.pex"
  },
  weaponTexture = "fighterWeaponBasic.atlas.png?anim=projectile",
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ribbon = "smallGreenRibbon",
  nitroTexture = "fighterNitro.pex?looping=true",
  deathfx = {
    "fighterExplosionSmall.pex",
    "fighterExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_cloneup("Fighter_Basic", 6)
_M.Fighter_Yam_0 = {
  texture = {
    "capShipTrail.pex?loc=-7,-80&looping=true",
    "capShipTrail.pex?loc=20,-100&looping=true",
    "capShipTrail.pex?loc=-25,-100&looping=true",
    "fighterCarrierYam.atlas.png#ship01.png"
  },
  damageTextures = {
    {
      "fighterCarrierYam.atlas.png#dmgState02.png",
      "shipFire02.pex?loc= -20,-77&looping=true",
      "shipFire02.pex?loc=25,-30&looping=true",
      "shipFire02.pex?loc=25,-48&looping=true",
      "shipFire04.pex?loc=10,30&looping=true",
      "shipFire04.pex?loc= -20,-77&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#fighterCarrierYam.png"
  },
  subentities = {
    "Fighter_Yam_0_fighter_module?loc=0,0"
  },
  collisionRadius = 100,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "fighterCarrierYam.atlas.png#deathPart01.png?lifetime=2.5&dir=-150&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "fighterCarrierYam.atlas.png#deathPart02.png?lifetime=2&dir=45&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut60.pex?loc=0,-80&looping=true&pri=-1"
}
_M.Fighter_Yam_0_fighter = {
  texture = "fighterCarrierYam.atlas.png#fighter01.png?rot=-90",
  storeTexture = "fighterCarrierYam.atlas.png#fighter01.png",
  collisionRadius = 25,
  weaponLoc = {18, 0},
  weaponFireSfx = "game_fighterlaser_01?volume=0.2",
  weaponFireTexture = "fighterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "fighterWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "fighterImpactSmall.pex",
    high = "fighterImpactLarge.pex",
    bonus = "fighterImpactHigh.pex"
  },
  weaponTexture = "fighterWeaponBasic.atlas.png?anim=projectile",
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ribbon = "smallGreenRibbon",
  nitroTexture = "fighterNitro.pex?looping=true",
  deathfx = {
    "fighterExplosionSmall.pex",
    "fighterExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_cloneup("Fighter_Yam", 6)
_M.Fighter_Dragon_0 = {
  texture = {
    "fighterCarrierDragon.atlas.png#ship01.png",
    "capShipTrail.pex?loc=0,-90&looping=true",
    "capShipTrail.pex?loc=31,-85&looping=true",
    "capShipTrail.pex?loc=-31,-85&looping=true"
  },
  damageTextures = {
    {
      "fighterCarrierDragon.atlas.png#dmgState02.png",
      "shipFire.pex?loc=23,-25&looping=true&pri=15",
      "shipFire.pex?loc=38,-15&looping=true&pri=15",
      "shipFire04.pex?loc=-15,-45&looping=true&pri=15",
      "shipFire04.pex?loc= 20,-77&looping=true&pri=15"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#fighterCarrierDragon.png"
  },
  subentities = {
    "Fighter_Dragon_0_fighter_module?loc=0,0"
  },
  collisionRadius = 100,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "fighterCarrierDragon.atlas.png#deathPart01.png?lifetime=2.5&dir=-10&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "fighterCarrierDragon.atlas.png#deathPart02.png?lifetime=2&dir=150&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut60.pex?loc=0,-85&looping=true&pri=-1"
}
_M.Fighter_Dragon_0_fighter = {
  texture = "fighterCarrierDragon.atlas.png#fighter01.png?rot=-90",
  storeTexture = "fighterCarrierDragon.atlas.png#fighter01.png",
  collisionRadius = 25,
  weaponLoc = {18, 0},
  weaponFireSfx = "game_fighterlaser_01?volume=0.2",
  weaponFireTexture = "fighterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "fighterWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "fighterImpactSmall.pex",
    high = "fighterImpactLarge.pex",
    bonus = "fighterImpactHigh.pex"
  },
  weaponTexture = "fighterWeaponBasic.atlas.png?anim=projectile",
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ribbon = "smallGreenRibbon",
  nitroTexture = "fighterNitro.pex?looping=true",
  deathfx = {
    "fighterExplosionSmall.pex",
    "fighterExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_cloneup("Fighter_Dragon", 6)
_M.Fighter_Halberd_0 = {
  texture = {
    "fighterCarrierAssault.atlas.png#ship01.png",
    "capShipTrail.pex?loc=1,-90&looping=true",
    "capShipTrail.pex?loc=36,-95&looping=true",
    "capShipTrail.pex?loc=-35,-95&looping=true"
  },
  damageTextures = {
    {
      "fighterCarrierAssault.atlas.png#dmgState02.png",
      "shipFire.pex?loc=-42,14&looping=true&pri=15",
      "shipFire02.pex?loc=-3,-11&looping=true&pri=15",
      "shipFire04.pex?loc=10,-63&looping=true&pri=15",
      "shipFire.pex?loc=50,28&looping=true&pri=15"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#fighterCarrierAssault.png"
  },
  subentities = {
    "Fighter_Halberd_0_fighter_module?loc=0,0"
  },
  collisionRadius = 100,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "fighterCarrierAssault.atlas.png#deathPart01.png?lifetime=2.5&dir=-10&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "fighterCarrierAssault.atlas.png#deathPart02.png?lifetime=2&dir=150&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "fighterCarrierAssault.atlas.png#deathPart03.png?lifetime=2&dir=300&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut60.pex?loc=0,-85&looping=true&pri=-1"
}
_M.Fighter_Halberd_0_fighter = {
  texture = "fighterCarrierAssault.atlas.png#fighter01.png?rot=-90",
  storeTexture = "fighterCarrierAssault.atlas.png#fighter01.png",
  collisionRadius = 25,
  weaponLoc = {18, 0},
  weaponFireSfx = "game_fighterlaser_01?volume=0.2",
  weaponFireTexture = "fighterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "fighterWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "fighterImpactSmall.pex",
    high = "fighterImpactLarge.pex",
    bonus = "fighterImpactHigh.pex"
  },
  weaponTexture = "fighterWeaponBasic.atlas.png?anim=projectile",
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ribbon = "smallGreenRibbon",
  nitroTexture = "fighterNitro.pex?looping=true",
  deathfx = {
    "fighterExplosionSmall.pex",
    "fighterExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_cloneup("Fighter_Halberd", 6)
_M.Fighter_Shogun_0 = {
  texture = {
    "fighterCarrierAssaultAdv.atlas.png#ship01.png",
    "capShipTrail.pex?loc=-48,-60&looping=true",
    "capShipTrail.pex?loc=12,-105&looping=true",
    "capShipTrail.pex?loc=-11,-105&looping=true",
    "capShipTrail.pex?loc=48,-60&looping=true"
  },
  damageTextures = {
    {
      "fighterCarrierAssaultAdv.atlas.png#dmgState02.png",
      "shipFire.pex?loc=-50,-36&looping=true&pri=15",
      "shipFire02.pex?loc=49,-9&looping=true&pri=15",
      "shipFire.pex?loc=15,-69&looping=true&pri=15",
      "shipFire.pex?loc=60,-35&looping=true&pri=15"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#fighterCarrierAssaultAdv.png"
  },
  subentities = {
    "Fighter_Shogun_0_fighter_module?loc=0,0"
  },
  collisionRadius = 100,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "fighterCarrierAssaultAdv.atlas.png#deathPart01.png?lifetime=2.5&dir=-10&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "fighterCarrierAssaultAdv.atlas.png#deathPart02.png?lifetime=2&dir=64&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "fighterCarrierAssaultAdv.atlas.png#deathPart03.png?lifetime=2&dir=150&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut60.pex?loc=0,-85&looping=true&pri=-1"
}
_M.Fighter_Shogun_0_fighter = {
  texture = "fighterCarrierAssaultAdv.atlas.png#fighter01.png?rot=-90",
  storeTexture = "fighterCarrierAssaultAdv.atlas.png#fighter01.png",
  collisionRadius = 25,
  weaponLoc = {18, 0},
  weaponFireSfx = "game_fighterlaser_01?volume=0.2",
  weaponFireTexture = "fighterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "fighterWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "fighterImpactSmall.pex",
    high = "fighterImpactLarge.pex",
    bonus = "fighterImpactHigh.pex"
  },
  weaponTexture = "fighterWeaponBasic.atlas.png?anim=projectile",
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ribbon = "smallGreenRibbon",
  nitroTexture = "fighterNitro.pex?looping=true",
  deathfx = {
    "fighterExplosionSmall.pex",
    "fighterExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_cloneup("Fighter_Shogun", 6)
_M.Anti_Bomber_0 = {
  texture = {
    "capShipTrail.pex?loc=-22,-64&looping=true",
    "antiBomberCarrierHornet.atlas.png#ship01.png"
  },
  damageTextures = {
    {
      "antiBomberCarrierHornet.atlas.png#dmgState02.png",
      "shipFire.pex?loc=42,-19&looping=true",
      "shipFire04.pex?loc=-15, 30&looping=true",
      "shipFire.pex?loc=-17, 25&looping=true",
      "shipFire04.pex?loc= -20,-60&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#antiBomberCarrierHornet.png"
  },
  subentities = {
    "Anti_Bomber_0_fighter_module?loc=0,0"
  },
  collisionRadius = 88,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "antiBomberCarrierHornet.atlas.png#deathPart01.png?lifetime=2.5&dir=10&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "antiBomberCarrierHornet.atlas.png#deathPart02.png?lifetime=2&dir=80&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "antiBomberCarrierHornet.atlas.png#deathPart03.png?lifetime=1.8&dir=-150&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut15.pex?loc=-22,-64&looping=true&pri=-1"
}
_M.Anti_Bomber_0_fighter = {
  texture = "antiBomberBasic.atlas.png#ship00.png?rot=-90",
  storeTexture = "antiBomberBasic.atlas.png#ship00.png",
  collisionRadius = 25,
  weaponLoc = {10, 0},
  weaponFireSfx = "playerinterceptor?volume=0.6",
  weaponFireTexture = "antiBomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "antiBomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "antiBomberImpactSmall.pex",
    high = "antiBomberImpactLarge.pex",
    bonus = "antiBomberImpactHigh.pex"
  },
  weaponTexture = "antiBomberWeaponBasic.atlas.png?anim=projectile",
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(15),
  ribbon = "smallYellowRibbon",
  nitroTexture = "antiBomberNitro.pex?looping=true",
  deathfx = {
    "antiBomberExplosionSmall.pex",
    "antiBomberExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_cloneup("Anti_Bomber", 6)
_M.Anti_Bomb_Condor_0 = {
  texture = {
    "capShipTrail.pex?loc=-0,-85&looping=true",
    "antiBomberCarrierCondor.atlas.png#ship01.png"
  },
  damageTextures = {
    {
      "antiBomberCarrierCondor.atlas.png#dmgState02.png",
      "shipFire.pex?loc= -28,45&looping=true",
      "shipFire02.pex?loc=49,-19&looping=true",
      "shipFire02.pex?loc=-8,-64&looping=true",
      "shipFire04.pex?loc= -20,-40&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#antiBomberCarrierCondor.png"
  },
  subentities = {
    "Anti_Bomb_Condor_0_fighter_module?loc=0,0"
  },
  collisionRadius = 88,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "antiBomberCarrierCondor.atlas.png#deathPart01.png?lifetime=2.5&dir=45&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "antiBomberCarrierCondor.atlas.png#deathPart02.png?lifetime=2&dir=190&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "antiBomberCarrierCondor.atlas.png#deathPart03.png?lifetime=1.8&dir=-70&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut60.pex?loc=0,-85&looping=true&pri=-1"
}
_M.Anti_Bomb_Condor_0_fighter = {
  texture = "antiBomberCarrierCondor.atlas.png#fighter01.png?rot=-90",
  storeTexture = "antiBomberCarrierCondor.atlas.png#fighter01.png",
  collisionRadius = 25,
  weaponLoc = {10, 0},
  weaponFireSfx = "playerinterceptor?volume=0.6",
  weaponFireTexture = "antiBomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "antiBomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "antiBomberImpactSmall.pex",
    high = "antiBomberImpactLarge.pex",
    bonus = "antiBomberImpactHigh.pex"
  },
  weaponTexture = "antiBomberWeaponBasic.atlas.png?anim=projectile",
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(15),
  ribbon = "smallYellowRibbon",
  nitroTexture = "antiBomberNitro.pex?looping=true",
  deathfx = {
    "antiBomberExplosionSmall.pex",
    "antiBomberExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_cloneup("Anti_Bomb_Condor", 6)
_M.Anti_Bomb_Falcon_0 = {
  texture = {
    "capShipTrail.pex?loc=-10,-64&looping=true",
    "capShipTrail.pex?loc=10,-64&looping=true",
    "antiBomberCarrierFalcon.atlas.png#ship01.png"
  },
  damageTextures = {
    {
      "antiBomberCarrierFalcon.atlas.png#dmgState02.png",
      "shipFire02.pex?loc= -23,60&looping=true",
      "shipFire.pex?loc=26,20&looping=true",
      "shipFire04.pex?loc=-32,-43&looping=true",
      "shipFire04.pex?loc=18,-18&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#antiBomberCarrierFalcon.png"
  },
  subentities = {
    "Anti_Bomb_Falcon_0_fighter_module?loc=0,0"
  },
  collisionRadius = 94,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "antiBomberCarrierFalcon.atlas.png#deathPart01.png?lifetime=2.5&dir=30&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "antiBomberCarrierFalcon.atlas.png#deathPart02.png?lifetime=2&dir=170&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "antiBomberCarrierFalcon.atlas.png#deathPart03.png?lifetime=1.8&dir=120&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut88.pex?loc=0,-64&looping=true&pri=-1"
}
_M.Anti_Bomb_Falcon_0_fighter = {
  texture = "antiBomberCarrierFalcon.atlas.png#fighter01.png?rot=-90",
  storeTexture = "antiBomberCarrierFalcon.atlas.png#fighter01.png",
  collisionRadius = 25,
  weaponLoc = {10, 0},
  weaponFireSfx = "playerinterceptor?volume=0.6",
  weaponFireTexture = "antiBomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "antiBomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "antiBomberImpactSmall.pex",
    high = "antiBomberImpactLarge.pex",
    bonus = "antiBomberImpactHigh.pex"
  },
  weaponTexture = "antiBomberWeaponBasic.atlas.png?anim=projectile",
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(15),
  ribbon = "smallYellowRibbon",
  nitroTexture = "antiBomberNitro.pex?looping=true",
  deathfx = {
    "antiBomberExplosionSmall.pex",
    "antiBomberExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_cloneup("Anti_Bomb_Falcon", 6)
_M.Anti_Bomb_Eagle_0 = {
  texture = {
    "capShipTrail.pex?loc=-43,-90&looping=true",
    "capShipTrail.pex?loc=43,-90&looping=true",
    "antiBomberCarrierAssault.atlas.png#ship01.png"
  },
  damageTextures = {
    {
      "antiBomberCarrierAssault.atlas.png#dmgState02.png",
      "shipFire.pex?loc=-6,-52&looping=true",
      "shipFire02.pex?loc= -23,60&looping=true",
      "shipFire04.pex?loc=-32,-43&looping=true",
      "shipFire.pex?loc=46,-46&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#antiBomberCarrierAssault.png"
  },
  subentities = {
    "Anti_Bomb_Eagle_0_fighter_module?loc=0,0"
  },
  collisionRadius = 94,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "antiBomberCarrierAssault.atlas.png#deathPart01.png?lifetime=2.5&dir=210&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "antiBomberCarrierAssault.atlas.png#deathPart02.png?lifetime=2&dir=90&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "antiBomberCarrierAssault.atlas.png#deathPart03.png?lifetime=1.8&dir=358&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut88.pex?loc=0,-64&looping=true&pri=-1"
}
_M.Anti_Bomb_Eagle_0_fighter = {
  texture = "antiBomberCarrierAssault.atlas.png#fighter01.png?rot=-90",
  storeTexture = "antiBomberCarrierAssault.atlas.png#fighter01.png",
  collisionRadius = 25,
  weaponLoc = {10, 0},
  weaponFireSfx = "playerinterceptor?volume=0.6",
  weaponFireTexture = "antiBomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "antiBomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "antiBomberImpactSmall.pex",
    high = "antiBomberImpactLarge.pex",
    bonus = "antiBomberImpactHigh.pex"
  },
  weaponTexture = "antiBomberWeaponBasic.atlas.png?anim=projectile",
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(15),
  ribbon = "smallYellowRibbon",
  nitroTexture = "antiBomberNitro.pex?looping=true",
  deathfx = {
    "antiBomberExplosionSmall.pex",
    "antiBomberExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_cloneup("Anti_Bomb_Eagle", 6)
_M.Anti_Bomb_Tyton_0 = {
  texture = {
    "capShipTrail.pex?loc=-43,-90&looping=true",
    "capShipTrail.pex?loc=22,-95&looping=true",
    "capShipTrail.pex?loc=0,-90&looping=true",
    "capShipTrail.pex?loc=-22,-95&looping=true",
    "capShipTrail.pex?loc=43,-90&looping=true",
    "antiBomberCarrierAssaultAdv.atlas.png#ship01.png"
  },
  damageTextures = {
    {
      "antiBomberCarrierAssaultAdv.atlas.png#dmgState02.png",
      "shipFire.pex?loc=-46,-59&looping=true",
      "shipFire02.pex?loc=-33,60&looping=true",
      "shipFire.pex?loc=26,60&looping=true",
      "shipFire04.pex?loc=-9,-40&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#antiBomberCarrierAssaultAdv.png"
  },
  subentities = {
    "Anti_Bomb_Tyton_0_fighter_module?loc=0,0"
  },
  collisionRadius = 94,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "antiBomberCarrierAssaultAdv.atlas.png#deathPart01.png?lifetime=2.5&dir=30&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "antiBomberCarrierAssaultAdv.atlas.png#deathPart02.png?lifetime=2&dir=170&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "antiBomberCarrierAssaultAdv.atlas.png#deathPart03.png?lifetime=1.8&dir=120&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut88.pex?loc=0,-64&looping=true&pri=-1"
}
_M.Anti_Bomb_Tyton_0_fighter = {
  texture = "antiBomberCarrierAssaultAdv.atlas.png#fighter01.png?rot=-90",
  storeTexture = "antiBomberCarrierAssaultAdv.atlas.png#fighter01.png",
  collisionRadius = 25,
  weaponLoc = {10, 0},
  weaponFireSfx = "playerinterceptor?volume=0.6",
  weaponFireTexture = "antiBomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "antiBomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "antiBomberImpactSmall.pex",
    high = "antiBomberImpactLarge.pex",
    bonus = "antiBomberImpactHigh.pex"
  },
  weaponTexture = "antiBomberWeaponBasic.atlas.png?anim=projectile",
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(15),
  ribbon = "smallYellowRibbon",
  nitroTexture = "antiBomberNitro.pex?looping=true",
  deathfx = {
    "antiBomberExplosionSmall.pex",
    "antiBomberExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_cloneup("Anti_Bomb_Tyton", 6)
_M.Bomber_Vickers_0 = {
  texture = {
    "capShipTrail.pex?loc=10,-65&looping=true",
    "capShipTrail.pex?loc=-10,-65&looping=true",
    "bomberCarrierVickers.atlas.png#ship01.png"
  },
  damageTextures = {
    {
      "bomberCarrierVickers.atlas.png#dmgState02.png",
      "shipFire.pex?loc=-20,14&looping=true",
      "shipFire.pex?loc=42,-19&looping=true",
      "shipFire04.pex?loc=-19,-35&looping=true",
      "shipFire04.pex?loc= 39,15&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#bomberCarrierVickers.png"
  },
  subentities = {
    "Bomber_Vickers_0_fighter_module?loc=0,0"
  },
  collisionRadius = 74,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "bomberCarrierVickers.atlas.png#deathPart01.png?lifetime=2.5&dir=15&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "bomberCarrierVickers.atlas.png#deathPart02.png?lifetime=2&dir=-150&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "bomberCarrierVickers.atlas.png#deathPart03.png?lifetime=1.8&dir=100&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut60.pex?loc=0,-65&looping=true&pri=-1"
}
_M.Bomber_Vickers_0_fighter = {
  texture = "bomberCarrierVickers.atlas.png#bomber01.png?rot=-90",
  storeTexture = "bomberCarrierVickers.atlas.png#bomber01.png",
  collisionRadius = 30,
  weaponLoc = {18, 0},
  weaponFireSfx = "game_fighterlaser_01",
  weaponFireTexture = "bomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "bomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "bomberImpactSmall.pex",
    high = {
      "bomberImpact01.pex",
      "bomberImpact02.pex",
      "bomberImpact03.pex"
    },
    bonus = "bomberImpactHigh.pex"
  },
  weaponTexture = "bomberWeaponBasic.atlas.png?anim=projectile",
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ribbon = "smallGoldRibbon?loc=-18,0",
  nitroTexture = "bomberNitro.pex?looping=true",
  deathfx = {
    "bomberExplosion01.pex",
    "bomberExplosion02.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_cloneup("Bomber_Vickers", 6)
_M.Bomber_Staaken_0 = {
  texture = {
    "capShipTrail.pex?loc=13,-70&looping=true",
    "capShipTrail.pex?loc=-13,-70&looping=true",
    "bomberCarrierStaaken.atlas.png#ship01.png"
  },
  damageTextures = {
    {
      "bomberCarrierStaaken.atlas.png#dmgState02.png",
      "shipFire02.pex?loc= -20,-55&looping=true",
      "shipFire.pex?loc=-53,8&looping=true",
      "shipFire.pex?loc=-15,-50&looping=true",
      "shipFire04.pex?loc= -15,57&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#bomberCarrierStaaken.png"
  },
  subentities = {
    "Bomber_Staaken_0_fighter_module?loc=0,0"
  },
  collisionRadius = 86,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "bomberCarrierStaaken.atlas.png#deathPart01.png?lifetime=2.5&dir=-15&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "bomberCarrierStaaken.atlas.png#deathPart02.png?lifetime=2&dir=-130&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "bomberCarrierStaaken.atlas.png#deathPart03.png?lifetime=1.8&dir=120&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut60.pex?loc=0,-70&looping=true&pri=-1"
}
_M.Bomber_Staaken_0_fighter = {
  texture = "bomberCarrierStaaken.atlas.png#bomber01.png?rot=-90",
  storeTexture = "bomberCarrierStaaken.atlas.png#bomber01.png",
  collisionRadius = 35,
  weaponLoc = {18, 0},
  weaponFireSfx = "playerbomber?volume=0.6",
  weaponFireTexture = "bomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "bomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "bomberImpactSmall.pex",
    high = {
      "bomberImpact01.pex",
      "bomberImpact02.pex",
      "bomberImpact03.pex"
    },
    bonus = "bomberImpactHigh.pex"
  },
  weaponTexture = "bomberWeaponBasic.atlas.png?anim=projectile",
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ribbon = "smallGoldRibbon?loc=-18,0",
  nitroTexture = "bomberNitro.pex?looping=true",
  deathfx = {
    "bomberExplosion01.pex",
    "bomberExplosion02.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_cloneup("Bomber_Staaken", 6)
_M.Bomber_Blackburn_0 = {
  texture = {
    "capShipTrail.pex?loc=10,-70&looping=true",
    "capShipTrail.pex?loc=-10,-70&looping=true",
    "bomberCarrierBlackburn.atlas.png#ship01.png"
  },
  damageTextures = {
    {
      "bomberCarrierBlackburn.atlas.png#dmgState02.png",
      "shipFire.pex?loc= 24,-20&looping=true",
      "shipFire04.pex?loc=42,-19&looping=true",
      "shipFire.pex?loc=19,32&looping=true",
      "shipFire04.pex?loc= -20,40&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#bomberCarrierBlackburn.png"
  },
  subentities = {
    "Bomber_Blackburn_0_fighter_module?loc=0,0"
  },
  collisionRadius = 86,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "bomberCarrierBlackburn.atlas.png#deathPart01.png?lifetime=2.5&dir=-20&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "bomberCarrierBlackburn.atlas.png#deathPart02.png?lifetime=2&dir=170&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "bomberCarrierBlackburn.atlas.png#deathPart03.png?lifetime=1.8&dir=180&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut60.pex?loc=0,-70&looping=true&pri=-1"
}
_M.Bomber_Blackburn_0_fighter = {
  texture = "bomberCarrierBlackburn.atlas.png#bomber01.png?rot=-90",
  storeTexture = "bomberCarrierBlackburn.atlas.png#bomber01.png",
  collisionRadius = 35,
  weaponLoc = {18, 0},
  weaponFireSfx = "game_fighterlaser_01?volume=0.2",
  weaponFireTexture = "bomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "bomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "bomberImpactSmall.pex",
    high = {
      "bomberImpact01.pex",
      "bomberImpact02.pex",
      "bomberImpact03.pex"
    },
    bonus = "bomberImpactHigh.pex"
  },
  weaponTexture = "bomberWeaponBasic.atlas.png?anim=projectile",
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ribbon = "smallGoldRibbon?loc=-18,0",
  nitroTexture = "bomberNitro.pex?looping=true",
  deathfx = {
    "bomberExplosion01.pex",
    "bomberExplosion02.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_cloneup("Bomber_Blackburn", 6)
_M.Bomber_Abel_0 = {
  texture = {
    "capShipTrail.pex?loc=-34,-68&looping=true",
    "capShipTrail.pex?loc=10,-70&looping=true",
    "capShipTrail.pex?loc=-10,-70&looping=true",
    "capShipTrail.pex?loc=34,-68&looping=true",
    "bomberCarrierAssault.atlas.png#ship01.png"
  },
  damageTextures = {
    {
      "bomberCarrierAssault.atlas.png#dmgState02.png",
      "shipFire.pex?loc= 24,-20&looping=true",
      "shipFire04.pex?loc=42,-19&looping=true",
      "shipFire.pex?loc=19,32&looping=true",
      "shipFire04.pex?loc= -20,40&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#bomberCarrierAssault.png"
  },
  subentities = {
    "Bomber_Abel_0_fighter_module?loc=0,0"
  },
  collisionRadius = 86,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "bomberCarrierAssault.atlas.png#deathPart01.png?lifetime=2.5&dir=-20&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "bomberCarrierAssault.atlas.png#deathPart02.png?lifetime=2&dir=195&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "bomberCarrierAssault.atlas.png#deathPart03.png?lifetime=1.8&dir=94&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut60.pex?loc=0,-70&looping=true&pri=-1"
}
_M.Bomber_Abel_0_fighter = {
  texture = "bomberCarrierAssault.atlas.png#bomber01.png?rot=-90",
  storeTexture = "bomberCarrierAssault.atlas.png#bomber01.png",
  collisionRadius = 35,
  weaponLoc = {18, 0},
  weaponFireSfx = "game_fighterlaser_01?volume=0.2",
  weaponFireTexture = "bomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "bomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "bomberImpactSmall.pex",
    high = {
      "bomberImpact01.pex",
      "bomberImpact02.pex",
      "bomberImpact03.pex"
    },
    bonus = "bomberImpactHigh.pex"
  },
  weaponTexture = "bomberWeaponBasic.atlas.png?anim=projectile",
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ribbon = "smallGoldRibbon?loc=-18,0",
  nitroTexture = "bomberNitro.pex?looping=true",
  deathfx = {
    "bomberExplosion01.pex",
    "bomberExplosion02.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_cloneup("Bomber_Abel", 6)
_M.Bomber_Cain_0 = {
  texture = {
    "capShipTrail.pex?loc=-34,-78&looping=true",
    "capShipTrail.pex?loc=10,-80&looping=true",
    "capShipTrail.pex?loc=-10,-80&looping=true",
    "capShipTrail.pex?loc=35,-78&looping=true",
    "bomberCarrierAssaultAdv.atlas.png#ship01.png"
  },
  damageTextures = {
    {
      "bomberCarrierAssaultAdv.atlas.png#dmgState02.png",
      "shipFire.pex?loc= 24,-20&looping=true",
      "shipFire04.pex?loc=42,-19&looping=true",
      "shipFire.pex?loc=19,32&looping=true",
      "shipFire04.pex?loc= -20,40&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#bomberCarrierAssaultAdv.png"
  },
  subentities = {
    "Bomber_Cain_0_fighter_module?loc=0,0"
  },
  collisionRadius = 86,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "bomberCarrierAssaultAdv.atlas.png#deathPart01.png?lifetime=2.5&dir=-20&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "bomberCarrierAssaultAdv.atlas.png#deathPart02.png?lifetime=2&dir=170&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "bomberCarrierAssaultAdv.atlas.png#deathPart03.png?lifetime=1.8&dir=180&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut60.pex?loc=0,-70&looping=true&pri=-1"
}
_M.Bomber_Cain_0_fighter = {
  texture = "bomberCarrierAssaultAdv.atlas.png#bomber01.png?rot=-90",
  storeTexture = "bomberCarrierAssaultAdv.atlas.png#bomber01.png",
  collisionRadius = 35,
  weaponLoc = {18, 0},
  weaponFireSfx = "game_fighterlaser_01?volume=0.2",
  weaponFireTexture = "bomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponImpactTextureLo = "bomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = {
    low = "bomberImpactSmall.pex",
    high = {
      "bomberImpact01.pex",
      "bomberImpact02.pex",
      "bomberImpact03.pex"
    },
    bonus = "bomberImpactHigh.pex"
  },
  weaponTexture = "bomberWeaponBasic.atlas.png?anim=projectile",
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ribbon = "smallGoldRibbon?loc=-18,0",
  nitroTexture = "bomberNitro.pex?looping=true",
  deathfx = {
    "bomberExplosion01.pex",
    "bomberExplosion02.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_cloneup("Bomber_Cain", 6)
_M.Mining_Basic_0 = {
  texture = {
    "capShipTrail.pex?loc=-23,-62&looping=true",
    "capShipTrail.pex?loc=23,-62&looping=true",
    "harvesterCarrierBoring.atlas.png#ship01.png",
    "StarPatrolOne.atlas.png?loc=-34,-44&anim=runningLightGold",
    "StarPatrolOne.atlas.png?loc=34,-44&anim=runningLightGold"
  },
  damageTextures = {
    {
      "harvesterCarrierBoring.atlas.png#dmgState02.png",
      "shipFire03.pex?loc= 8,55&looping=true",
      "shipFire.pex?loc=10,15&looping=true",
      "shipFire04.pex?loc=-10,-50&looping=true",
      "shipFire04.pex?loc= 8,55&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#harvesterCarrierBoring.png"
  },
  subentities = {
    "Mining_Basic_0_harvester_module?loc=0,0"
  },
  collisionRadius = 88,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "harvesterCarrierBoring.atlas.png#deathPart01.png?lifetime=2.5&dir=80&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "harvesterCarrierBoring.atlas.png#deathPart02.png?lifetime=2&dir=-90&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "harvesterCarrierBoring.atlas.png#deathPart03.png?lifetime=1.8&dir=160&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut60.pex?loc=0,-62&looping=true&pri=-1"
}
_M.Mining_Basic_0_harvester = {
  texture = "harvesterBasic.atlas.png#ship01.png?rot=-90",
  storeTexture = "harvesterBasic.atlas.png#ship01.png",
  collisionRadius = 14,
  ribbon = "smallBlueRibbon",
  nitroTexture = "harvesterNitro.pex?looping=true",
  depositSfx = "game_resourcecollect_01?volume=0.6",
  weaponFireTexture = "harvesterImpactLarge.pex",
  weaponLoc = {18, 0},
  deathfx = {
    "harvesterExplosionSmall.pex",
    "harvesterExplosionSparksSmall.pex"
  },
  deathSfx = "game_rr_destruction_01"
}
_cloneup("Mining_Basic", 6)
_M.Mining_Newcastle_0 = {
  texture = {
    "capShipTrail.pex?loc=10,-63&looping=true",
    "capShipTrail.pex?loc=-10,-63&looping=true",
    "capShipTrail.pex?loc=-23,-63&looping=true",
    "capShipTrail.pex?loc=23,-63&looping=true",
    "capShipTrail.pex?loc=-38,-63&looping=true",
    "capShipTrail.pex?loc=38,-63&looping=true",
    "harvesterCarrierNewcastle.atlas.png#ship01.png",
    "StarPatrolOne.atlas.png?loc=-34,-44&anim=runningLightGold",
    "StarPatrolOne.atlas.png?loc=34,-44&anim=runningLightGold"
  },
  damageTextures = {
    {
      "harvesterCarrierNewcastle.atlas.png#dmgState02.png",
      "shipFire.pex?loc= 12,69&looping=true",
      "shipFire.pex?loc= -30,38&looping=true",
      "shipFire.pex?loc=10,45&looping=true",
      "shipFire04.pex?loc=-12,-35&looping=true",
      "shipFire04.pex?loc= 8,55&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#harvesterCarrierNewcastle.png"
  },
  subentities = {
    "Mining_Newcastle_0_harvester_module?loc=0,0"
  },
  collisionRadius = 90,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "harvesterCarrierNewcastle.atlas.png#deathPart01.png?lifetime=2.5&dir=70&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "harvesterCarrierNewcastle.atlas.png#deathPart02.png?lifetime=2&dir=-100&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut60.pex?loc=0,-63&looping=true&pri=-1"
}
_M.Mining_Newcastle_0_harvester = {
  texture = "harvesterCarrierNewcastle.atlas.png#harvester01.png?rot=-90",
  storeTexture = "harvesterCarrierNewcastle.atlas.png#harvester01.png",
  collisionRadius = 14,
  ribbon = "smallBlueRibbon",
  nitroTexture = "harvesterNitro.pex?looping=true",
  depositSfx = "game_resourcecollect_01?volume=0.6",
  weaponFireTexture = "harvesterImpactLarge.pex",
  weaponLoc = {18, 0},
  deathfx = {
    "harvesterExplosionSmall.pex",
    "harvesterExplosionSparksSmall.pex"
  },
  deathSfx = "game_miner_destruction_01"
}
_cloneup("Mining_Newcastle", 6)
_M.Mining_Dorado_0 = {
  texture = {
    "capShipTrail.pex?loc=-12,-60&looping=true",
    "capShipTrail.pex?loc=10,-60&looping=true",
    "capShipTrail.pex?loc=-25,-58&looping=true",
    "capShipTrail.pex?loc=22,-58&looping=true",
    "harvesterCarrierDorado.atlas.png#ship01.png",
    "StarPatrolOne.atlas.png?loc=-34,-44&anim=runningLightGold",
    "StarPatrolOne.atlas.png?loc=34,-44&anim=runningLightGold"
  },
  damageTextures = {
    {
      "harvesterCarrierDorado.atlas.png#dmgState02.png",
      "shipFire02.pex?loc= 8,-20&looping=true",
      "shipFire.pex?loc=10,15&looping=true",
      "shipFire.pex?loc=-2,-20&looping=true",
      "shipFire04.pex?loc=-10,40&looping=true",
      "shipFire04.pex?loc= 8,45&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#harvesterCarrierDorado.png"
  },
  subentities = {
    "Mining_Dorado_0_harvester_module?loc=0,0"
  },
  collisionRadius = 92,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "harvesterCarrierDorado.atlas.png#deathPart01.png?lifetime=2.5&dir=10&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "harvesterCarrierDorado.atlas.png#deathPart02.png?lifetime=2&dir=-145&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "harvesterCarrierDorado.atlas.png#deathPart03.png?lifetime=1.8&dir=85&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut60.pex?loc=0,-60&looping=true&pri=-1"
}
_M.Mining_Dorado_0_harvester = {
  texture = "harvesterCarrierDorado.atlas.png#harvester01.png?rot=-90",
  storeTexture = "harvesterCarrierDorado.atlas.png#harvester01.png",
  collisionRadius = 14,
  ribbon = "smallBlueRibbon",
  nitroTexture = "harvesterNitro.pex?looping=true",
  depositSfx = "game_resourcecollect_01?volume=0.6",
  weaponFireTexture = "harvesterImpactLarge.pex",
  weaponLoc = {18, 0},
  deathfx = {
    "harvesterExplosionSmall.pex",
    "harvesterExplosionSparksSmall.pex"
  },
  deathSfx = "game_miner_destruction_01"
}
_cloneup("Mining_Dorado", 6)
_M.Mining_Sutter_0 = {
  texture = {
    "capShipTrail.pex?loc=-32,-90&looping=true",
    "capShipTrail.pex?loc=20,-94&looping=true",
    "capShipTrail.pex?loc=1,-96&looping=true",
    "capShipTrail.pex?loc=-19,-94&looping=true",
    "capShipTrail.pex?loc=33,-90&looping=true",
    "harvesterCarrierAssault.atlas.png#ship01.png",
    "StarPatrolOne.atlas.png?loc=-34,-44&anim=runningLightGold",
    "StarPatrolOne.atlas.png?loc=34,-44&anim=runningLightGold"
  },
  damageTextures = {
    {
      "harvesterCarrierAssault.atlas.png#dmgState02.png",
      "shipFire02.pex?loc= 8,-20&looping=true",
      "shipFire.pex?loc=-5,-48&looping=true",
      "shipFire.pex?loc=6,-64&looping=true",
      "shipFire04.pex?loc= 8,45&looping=true",
      "shipFire02.pex?loc= 10,62&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#harvesterCarrierAssault.png"
  },
  subentities = {
    "Mining_Sutter_0_harvester_module?loc=0,0"
  },
  collisionRadius = 92,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "harvesterCarrierAssault.atlas.png#deathPart01.png?lifetime=2.5&dir=10&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "harvesterCarrierAssault.atlas.png#deathPart02.png?lifetime=2&dir=145&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "harvesterCarrierAssault.atlas.png#deathPart03.png?lifetime=1.8&dir=65&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut60.pex?loc=0,-84&looping=true&pri=-1"
}
_M.Mining_Sutter_0_harvester = {
  texture = "harvesterCarrierAssault.atlas.png#harvester01.png?rot=-90",
  storeTexture = "harvesterCarrierAssault.atlas.png#harvester01.png",
  collisionRadius = 14,
  ribbon = "smallBlueRibbon",
  nitroTexture = "harvesterNitro.pex?looping=true",
  depositSfx = "game_resourcecollect_01?volume=0.6",
  weaponFireTexture = "harvesterImpactLarge.pex",
  weaponLoc = {18, 0},
  deathfx = {
    "harvesterExplosionSmall.pex",
    "harvesterExplosionSparksSmall.pex"
  },
  deathSfx = "game_miner_destruction_01"
}
_cloneup("Mining_Sutter", 6)
_M.Mining_Thule_0 = {
  texture = {
    "capShipTrail.pex?loc=-13,-90&looping=true",
    "capShipTrail.pex?loc=-42,-80&looping=true",
    "capShipTrail.pex?loc=42,-80&looping=true",
    "capShipTrail.pex?loc=13,-90&looping=true",
    "harvesterCarrierAssaultAdv.atlas.png#ship01.png",
    "StarPatrolOne.atlas.png?loc=-34,-44&anim=runningLightGold",
    "StarPatrolOne.atlas.png?loc=34,-44&anim=runningLightGold"
  },
  damageTextures = {
    {
      "harvesterCarrierAssaultAdv.atlas.png#dmgState02.png",
      "shipFire02.pex?loc= 8,-20&looping=true",
      "shipFire.pex?loc=3,29&looping=true",
      "shipFire.pex?loc=-14,-42&looping=true",
      "shipFire02.pex?loc=-11,52&looping=true",
      "shipFire04.pex?loc= 8,54&looping=true"
    }
  },
  storeTexture = {
    "storeScreen.atlas.png#harvesterCarrierAssaultAdv.png"
  },
  subentities = {
    "Mining_Thule_0_harvester_module?loc=0,0"
  },
  collisionRadius = 92,
  deathfx = {
    "explosionCapitalShip.pex",
    "explosionSparksCapitalShip.pex"
  },
  deathObjs = {
    "harvesterCarrierAssaultAdv.atlas.png#deathPart01.png?lifetime=2.5&dir=10&fxrate=0.4,0.6&fxorigin=-20,59&fxbounds=40,120",
    "harvesterCarrierAssaultAdv.atlas.png#deathPart02.png?lifetime=2&dir=145&fxrate=0.1,0.2&fxorigin=22,99&fxbounds=50,100",
    "harvesterCarrierAssaultAdv.atlas.png#deathPart03.png?lifetime=1.8&dir=85&fxrate=0.5,1&fxorigin=37,-46&fxbounds=30,40"
  },
  deathSfx = "game_capship_death_01",
  warpEffect = "warpOut60.pex?loc=0,-60&looping=true&pri=-1"
}
_M.Mining_Thule_0_harvester = {
  texture = "harvesterCarrierAssaultAdv.atlas.png#harvester01.png?rot=-90",
  storeTexture = "harvesterCarrierAssaultAdv.atlas.png#harvester01.png",
  collisionRadius = 14,
  ribbon = "smallBlueRibbon",
  nitroTexture = "harvesterNitro.pex?looping=true",
  depositSfx = "game_resourcecollect_01?volume=0.6",
  weaponFireTexture = "harvesterImpactLarge.pex",
  weaponLoc = {18, 0},
  deathfx = {
    "harvesterExplosionSmall.pex",
    "harvesterExplosionSparksSmall.pex"
  },
  deathSfx = "game_miner_destruction_01"
}
_cloneup("Mining_Thule", 6)
_M.Alien_Sm_Fighter = {
  texture = "alienFighterBasic.atlas.png#ship01.png?rot=-90",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyFighter.png",
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 18,
  weaponFireSfx = "alienFighterLaser?volume=0.4",
  weaponFireTexture = "alienFighterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienFighterWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTextureLo = "alienFighterWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = "alienImpactLarge.pex",
  weaponLoc = {8, 0},
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ai = "enemy_seek_closest",
  type = "enemyf",
  ribbon = "smallRedRibbon",
  pathColor = "clear",
  deathfx = {
    "alienExplosionSmall.pex",
    "alienExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_M.Alien_Med_Fighter = {
  texture = "alienFighterMedBasic.atlas.png#ship01.png?rot=-90",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyFighter.png",
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 18,
  weaponFireSfx = "alienFighterLaser?volume=0.4",
  weaponFireTexture = "alienFighterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienFighterWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTextureLo = "alienFighterWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = "alienImpactLarge.pex",
  weaponLoc = {12, 0},
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ai = "enemy_seek_closest",
  pathColor = "clear",
  type = "enemyf",
  ribbon = "smallRedRibbon",
  deathfx = {
    "alienExplosionSmall.pex",
    "alienExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_M.Alien_Med_Fighter_SH = _deepcopy(_M.Alien_Med_Fighter)
_M.Alien_Large_Fighter = {
  texture = "alienFighterHeavyBasic.atlas.png#ship01.png?rot=-90",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyFighter.png",
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 26,
  weaponFireSfx = "alienFighterLaser",
  weaponFireTexture = "alienFighterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienFighterWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTextureLo = "alienFighterWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = "alienImpactLarge.pex",
  weaponLoc = {12, 0},
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ai = "enemy_seek_closest",
  pathColor = "clear",
  type = "enemyf",
  ribbon = "smallRedRibbon",
  deathfx = {
    "alienExplosionSmall.pex",
    "alienExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_M.Alien_Large_Fighter_SH = _deepcopy(_M.Alien_Large_Fighter)
_M.Alien_Sm_Bomber = {
  texture = "alienBomberBasic.atlas.png#ship01.png?rot=-90",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyBomber.png",
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 32,
  weaponFireSfx = "alienBomber?volum=0.3",
  wiggleFrequency = 1.5,
  wiggleAmplitude = 1.5,
  weaponFireTexture = "alienBomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienBomberWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTextureLo = "alienBomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = "alienBomberImpactLarge.pex",
  weaponLoc = {20, 0},
  ai = "enemy_seek_capitalship",
  type = "enemyb",
  ribbon = "largeRedRibbon?loc=-16,0",
  pathColor = "clear",
  deathfx = {
    "alienExplosionMed.pex",
    "alienExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_M.Alien_Sm_Bomber_SH = _deepcopy(_M.Alien_Sm_Bomber)
_M.Alien_Med_Bomber = {
  texture = {
    "alienBomberMedBasic.atlas.png#ship01.png?rot=-90"
  },
  damageTextures = {
    {
      "shipFire.pex?loc=10,15&looping=true",
      "shipFire04.pex?loc=-2,-8&looping=true"
    }
  },
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyBomber.png",
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 42,
  weaponFireSfx = "alienBomber?volume=0.3",
  weaponFireTexture = "alienBomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienBomberWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTextureLo = "alienBomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = "alienBomberImpactLarge.pex",
  weaponLoc = {20, 0},
  ai = "enemy_bombing_run",
  type = "enemyb",
  ribbon = "largeRedRibbon?loc=-22,0",
  pathColor = "clear",
  deathfx = {
    "alienExplosionMed.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_M.Alien_Med_Bomber_SH = _deepcopy(_M.Alien_Med_Bomber)
_M.Alien_Lg_Bomber = {
  texture = {
    "alienHeavyBasic.atlas.png#ship01.png?rot=-90"
  },
  damageTextures = {
    {
      "shipFire.pex?loc=-20,17&looping=true",
      "shipFire.pex?loc=-15,-10&looping=true",
      "shipFire04.pex?loc=3,-5&looping=true"
    }
  },
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyBomber.png",
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 46,
  weaponFireSfx = "alienHeavy?volume=0.5",
  weaponFireTexture = "alienBomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienBomberWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTextureLo = "alienBomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = "alienBomberImpactLarge.pex",
  weaponLoc = {20, 0},
  ai = "enemy_bombing_run",
  type = "enemyb",
  ribbon = "largeRedRibbon?loc=-26,0",
  pathColor = "clear",
  deathfx = {
    "alienExplosionMed.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_M.Alien_Lg_Bomber_SH = _deepcopy(_M.Alien_Lg_Bomber)
_M.Alien_Med_Artillery = {
  texture = {
    "alienSpitterBasic.atlas.png#ship01.png?rot=-90"
  },
  damageTextures = {
    {
      "alienSpitterBasic.atlas.png#dmgState02.png?rot=-90&loc=-22,-19",
      "shipDeathExplosion.pex?loc=16,18",
      "shipDeathExplosion.pex?loc=-85,15",
      "shipDeathExplosion.pex?loc=-20,-30",
      "shipFire.pex?loc=16,18&looping=true",
      "shipFire.pex?loc=-25,-10&looping=true",
      "shipFire04.pex?loc=-85,15&looping=true",
      "shipFire.pex?loc=29,29&looping=true",
      "shipFire.pex?loc=0,22&looping=true",
      "shipFire04.pex?loc=-55,-20&looping=true"
    }
  },
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyCapship.png",
  offscreenIndicatorNoRot = true,
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 110,
  weaponFireTexture = "alienSpitterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienSpitterWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTextureLo = "alienSpitterImpact.pex",
  weaponImpactTexture = "alienSpitterImpact.pex",
  weaponTravelTime = 1.3,
  weaponLoc = {52, 0},
  targetTypes = {capitalship = 1, harvesters = 1},
  shieldTexture = "shieldPrototype.png",
  ai = "enemy_artillery",
  type = "enemyc",
  ribbon = "largeRedRibbon",
  pathColor = "clear",
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_capship_death_01"
}
_M.Alien_Med_Artillery_SH = _deepcopy(_M.Alien_Med_Artillery)
_M.Alien_Con_Catapult = {
  texture = {
    "alienConstruction01.atlas.png#ship01.png?rot=-90"
  },
  anim = "alienConstructionArms.atlas.png?anim=alienConstructionArms&loc=30,0&rot=90&showAnim=true",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyFighter.png",
  scl = 1,
  collisionRadius = 32,
  weaponFireTexture = "alienConstructionSparks.pex",
  weaponLoc = {52, 0},
  shieldTexture = "shieldPrototype.png",
  ai = "enemy_construction",
  type = "enemyc",
  ribbon = "largeRedRibbon",
  pathColor = "clear",
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01",
  buildType = "Alien_Catapult"
}
_M.Alien_Con_Trebuchet = {
  texture = {
    "alienConstruction01.atlas.png#ship01.png?rot=-90"
  },
  anim = "alienConstructionArms.atlas.png?anim=alienConstructionArms&loc=30,0&rot=90&showAnim=true",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyFighter.png",
  scl = 1,
  collisionRadius = 34,
  weaponFireTexture = "alienConstructionSparks.pex",
  weaponLoc = {52, 0},
  targetTypes = {capitalship = 1, harvesters = 1},
  shieldTexture = "shieldPrototype.png",
  ai = "enemy_construction",
  type = "enemyc",
  ribbon = "largeRedRibbon",
  pathColor = "clear",
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01",
  buildType = "Alien_Trebuchet"
}
_M.Alien_Con_Ballista = {
  texture = {
    "alienConstruction01.atlas.png#ship01.png?rot=-90"
  },
  anim = "alienConstructionArms.atlas.png?anim=alienConstructionArms&loc=30,0&rot=90&showAnim=true",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyFighter.png",
  scl = 1,
  collisionRadius = 34,
  weaponFireTexture = "alienConstructionSparks.pex",
  weaponLoc = {52, 0},
  shieldTexture = "shieldPrototype.png",
  ai = "enemy_construction",
  type = "enemyc",
  ribbon = "largeRedRibbon",
  pathColor = "clear",
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01",
  buildType = "Alien_Ballista"
}
_M.Alien_Credit_Saucer = {
  texture = "alienSaucerBasic.atlas.png#ship01.png?rot=-90",
  scl = 1,
  damageTextures = {
    {
      "shipFire05.pex?loc=10,15&looping=true",
      "shipFire05.pex?loc=-18,-5&looping=true",
      "shipFire05.pex?loc=3,-12&looping=true"
    }
  },
  collisionRadius = 55,
  wiggleFrequency = 0.5,
  wiggleAmplitude = 0.8,
  ai = "flying_saucer",
  type = "saucer",
  pathColor = "clear",
  deathfx = {
    "saucerExplosion02.pex",
    "saucerExplosion01.pex",
    "saucerExplosionSparks.pex"
  },
  deathSfx = "capitalShipDeathExplosion"
}
_M.Alien_Ballista = {
  texture = {
    "alienAntiCapital03.atlas.png#ship01.png?rot=-90"
  },
  buildingTextures = {
    {
      "alienAntiCapital03.atlas.png#underConstruction_04_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital03.atlas.png#underConstruction_03_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital03.atlas.png#underConstruction_02_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital03.atlas.png#underConstruction_01_15fps.png?rot=-90"
    }
  },
  damageTextures = {
    {
      "alienAntiCapital03.atlas.png#dmgState02.png?rot=-90",
      "shipFire.pex?loc= 24,-20&looping=true",
      "shipFire04.pex?loc=42,-19&looping=true",
      "shipFire.pex?loc=19,32&looping=true",
      "shipFire04.pex?loc= -20,40&looping=true"
    }
  },
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyCapship.png",
  offscreenIndicatorNoRot = true,
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 90,
  weaponFireTexture = "alienSpitterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienSpitterWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTexture = "spitterImpact01.pex",
  weaponTravelTime = 1.3,
  weaponLoc = {52, 0},
  targetTypes = {capitalship = 1, harvesters = 1},
  shieldTexture = "shieldPrototype.png",
  ai = "enemy_ballista",
  ribbon = "largeRedRibbon",
  pathColor = "clear",
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_capship_death_01",
  subentities = {
    "Alien_Ballista_cannon?loc=-28,0",
    "Alien_Ballista_cannon?loc=-18,-36",
    "Alien_Ballista_cannon?loc=-18,36"
  }
}
_M.Alien_Ballista_cannon = {
  turretTexture = "alienTurretBasic.atlas.png#ship01.png?rot=-90",
  weaponFireTexture = "gunshipWeaponBasic.atlas.png?anim=muzzleFlash",
  weaponFireSfx = "uiUnavailable",
  cannonIcon = "cannonIcon.png",
  weaponLoc = {0, 60}
}
_M.Alien_Ballista_projectile = {
  anim = "alienAntiCapital03WeaponBasic.atlas.png?anim=projectile&rot=-90",
  weaponImpactTexture = {
    "alienArtillery05.pex",
    "alienArtillery06.pex"
  },
  targetTypes = ALIEN_PROJECTILE_TARGETS,
  navPointTexture = "hud.atlas.png#deathBlossomReticle.png",
  collisionRadius = 88,
  shieldRadius = 22
}
_M.Alien_Trebuchet = {
  texture = {
    "alienAntiCapital02.atlas.png#ship01.png?rot=-90"
  },
  buildingTextures = {
    {
      "alienAntiCapital02.atlas.png#underConstruction_004_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital02.atlas.png#underConstruction_003_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital02.atlas.png#underConstruction_002_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital02.atlas.png#underConstruction_001_15fps.png?rot=-90"
    }
  },
  damageTextures = {
    {
      "alienAntiCapital02.atlas.png#dmgState02.png?rot=-90",
      "shipFire.pex?loc= 24,-20&looping=true",
      "shipFire04.pex?loc=42,-19&looping=true",
      "shipFire.pex?loc=19,32&looping=true",
      "shipFire04.pex?loc= -20,40&looping=true"
    }
  },
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyCapship.png",
  offscreenIndicatorNoRot = true,
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 70,
  weaponLoc = {52, 0},
  shieldTexture = "shieldPrototype.png",
  ai = "enemy_trebuchet",
  ribbon = "largeRedRibbon",
  pathColor = "clear",
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_capship_death_01",
  subentities = {
    "Alien_Trebuchet_cannon?loc=25,-25",
    "Alien_Trebuchet_cannon?loc=25,25"
  }
}
_M.Alien_Trebuchet_cannon = {
  turretTexture = "alienTurretBasic.atlas.png#ship01.png?rot=-90",
  weaponFireTexture = "gunshipWeaponBasic.atlas.png?anim=muzzleFlash",
  weaponFireSfx = "uiUnavailable",
  cannonIcon = "cannonIcon.png",
  weaponLoc = {0, 60}
}
_M.Alien_Trebuchet_projectile = {
  anim = "alienAntiCapital02WeaponBasic.atlas.png?anim=projectile&rot=-90",
  weaponImpactTexture = {
    "alienArtillery03.pex",
    "alienArtillery04.pex"
  },
  targetTypes = ALIEN_PROJECTILE_TARGETS,
  navPointTexture = "hud.atlas.png#deathBlossomReticle.png",
  collisionRadius = 88,
  shieldRadius = 22
}
_M.Alien_Catapult = {
  texture = {
    "alienAntiCapital01.atlas.png#ship01.png?rot=-90"
  },
  buildingTextures = {
    {
      "alienAntiCapital01.atlas.png#underConstruction_004_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital01.atlas.png#underConstruction_003_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital01.atlas.png#underConstruction_002_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital01.atlas.png#underConstruction_001_15fps.png?rot=-90"
    }
  },
  damageTextures = {
    {
      "alienAntiCapital01.atlas.png#dmgState02.png?rot=-90",
      "shipFire.pex?loc= -24,-20&looping=true",
      "shipFire04.pex?loc=35,-5&looping=true",
      "shipFire.pex?loc=13,20&looping=true",
      "shipFire04.pex?loc= -24,20&looping=true"
    }
  },
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyCapship.png",
  offscreenIndicatorNoRot = true,
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 80,
  weaponLoc = {52, 0},
  shieldTexture = "shieldPrototype.png",
  ai = "enemy_catapult",
  ribbon = "largeRedRibbon",
  pathColor = "clear",
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_capship_death_01",
  subentities = {
    "Alien_Catapult_cannon?loc=-25,0"
  }
}
_M.Alien_Catapult_cannon = {
  turretTexture = "alienTurretBasic.atlas.png#ship01.png?rot=-90",
  weaponFireTexture = "gunshipWeaponBasic.atlas.png?anim=muzzleFlash",
  weaponFireSfx = "uiUnavailable",
  cannonIcon = "cannonIcon.png",
  weaponLoc = {0, 60}
}
_M.Alien_Catapult_projectile = {
  anim = "alienAntiCapital01WeaponBasic.atlas.png?anim=projectile&rot=-90",
  weaponImpactTexture = {
    "alienArtillery01.pex",
    "alienArtillery02.pex"
  },
  targetTypes = {
    capitalship = true,
    harvester = true,
    fighter = true,
    asteroid = true
  },
  navPointTexture = "hud.atlas.png#deathBlossomReticle.png",
  collisionRadius = 88,
  shieldRadius = 22
}
_M.Alien_Sm_Fighter_v2 = {
  texture = "venomFighterBasic.atlas.png#ship01.png?rot=-90",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyFighter.png",
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 18,
  weaponFireSfx = "alienFighterLaser?volume=0.4",
  weaponFireTexture = "alienFighterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienFighterWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTextureLo = "alienFighterWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = "alienImpactLarge.pex",
  weaponLoc = {8, 0},
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ai = "enemy_seek_closest",
  type = "enemyf",
  ribbon = "smallRedRibbonTier2",
  pathColor = "clear",
  deathfx = {
    "alienExplosionSmall.pex",
    "alienExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_M.Alien_Med_Fighter_v2 = {
  texture = "venomFighterMedBasic.atlas.png#ship01.png?rot=-90",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyFighter.png",
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 26,
  weaponFireSfx = "alienFighterLaser?volume=0.4",
  weaponFireTexture = "alienFighterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienFighterWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTextureLo = "alienFighterWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = "alienImpactLarge.pex",
  weaponLoc = {12, 0},
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ai = "enemy_seek_closest",
  pathColor = "clear",
  type = "enemyf",
  ribbon = "smallRedRibbonTier2",
  deathfx = {
    "alienExplosionSmall.pex",
    "alienExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_M.Alien_Med_Fighter_SH_v2 = _deepcopy(_M.Alien_Med_Fighter_v2)
_M.Alien_Med_Fighter_v2_screamer = {
  texture = "venomFighterMedBasic.atlas.png#ship01.png?rot=-90",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyFighter.png",
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 18,
  weaponFireSfx = "alienFighterLaser?volume=0.4",
  weaponFireTexture = "alienFighterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienFighterWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTextureLo = "alienFighterWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = "alienImpactLarge.pex",
  weaponLoc = {12, 0},
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ai = "enemy_seek_capitalship",
  pathColor = "clear",
  type = "enemyf",
  ribbon = "smallRedRibbonTier2",
  deathfx = {
    "alienExplosionSmall.pex",
    "alienExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_M.Alien_Large_Fighter_v2 = {
  texture = "venomFighterHeavyBasic.atlas.png#ship01.png?rot=-90",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyFighter.png",
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 26,
  weaponFireSfx = "alienFighterLaser",
  weaponFireTexture = "alienFighterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienFighterWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTextureLo = "alienFighterWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = "alienImpactLarge.pex",
  weaponLoc = {12, 0},
  weaponTravelTime = 0.15,
  weaponFOV = math.cos(45),
  ai = "enemy_seek_closest",
  pathColor = "clear",
  type = "enemyf",
  ribbon = "smallRedRibbonTier2",
  deathfx = {
    "alienExplosionSmall.pex",
    "alienExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_M.Alien_Large_Fighter_SH_v2 = _deepcopy(_M.Alien_Large_Fighter_v2)
_M.Alien_Sm_Bomber_v2 = {
  texture = "venomBomberBasic.atlas.png#ship01.png?rot=-90",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyBomber.png",
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 38,
  weaponFireSfx = "alienBomber?volum=0.3",
  wiggleFrequency = 1.5,
  wiggleAmplitude = 1.5,
  weaponFireTexture = "alienBomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienBomberWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTextureLo = "alienBomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = "alienBomberImpactLarge.pex",
  weaponLoc = {20, 0},
  ai = "enemy_seek_capitalship",
  type = "enemyb",
  ribbon = "largeRedRibbonTier2?loc=-16,0",
  pathColor = "clear",
  deathfx = {
    "alienExplosionMed.pex",
    "alienExplosionSparksSmall.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_M.Alien_Sm_Bomber_SH_v2 = _deepcopy(_M.Alien_Sm_Bomber_v2)
_M.Alien_Med_Bomber_v2 = {
  texture = {
    "venomBomberMedBasic.atlas.png#ship01.png?rot=-90"
  },
  damageTextures = {
    {
      "shipFire.pex?loc=10,15&looping=true",
      "shipFire04.pex?loc=-2,-8&looping=true"
    }
  },
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyBomber.png",
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 48,
  weaponFireSfx = "alienBomber?volume=0.3",
  weaponFireTexture = "alienBomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienBomberWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTextureLo = "alienBomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = "alienBomberImpactLarge.pex",
  weaponLoc = {20, 0},
  ai = "enemy_bombing_run",
  type = "enemyb",
  ribbon = "largeRedRibbonTier2?loc=-22,0",
  pathColor = "clear",
  deathfx = {
    "alienExplosionMed.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_M.Alien_Med_Bomber_SH_v2 = _deepcopy(_M.Alien_Med_Bomber_v2)
_M.Alien_Lg_Bomber_v2 = {
  texture = {
    "venomHeavyBasic.atlas.png#ship01.png?rot=-90"
  },
  damageTextures = {
    {
      "shipFire.pex?loc=-20,17&looping=true",
      "shipFire.pex?loc=-15,-10&looping=true",
      "shipFire04.pex?loc=3,-5&looping=true"
    }
  },
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyBomber.png",
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 52,
  weaponFireSfx = "alienHeavy?volume=0.5",
  weaponFireTexture = "alienBomberWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienBomberWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTextureLo = "alienBomberWeaponBasic.atlas.png?anim=impact",
  weaponImpactTexture = "alienBomberImpactLarge.pex",
  weaponLoc = {20, 0},
  ai = "enemy_bombing_run",
  type = "enemyb",
  ribbon = "largeRedRibbonTier2?loc=-26,0",
  pathColor = "clear",
  deathfx = {
    "alienExplosionMed.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01"
}
_M.Alien_Lg_Bomber_SH_v2 = _deepcopy(_M.Alien_Lg_Bomber_v2)
_M.Alien_Med_Artillery_v2 = {
  texture = {
    "venomSpitterBasic.atlas.png#ship01.png?rot=-90"
  },
  damageTextures = {
    {
      "alienSpitterBasic.atlas.png#dmgState02.png?rot=-90&loc=-22,-19",
      "shipDeathExplosion.pex?loc=16,18",
      "shipDeathExplosion.pex?loc=-85,15",
      "shipDeathExplosion.pex?loc=-20,-30",
      "shipFire.pex?loc=16,18&looping=true",
      "shipFire.pex?loc=-25,-10&looping=true",
      "shipFire04.pex?loc=-85,15&looping=true",
      "shipFire.pex?loc=29,29&looping=true",
      "shipFire.pex?loc=0,22&looping=true",
      "shipFire04.pex?loc=-55,-20&looping=true"
    }
  },
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyCapship.png",
  offscreenIndicatorNoRot = true,
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 110,
  weaponFireTexture = "alienSpitterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienSpitterWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTextureLo = "alienSpitterImpact.pex",
  weaponImpactTexture = "alienSpitterImpact.pex",
  weaponTravelTime = 1.3,
  weaponLoc = {52, 0},
  targetTypes = {capitalship = 1, harvesters = 1},
  shieldTexture = "shieldPrototype.png",
  ai = "enemy_artillery",
  type = "enemyc",
  ribbon = "largeRedRibbonTier2",
  pathColor = "clear",
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_capship_death_01"
}
_M.Alien_Med_Artillery_SH_v2 = _deepcopy(_M.Alien_Med_Artillery_v2)
_M.Alien_Con_Catapult_v2 = {
  texture = {
    "alienConstruction03.atlas.png#ship01.png?rot=-90"
  },
  anim = "alienConstructionArms.atlas.png?anim=alienConstructionArms&loc=32,0&rot=90&showAnim=true",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyFighter.png",
  scl = 1,
  collisionRadius = 32,
  weaponFireTexture = "alienConstructionSparks.pex",
  weaponLoc = {52, 0},
  shieldTexture = "shieldPrototype.png",
  ai = "enemy_construction",
  type = "enemyc",
  ribbon = "largeRedRibbonTier2",
  pathColor = "clear",
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01",
  buildType = "Alien_Catapult_v2"
}
_M.Alien_Con_Trebuchet_v2 = {
  texture = {
    "alienConstruction03.atlas.png#ship01.png?rot=-90"
  },
  anim = "alienConstructionArms.atlas.png?anim=alienConstructionArms&loc=32,0&rot=90&showAnim=true",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyFighter.png",
  scl = 1,
  collisionRadius = 34,
  weaponFireTexture = "alienConstructionSparks.pex",
  weaponLoc = {52, 0},
  targetTypes = {capitalship = 1, harvesters = 1},
  shieldTexture = "shieldPrototype.png",
  ai = "enemy_construction",
  type = "enemyc",
  ribbon = "largeRedRibbonTier2",
  pathColor = "clear",
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01",
  buildType = "Alien_Trebuchet_v2"
}
_M.Alien_Con_Ballista_v2 = {
  texture = {
    "alienConstruction03.atlas.png#ship01.png?rot=-90"
  },
  anim = "alienConstructionArms.atlas.png?anim=alienConstructionArms&loc=32,0&rot=90&showAnim=true",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyFighter.png",
  scl = 1,
  collisionRadius = 34,
  weaponFireTexture = "alienConstructionSparks.pex",
  weaponLoc = {52, 0},
  shieldTexture = "shieldPrototype.png",
  ai = "enemy_construction",
  type = "enemyc",
  ribbon = "largeRedRibbonTier2",
  pathColor = "clear",
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01",
  buildType = "Alien_Ballista_v2"
}
_M.Alien_Ballista_v2 = {
  texture = {
    "venomAntiCapital03.atlas.png#ship01.png?rot=-90"
  },
  buildingTextures = {
    {
      "alienAntiCapital03.atlas.png#underConstruction_04_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital03.atlas.png#underConstruction_03_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital03.atlas.png#underConstruction_02_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital03.atlas.png#underConstruction_01_15fps.png?rot=-90"
    }
  },
  damageTextures = {
    {
      "alienAntiCapital03.atlas.png#dmgState02.png?rot=-90",
      "shipFire.pex?loc= 24,-20&looping=true",
      "shipFire04.pex?loc=42,-19&looping=true",
      "shipFire.pex?loc=19,32&looping=true",
      "shipFire04.pex?loc= -20,40&looping=true"
    }
  },
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyCapship.png",
  offscreenIndicatorNoRot = true,
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 90,
  weaponFireTexture = "alienSpitterWeaponBasic.atlas.png?rot=-90&anim=muzzleFlash",
  weaponTexture = "alienSpitterWeaponBasic.atlas.png?anim=projectile",
  weaponImpactTexture = "spitterImpact01.pex",
  weaponTravelTime = 1.3,
  weaponLoc = {52, 0},
  targetTypes = {capitalship = 1, harvesters = 1},
  shieldTexture = "shieldPrototype.png",
  ai = "enemy_ballista",
  ribbon = "largeRedRibbonTier2",
  pathColor = "clear",
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_capship_death_01",
  subentities = {
    "Alien_Ballista_cannon?loc=-28,0",
    "Alien_Ballista_cannon?loc=-18,-36",
    "Alien_Ballista_cannon?loc=-18,36"
  }
}
_M.Alien_Ballista_cannon_v2 = {
  turretTexture = "alienTurretBasic.atlas.png#ship01.png?rot=-90",
  weaponFireTexture = "gunshipWeaponBasic.atlas.png?anim=muzzleFlash",
  weaponFireSfx = "uiUnavailable",
  cannonIcon = "cannonIcon.png",
  weaponLoc = {0, 60}
}
_M.Alien_Ballista_projectile_v2 = {
  anim = "alienAntiCapital03WeaponBasic.atlas.png?anim=projectile&rot=-90",
  weaponImpactTexture = {
    "alienArtillery05.pex",
    "alienArtillery06.pex"
  },
  targetTypes = ALIEN_PROJECTILE_TARGETS,
  navPointTexture = "hud.atlas.png#deathBlossomReticle.png",
  collisionRadius = 88,
  shieldRadius = 22
}
_M.Alien_Trebuchet_v2 = {
  texture = {
    "venomAntiCapital02.atlas.png#ship01.png?rot=-90"
  },
  buildingTextures = {
    {
      "alienAntiCapital02.atlas.png#underConstruction_004_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital02.atlas.png#underConstruction_003_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital02.atlas.png#underConstruction_002_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital02.atlas.png#underConstruction_001_15fps.png?rot=-90"
    }
  },
  damageTextures = {
    {
      "alienAntiCapital02.atlas.png#dmgState02.png?rot=-90",
      "shipFire.pex?loc= 24,-20&looping=true",
      "shipFire04.pex?loc=42,-19&looping=true",
      "shipFire.pex?loc=19,32&looping=true",
      "shipFire04.pex?loc= -20,40&looping=true"
    }
  },
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyCapship.png",
  offscreenIndicatorNoRot = true,
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 70,
  weaponLoc = {52, 0},
  shieldTexture = "shieldPrototype.png",
  ai = "enemy_trebuchet",
  ribbon = "largeRedRibbonTier2",
  pathColor = "clear",
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_capship_death_01",
  subentities = {
    "Alien_Trebuchet_cannon?loc=25,-25",
    "Alien_Trebuchet_cannon?loc=25,25"
  }
}
_M.Alien_Trebuchet_cannon_v2 = {
  turretTexture = "alienTurretBasic.atlas.png#ship01.png?rot=-90",
  weaponFireTexture = "gunshipWeaponBasic.atlas.png?anim=muzzleFlash",
  weaponFireSfx = "uiUnavailable",
  cannonIcon = "cannonIcon.png",
  weaponLoc = {0, 60}
}
_M.Alien_Trebuchet_projectile_v2 = {
  anim = "alienAntiCapital02WeaponBasic.atlas.png?anim=projectile&rot=-90",
  weaponImpactTexture = {
    "alienArtillery03.pex",
    "alienArtillery04.pex"
  },
  targetTypes = ALIEN_PROJECTILE_TARGETS,
  navPointTexture = "hud.atlas.png#deathBlossomReticle.png",
  collisionRadius = 88,
  shieldRadius = 22
}
_M.Alien_Catapult_v2 = {
  texture = {
    "venomAntiCapital01.atlas.png#ship01.png?rot=-90"
  },
  buildingTextures = {
    {
      "alienAntiCapital01.atlas.png#underConstruction_004_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital01.atlas.png#underConstruction_003_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital01.atlas.png#underConstruction_002_15fps.png?rot=-90"
    },
    {
      "alienAntiCapital01.atlas.png#underConstruction_001_15fps.png?rot=-90"
    }
  },
  damageTextures = {
    {
      "alienAntiCapital01.atlas.png#dmgState02.png?rot=-90",
      "shipFire.pex?loc= -24,-20&looping=true",
      "shipFire04.pex?loc=35,-5&looping=true",
      "shipFire.pex?loc=13,20&looping=true",
      "shipFire04.pex?loc= -24,20&looping=true"
    }
  },
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyCapship.png",
  offscreenIndicatorNoRot = true,
  offscreenIndicatorPulseRate = 4,
  scl = 1,
  collisionRadius = 80,
  weaponLoc = {52, 0},
  shieldTexture = "shieldPrototype.png",
  ai = "enemy_catapult",
  ribbon = "largeRedRibbonTier2",
  pathColor = "clear",
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_capship_death_01",
  subentities = {
    "Alien_Catapult_cannon?loc=-25,0"
  }
}
_M.Alien_Catapult_cannon_v2 = {
  turretTexture = "alienTurretBasic.atlas.png#ship01.png?rot=-90",
  weaponFireTexture = "gunshipWeaponBasic.atlas.png?anim=muzzleFlash",
  weaponFireSfx = "uiUnavailable",
  cannonIcon = "cannonIcon.png",
  weaponLoc = {0, 60}
}
_M.Alien_Catapult_projectile_v2 = {
  anim = "alienAntiCapital01WeaponBasic.atlas.png?anim=projectile&rot=-90",
  weaponImpactTexture = {
    "alienArtillery01.pex",
    "alienArtillery02.pex"
  },
  targetTypes = {
    capitalship = true,
    harvester = true,
    fighter = true,
    asteroid = true
  },
  navPointTexture = "hud.atlas.png#deathBlossomReticle.png",
  collisionRadius = 88,
  shieldRadius = 22
}
_M.spawning_module = {
  moduleOverlay = "hud.atlas.png#warpSelector.png",
  warpType = "capitalship",
  scl = 0.5,
  ai = "warp_module",
  type = "warp_module"
}
_M.alien_spawning_module = {
  texture = "alienWarp.pex?looping=true",
  ai = "enemy_warp_module",
  hp = 15,
  drainHp = true,
  sfxOnChangeState = true,
  collisionRadius = 50,
  type = "alien_warp_module",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorEnemyCapship.png",
  offscreenIndicatorNoRot = true,
  offscreenIndicatorPulseRate = 4
}
_M.wreckage = {
  spawnLifetime = 10,
  noBlink = true,
  deathfx = {
    "alienExplosionLarge.pex"
  },
  ai = "wreckage",
  type = "wreckage"
}
_M.Resource_Lg = {
  texture = "objects.atlas.png#resource_01_b.png",
  scl = 0.5,
  collision = {},
  collisionRadius = 30,
  maxspeed = 0,
  resourceType = "blue",
  resourceValue = 10,
  towedObjectTexture = "objects.atlas.png#resource_01_capsule.png",
  towedObjectRadius = 8,
  towedObjectWeight = 1,
  ai = "resource_static",
  type = "resource"
}
_M.Salvage_Sm = {
  texture = "objects.atlas.png#salvageSmall01.png",
  collision = {},
  collisionRadius = 30,
  maxspeed = 0,
  resourceType = "alloy",
  resourceTexture = "menuTemplateShared.atlas.png#iconAlloyMed.png",
  resourceValue = 1,
  spawnLifetime = 10,
  noSpin = true,
  sclResource = true,
  salvageTouch = true,
  ai = "resource_static",
  type = "resource"
}
_M.Salvage_Lg = {
  texture = "objects.atlas.png#salvageMed01.png",
  collision = {},
  collisionRadius = 30,
  maxspeed = 0,
  resourceType = "alloy",
  resourceTexture = "menuTemplateShared.atlas.png#iconAlloyMed.png",
  resourceValue = 5,
  spawnLifetime = 10,
  noSpin = true,
  sclResource = true,
  salvageTouch = true,
  ai = "resource_static",
  type = "resource"
}
_M.Salvage_Credit = {
  texture = "objects.atlas.png#tCredDrop01.png",
  collision = {},
  collisionRadius = 20,
  maxspeed = 0,
  resourceType = "creds",
  resourceTexture = "menuTemplateShared.atlas.png#iconCredsMed.png",
  resourceValue = 1,
  spawnLifetime = 10,
  noSpin = true,
  sclResource = true,
  salvageTouch = true,
  ai = "resource_static",
  type = "resource"
}
_M.Asteroid_Lg = {
  texture = "objects.atlas.png#asteroid_01.png",
  scl = 1,
  collisionRadius = 70,
  hp = 600,
  harvestType = "Resource_Lg",
  harvestDamage = 10,
  ai = "asteroid",
  type = "asteroid"
}
_M.Asteroid_Med = {
  texture = "objects.atlas.png#asteroid_02.png",
  scl = 1,
  collisionRadius = 42,
  hp = 600,
  harvestType = "Resource_Lg",
  harvestDamage = 10,
  ai = "asteroid",
  type = "asteroid"
}
_M.Asteroid_Sm = {
  texture = "objects.atlas.png#asteroid_04.png",
  scl = 1,
  collisionRadius = 35,
  hp = 20,
  harvestType = "Resource_Lg",
  harvestDamage = 10,
  ai = "asteroid",
  type = "asteroid"
}
_M.Asteroid_Tn = {
  texture = "objects.atlas.png#asteroid_03.png",
  scl = 1,
  collisionRadius = 22,
  hp = 20,
  harvestType = "Resource_Lg",
  harvestDamage = 10,
  ai = "asteroid",
  type = "asteroid"
}
_M.Escape_Pod_Egn_Sm = {
  texture = {
    "objects.atlas.png#repairBuoySm.png",
    "objects.atlas.png?anim=buoyLight&loc=2,2&looping=true"
  },
  scl = 1,
  collision = {},
  collisionRadius = 40,
  maxspeed = 0,
  resourceType = "health",
  noSpin = true,
  damageTextures = {
    {
      "objects.atlas.png#repairBuoySmDmgState02.png",
      "shipFire04.pex?loc=12,-4&looping=true",
      "shipFire.pex?loc=-16,16&looping=true"
    }
  },
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01",
  warpEffect = "warpEffect.atlas.png",
  towedObjectTexture = "objects.atlas.png#repairBuoySm.png",
  towedObjectRadius = 8,
  offscreenIndicatorTexture = "hud.atlas.png#indicatorRepairBuoy.png",
  offscreenIndicatorPulseRate = 4,
  offscreenIndicatorColor = UI_BUOY_IND_COLOR,
  ai = "resource_drift",
  rotSpeed = 3,
  type = "survivor"
}
_M.Escape_Pod_Egn_Med = {
  texture = {
    "objects.atlas.png#repairBuoyMed.png",
    "objects.atlas.png?anim=buoyLight&looping=true"
  },
  scl = 1,
  collision = {},
  collisionRadius = 45,
  maxspeed = 0,
  resourceType = "health",
  noSpin = true,
  damageTextures = {
    {
      "objects.atlas.png#repairBuoyMedDmgState02.png",
      "shipFire04.pex?loc=12,-4&looping=true",
      "shipFire.pex?loc=-16,16&looping=true"
    }
  },
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01",
  warpEffect = "warpEffect.atlas.png",
  towedObjectTexture = "objects.atlas.png#repairBuoyMed.png",
  towedObjectRadius = 8,
  offscreenIndicatorTexture = "hud.atlas.png#indicatorRepairBuoy.png",
  offscreenIndicatorPulseRate = 4,
  offscreenIndicatorColor = UI_BUOY_IND_COLOR,
  ai = "resource_drift",
  rotSpeed = 3,
  type = "survivor"
}
_M.Escape_Pod_Egn_Lg = {
  texture = {
    "objects.atlas.png#repairBuoyMed.png",
    "objects.atlas.png?anim=buoyLight&looping=true"
  },
  scl = 1,
  collision = {},
  collisionRadius = 45,
  maxspeed = 0,
  resourceType = "health",
  noSpin = true,
  damageTextures = {
    {
      "objects.atlas.png#repairBuoyMedDmgState02.png",
      "shipFire04.pex?loc=12,-4&looping=true",
      "shipFire.pex?loc=-16,16&looping=true"
    }
  },
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01",
  warpEffect = "warpEffect.atlas.png",
  towedObjectTexture = "objects.atlas.png#repairBuoyMed.png",
  towedObjectRadius = 8,
  offscreenIndicatorTexture = "hud.atlas.png#indicatorRepairBuoy.png",
  offscreenIndicatorPulseRate = 4,
  offscreenIndicatorColor = UI_BUOY_IND_COLOR,
  ai = "resource_drift",
  rotSpeed = 3,
  type = "survivor"
}
_M.Escape_Pod_Mn_Sm = {
  texture = "objects.atlas.png#repairBuoySm.png",
  scl = 1,
  collision = {},
  collisionRadius = 40,
  maxspeed = 0,
  resourceType = "alloy",
  noSpin = true,
  damageTextures = {
    {
      "objects.atlas.png#repairBuoySmDmgState02.png",
      "shipFire04.pex?loc=12,-4&looping=true",
      "shipFire.pex?loc=-16,16&looping=true"
    }
  },
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01",
  warpEffect = "warpEffect.atlas.png",
  resourceTexture = "menuTemplateShared.atlas.png#iconAlloyMed.png",
  towedObjectRadius = 8,
  towedObjectTexture = "objects.atlas.png#repairBuoySm.png",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorRepairBuoy.png",
  offscreenIndicatorPulseRate = 4,
  offscreenIndicatorColor = UI_BUOY_IND_COLOR,
  ai = "resource_drift",
  rotSpeed = 3,
  type = "survivor"
}
_M.Escape_Pod_Mn_Med = {
  texture = "objects.atlas.png#repairBuoyMed.png",
  scl = 1,
  collision = {},
  collisionRadius = 45,
  maxspeed = 0,
  resourceType = "alloy",
  noSpin = true,
  damageTextures = {
    {
      "objects.atlas.png#repairBuoyMedDmgState02.png",
      "shipFire04.pex?loc=12,-4&looping=true",
      "shipFire.pex?loc=-16,16&looping=true"
    }
  },
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01",
  warpEffect = "warpEffect.atlas.png",
  resourceTexture = "menuTemplateShared.atlas.png#iconAlloyMed.png",
  towedObjectRadius = 8,
  towedObjectTexture = "objects.atlas.png#repairBuoyMed.png",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorRepairBuoy.png",
  offscreenIndicatorPulseRate = 4,
  offscreenIndicatorColor = UI_BUOY_IND_COLOR,
  ai = "resource_drift",
  rotSpeed = 3,
  type = "survivor"
}
_M.Escape_Pod_Mn_Lg = {
  texture = "objects.atlas.png#repairBuoyMed.png",
  scl = 1,
  collision = {},
  collisionRadius = 45,
  maxspeed = 0,
  resourceType = "alloy",
  noSpin = true,
  damageTextures = {
    {
      "objects.atlas.png#repairBuoyMedDmgState02.png",
      "shipFire04.pex?loc=12,-4&looping=true",
      "shipFire.pex?loc=-16,16&looping=true"
    }
  },
  deathfx = {
    "alienExplosionLarge.pex",
    "alienExplosionSparksLarge.pex"
  },
  deathSfx = "game_fighter_explosion_01",
  warpEffect = "warpEffect.atlas.png",
  resourceTexture = "menuTemplateShared.atlas.png#iconAlloyMed.png",
  towedObjectRadius = 8,
  towedObjectTexture = "objects.atlas.png#repairBuoyMed.png",
  offscreenIndicatorTexture = "hud.atlas.png#indicatorRepairBuoy.png",
  offscreenIndicatorPulseRate = 4,
  offscreenIndicatorColor = UI_BUOY_IND_COLOR,
  ai = "resource_drift",
  rotSpeed = 3,
  type = "survivor"
}
return _M
