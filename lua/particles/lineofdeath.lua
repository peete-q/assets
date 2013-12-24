local CONST = MOAIParticleScript.packConst
local PI = math.pi
local cos = math.cos
local sin = math.sin
local r1 = MOAIParticleScript.packReg(1)
local r2 = MOAIParticleScript.packReg(2)
local r3 = MOAIParticleScript.packReg(3)
local r4 = MOAIParticleScript.packReg(4)
local r5 = MOAIParticleScript.packReg(5)
local r6 = MOAIParticleScript.packReg(6)
local init = MOAIParticleScript.new()
init:rand(r1, CONST(0.43), CONST(0.76))
init:norm(r2, r3, MOAIParticleScript.PARTICLE_DX, MOAIParticleScript.PARTICLE_DY)
init:div(r4, MOAIParticleScript.PARTICLE_DX, r2)
init:div(r5, MOAIParticleScript.PARTICLE_DY, r3)
init:mul(r2, MOAIParticleScript.PARTICLE_DY, CONST(-1))
init:mul(r3, MOAIParticleScript.PARTICLE_DX, CONST(1))
init:mul(MOAIParticleScript.PARTICLE_DX, r2, r4)
init:mul(MOAIParticleScript.PARTICLE_DY, r3, r5)
local render = MOAIParticleScript.new()
render:sprite()
render:ease(r4, CONST(0), MOAIParticleScript.PARTICLE_Y, MOAIEaseType.LINEAR)
render:add(MOAIParticleScript.PARTICLE_X, MOAIParticleScript.PARTICLE_X, r2)
render:add(MOAIParticleScript.PARTICLE_Y, MOAIParticleScript.PARTICLE_Y, r3)
render:ease(MOAIParticleScript.SPRITE_OPACITY, CONST(1), CONST(0), MOAIEaseType.LINEAR)
render:ease(MOAIParticleScript.SPRITE_RED, CONST(1), CONST(1), MOAIEaseType.LINEAR)
render:mul(MOAIParticleScript.SPRITE_RED, MOAIParticleScript.SPRITE_RED, MOAIParticleScript.SPRITE_RED)
render:set(MOAIParticleScript.SPRITE_GREEN, CONST(0), MOAIParticleScript.SPRITE_OPACITY)
render:set(MOAIParticleScript.SPRITE_BLUE, CONST(0), MOAIParticleScript.SPRITE_OPACITY)
render:mul(MOAIParticleScript.SPRITE_GLOW, CONST(0), MOAIParticleScript.SPRITE_OPACITY)
render:ease(MOAIParticleScript.SPRITE_X_SCL, r1, CONST(0.6), MOAIEaseType.LINEAR)
render:mul(MOAIParticleScript.SPRITE_X_SCL, MOAIParticleScript.SPRITE_X_SCL, CONST(30))
render:set(MOAIParticleScript.SPRITE_Y_SCL, MOAIParticleScript.SPRITE_X_SCL)
local system = ui.new(MOAIParticleSystem.new())
system:reserveParticles(200, 6)
system:reserveSprites(200)
system:reserveStates(1)
local state = MOAIParticleState.new()
state:setTerm(0.7, 1.3)
state:setInitScript(init)
state:setRenderScript(render)
system:setState(1, state)
local deck = resource.deck("hardsphere.png")
system:setDeck(deck)
local emitters = {}
local defaultEmitter = ui.new(MOAIParticleTimedEmitter.new())
defaultEmitter:setMagnitude(5)
defaultEmitter:setAngle(0, 0)
defaultEmitter:setEmission(4)
defaultEmitter:setFrequency(0.05)
defaultEmitter:setSystem(system)
defaultEmitter:setRect(-10, 0, 10, 0)
system:add(defaultEmitter)
emitters[#emitters + 1] = defaultEmitter
system.emitters = emitters
function system:setParticleLength(len)
  if not len then
    return
  end
  local t = len / 280
  state:setTerm(t, t)
end
return system
