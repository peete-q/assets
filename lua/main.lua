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

playerForce = scene:addForce(1)
enemyForce = scene:addForce(2)
timer.new(0.1, function()
	scene:update()
end)

function pointerCallback(x, y)
    X, Y = layer:wndToWorld(x, y)
end

local e
function clickCallbackL(down)
	if down then
		if not e then
			e = Entity.new({movable=false, bodyGfx="bg.png", attackRange = 10}, playerForce)
			scene:addUnit(e)
			
			local thread = MOAIThread.new()
			thread:run(function()
				while true do
					local n = math.random(80, 100) / 100
					MOAIThread.blockOnAction(e._body:seekScl(n, n, n, MOAIEaseType.SOFT_SMOOTH))
					MOAIThread.blockOnAction(e._body:seekScl(1, 1, n, MOAIEaseType.SOFT_SMOOTH))
				end
			end)
			e:setWorldLoc(X, Y)
		else
			scene:emitMoveSpeedAura(X, Y, 50, 3, 1, 2)
		end
	end
end

function clickCallbackR(down)
	if down then
		for i = 1, 1 do
			local e = Entity.new({bodyGfx="bg.png"}, enemyForce)
			-- scene:spawnUnit(e)
			scene:addUnit(e)
			e:setWorldLoc(X, Y)
			e:move()
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