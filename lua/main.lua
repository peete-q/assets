package.path = "../?.lua;?.lua"
require "init"
require "constants"

function printf ( ... )
	return io.stdout:write ( string.format ( ... ))
end 

W, H = 600, 400
MOAISim.openWindow ( "test", W, H)
viewport = MOAIViewport.new ()
viewport:setSize ( W, H )
viewport:setScale ( W, H )

layer = MOAILayer2D.new ()
layer:setViewport ( viewport )
MOAISim.pushRenderPass ( layer )

-- set up the world and start its simulation
world = MOAIBox2DWorld.new ()
-- world:setGravity ( 0, -10 )
world:setUnitsToMeters ( 1 )
world:start ()
layer:setBox2DWorld ( world )

local Scene = require "Scene"
local Unit = require "Unit"
local Bullet = require "Bullet"
local timer = require "timer"

scene = Scene.new(W, H, layer)

local aiProps = {
	bodyGfx="icon-earth.png",
	attackRange = 10,
	movable = false,
}

local playerProps = {
	bodyGfx="icon-earth.png",
	movable = false,
	attackPower = 100,
	shots = 1,
	attackRange = 200,
	bullet = {bombRun = Bullet.bombEvent.spread, bombCmd = {{}, W, 3}},
}

local aiInfo = {
	loopBegin = 30,
	[1] = {aiProps, 1, 3},
	[30] = {aiProps, 2, 3},
	[60] = {aiProps, 3, 5},
}
-- scene:loadAI(aiInfo)

player = scene:newForce(Unit.FORCE_PLAYER)
enemy = scene:newForce(Unit.FORCE_ENEMY)
timer.new(0.1, function()
	scene:update()
end)

function pointerCallback(x, y)
    X, Y = layer:wndToWorld(x, y)
end

local p
function clickCallbackL(down)
	if down then
		p = scene:newUnit(playerProps, Unit.FORCE_PLAYER, X, Y)
		p._logging = true
	end
end

function clickCallbackR(down)
	if down then
		for i = 1, 1 do
			local e = scene:newUnit(aiProps, Unit.FORCE_ENEMY, X, Y)
			e:setWorldLoc(X, Y)
			-- p._ticks = scene.ticks - 20
			-- e:move()
		end
	end
end

if MOAIInputMgr.device.pointer then
	-- mouse input
	MOAIInputMgr.device.pointer:setCallback(pointerCallback)
	MOAIInputMgr.device.mouseLeft:setCallback(clickCallbackL)
	MOAIInputMgr.device.mouseRight:setCallback(clickCallbackR)
else
	-- touch input
	MOAIInputMgr.device.touch:setCallback (function(eventType, idx, x, y, tapCount)
		if idx ~= 0 then
			return
		end
		pointerCallback(x, y)
		if eventType == MOAITouchSensor.TOUCH_DOWN then
			clickCallback(true)
		elseif eventType == MOAITouchSensor.TOUCH_UP then
			clickCallback(false)
		end
	end)
end