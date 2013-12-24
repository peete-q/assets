local device = require("device")
local CONST = MOAIParticleScript.packConst
local r1 = MOAIParticleScript.packReg(1)
local r2 = MOAIParticleScript.packReg(2)
local r3 = MOAIParticleScript.packReg(3)
local r4 = MOAIParticleScript.packReg(4)
local init = MOAIParticleScript.new()
init:vecAngle(r1, MOAIParticleScript.PARTICLE_DX, MOAIParticleScript.PARTICLE_DY)
init:sub(r1, CONST(180), r1)
init:rand(r2, CONST(0.8), CONST(1.4))
init:rand(r3, CONST(-0.06), CONST(0.06))
init:rand(r4, CONST(-0.06), CONST(0.06))
local render = MOAIParticleScript.new()
render:sprite()
render:set(MOAIParticleScript.SPRITE_ROT, r1)
render:mul(MOAIParticleScript.PARTICLE_X, MOAIParticleScript.PARTICLE_X, MOAIParticleScript.SPRITE_X_SCL)
render:mul(MOAIParticleScript.PARTICLE_Y, MOAIParticleScript.PARTICLE_Y, MOAIParticleScript.SPRITE_Y_SCL)
render:add(MOAIParticleScript.PARTICLE_X, MOAIParticleScript.PARTICLE_X, r3)
render:add(MOAIParticleScript.PARTICLE_Y, MOAIParticleScript.PARTICLE_Y, r4)
render:ease(MOAIParticleScript.SPRITE_OPACITY, CONST(1), CONST(0), MOAIEaseType.LINEAR)
render:mul(MOAIParticleScript.SPRITE_RED, CONST(0.9215686274509803), MOAIParticleScript.SPRITE_OPACITY)
render:mul(MOAIParticleScript.SPRITE_GREEN, CONST(0.23529411764705882), MOAIParticleScript.SPRITE_OPACITY)
render:mul(MOAIParticleScript.SPRITE_BLUE, CONST(0.0392156862745098), MOAIParticleScript.SPRITE_OPACITY)
render:set(MOAIParticleScript.SPRITE_GLOW, CONST(1))
render:ease(MOAIParticleScript.SPRITE_X_SCL, r2, CONST(0.3), MOAIEaseType.LINEAR)
render:set(MOAIParticleScript.SPRITE_Y_SCL, MOAIParticleScript.SPRITE_X_SCL)
local system = ui.new(MOAIParticleSystem.new())
if device.cpu == device.CPU_LO then
  system:reserveParticles(48, 4)
  system:reserveSprites(48)
else
  system:reserveParticles(96, 4)
  system:reserveSprites(96)
end
system:reserveStates(2)
local state = MOAIParticleState.new()
if device.cpu == device.CPU_LO then
  state:setTerm(1.4, 1.4)
else
  state:setTerm(2.4, 2.4)
end
state:setInitScript(init)
state:setRenderScript(render)
system:setState(1, state)
local deck = resource.deck("ribbonTextureEnemy.png")
system:setDeck(deck)
local emitters = {}
local defaultEmitter = ui.new(MOAIParticleDistanceEmitter.new())
defaultEmitter:setMagnitude(1)
defaultEmitter:setAngle(270, 270)
if device.cpu == device.CPU_LO then
  defaultEmitter:setDistance(3.2)
else
  defaultEmitter:setDistance(1.2)
end
defaultEmitter:setSystem(system)
system:add(defaultEmitter)
emitters[#emitters + 1] = defaultEmitter
system.emitters = emitters
return system
