local device = require("device")
local CONST = MOAIParticleScript.packConst
local r1 = MOAIParticleScript.packReg(1)
local init = MOAIParticleScript.new()
init:vecAngle(r1, MOAIParticleScript.PARTICLE_DX, MOAIParticleScript.PARTICLE_DY)
init:sub(r1, CONST(180), r1)
local render = MOAIParticleScript.new()
render:sprite()
render:set(MOAIParticleScript.SPRITE_ROT, r1)
render:mul(MOAIParticleScript.PARTICLE_X, MOAIParticleScript.PARTICLE_X, MOAIParticleScript.SPRITE_X_SCL)
render:mul(MOAIParticleScript.PARTICLE_Y, MOAIParticleScript.PARTICLE_Y, MOAIParticleScript.SPRITE_Y_SCL)
render:set(MOAIParticleScript.SPRITE_RED, CONST(0.37254901960784315))
render:set(MOAIParticleScript.SPRITE_GREEN, CONST(0.8235294117647058))
render:set(MOAIParticleScript.SPRITE_BLUE, CONST(1))
render:ease(MOAIParticleScript.SPRITE_OPACITY, CONST(0.65), CONST(0), MOAIEaseType.LINEAR)
render:ease(MOAIParticleScript.SPRITE_GLOW, CONST(1), CONST(0), MOAIEaseType.EASE_IN)
render:ease(MOAIParticleScript.SPRITE_X_SCL, CONST(0.5), CONST(0.8), MOAIEaseType.LINEAR)
render:set(MOAIParticleScript.SPRITE_Y_SCL, CONST(1))
local system = ui.new(MOAIParticleSystem.new())
if device.cpu == device.CPU_LO then
  system:reserveParticles(48, 1)
  system:reserveSprites(48)
else
  system:reserveParticles(96, 1)
  system:reserveSprites(96)
end
system:reserveStates(2)
local state = MOAIParticleState.new()
if device.cpu == device.CPU_LO then
  state:setTerm(1.6, 1.6)
else
  state:setTerm(3, 3)
end
state:setInitScript(init)
state:setRenderScript(render)
system:setState(1, state)
local deck = resource.deck("ribbonTexture.png")
system:setDeck(deck)
local emitters = {}
local defaultEmitter = ui.new(MOAIParticleDistanceEmitter.new())
defaultEmitter:setMagnitude(1)
defaultEmitter:setAngle(270, 270)
if device.cpu == device.CPU_LO then
  defaultEmitter:setDistance(7)
else
  defaultEmitter:setDistance(4.6)
end
defaultEmitter:setSystem(system)
system:add(defaultEmitter)
emitters[#emitters + 1] = defaultEmitter
system.emitters = emitters
return system
