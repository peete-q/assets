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
render:ease(MOAIParticleScript.SPRITE_RED, CONST(0.294), CONST(0), MOAIEaseType.SHARP_EASE_IN)
render:ease(MOAIParticleScript.SPRITE_GREEN, CONST(0.18), CONST(0), MOAIEaseType.SHARP_EASE_IN)
render:ease(MOAIParticleScript.SPRITE_BLUE, CONST(0.12), CONST(0), MOAIEaseType.SHARP_EASE_IN)
render:ease(MOAIParticleScript.SPRITE_OPACITY, CONST(0.6), CONST(0), MOAIEaseType.SHARP_EASE_IN)
render:ease(MOAIParticleScript.SPRITE_GLOW, CONST(1), CONST(1), MOAIEaseType.SHARP_EASE_IN)
render:set(MOAIParticleScript.SPRITE_Y_SCL, CONST(1))
local system = ui.new(MOAIParticleSystem.new())
system:reserveParticles(500, 1)
system:reserveSprites(500)
system:reserveStates(2)
local state = MOAIParticleState.new()
state:setTerm(1.8, 1.8)
state:setInitScript(init)
state:setRenderScript(render)
system:setState(1, state)
local deck = resource.deck("warpOutTrail.png")
system:setDeck(deck)
local emitters = {}
local defaultEmitter = ui.new(MOAIParticleDistanceEmitter.new())
defaultEmitter:setMagnitude(1)
defaultEmitter:setAngle(270, 270)
defaultEmitter:setDistance(7)
defaultEmitter:setSystem(system)
system:add(defaultEmitter)
emitters[#emitters + 1] = defaultEmitter
system.emitters = emitters
return system
