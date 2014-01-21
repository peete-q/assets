package.path = "../?.lua;?.lua"
require "init"
require "constants"

function printf ( ... )
	return io.stdout:write ( string.format ( ... ))
end 

MOAISim.openWindow ( "test", 320, 240 )

W, H = 320, 240
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
local Entity = require "Entity"
local timer = require "timer"

scene = Scene.new(W, H, layer)

local aiProps = {
	bodyGfx="bg.png",
	attackRange = 10,
}

local playerProps = {
	bodyGfx="bg.png",
	movable = false,
	attackPower = 50,
	shots = 3,
}

local aiInfo = {
	loopBegin = 30,
	[1] = {props = aiProps, nb = 2},
	[30] = {props = aiProps, nb = 3},
	[60] = {props = aiProps, nb = 5},
}
-- scene:loadAI(aiInfo)

player = scene:newForce(Entity.FORCE_PLAYER)
enemy = scene:newForce(Entity.FORCE_ENEMY)
timer.new(0.1, function()
	scene:update()
end)

function pointerCallback(x, y)
    X, Y = layer:wndToWorld(x, y)
end

local e
function clickCallbackL(down)
	if down then
		local e = scene:newUnit(playerProps, Entity.FORCE_PLAYER, X, Y)
	end
end

function clickCallbackR(down)
	if down then
		for i = 1, 1 do
			local e = scene:newUnit(aiProps, Entity.FORCE_ENEMY, X, Y)
			e:setWorldLoc(X, Y)
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