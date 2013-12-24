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
render:set(MOAIParticleScript.SPRITE_RED, CONST(0.6862745098039216))
render:set(MOAIParticleScript.SPRITE_GREEN, CONST(0.9882352941176471))
render:set(MOAIParticleScript.SPRITE_BLUE, CONST(0.19607843137254902))
render:ease(MOAIParticleScript.SPRITE_OPACITY, CONST(0.5), CONST(0), MOAIEaseType.LINEAR)
render:ease(MOAIParticleScript.SPRITE_GLOW, CONST(1), CONST(0), MOAIEaseType.SHARP_EASE_IN)
render:ease(MOAIParticleScript.SPRITE_X_SCL, CONST(0.45), CONST(0.75), MOAIEaseType.LINEAR)
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
  state:setTerm(1.8, 1.8)
else
  state:setTerm(3.2, 3.2)
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
