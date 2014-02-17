require "constants"
local device = require "device"
local util = require "util"
local ui = require "ui.base"
local actionset = require "actionset"
local resource = require "resource"
local memory = require "memory"
local timerutil = require "timerutil"
local appcache = require "appcache"
local keys = require "keys"
local bucket = resource.bucket
local update = require "update"
local environment = require "environment"
local qlog = require "qlog"
local randutil = require "randutil"
randutil.randomseed()
if os.getenv("NO_SOUND") then
  MOAIUntzSystem = nil
end
local gettext = require("gettext.gettext")
if os.getenv("I18N_TEST") then
  gettext.setlang("*")
else
  gettext.setlang(PREFERRED_LANGUAGES, "mo/?.mo")
end
MOAISim.openWindow(_("SBC"), device.width, device.height)
ui.init()

viewport = MOAIViewport.new()
viewport:setScale(device.width, device.height)
viewport:setSize(0, 0, device.width, device.height)

perspectiveLayer = MOAILayer2D.new()
perspectiveLayer:setViewport(viewport)
MOAISim.pushRenderPass(perspectiveLayer)
sceneLayer = MOAILayer2D.new()
sceneLayer:setViewport(viewport)
MOAISim.pushRenderPass(sceneLayer)

uiLayer = ui.Layer.new(viewport)
uiLayer._uiname = "uiLayer"
uiLayer:setSortMode(MOAILayer2D.SORT_PRIORITY_ASCENDING)

mainAS = actionset.new()
mainAS:start()

local HomeStage = require "HomeStage"

HomeStage:init()
HomeStage:load()

W, H = device.width, device.height
layer = uiLayer

local Scene = require "Scene"
local Unit = require "Unit"
local Bullet = require "Bullet"
local timer = require "timer"

timer.new(0.1, function() dofile "test.lua" end)

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
			print(X, Y)
			-- e:move()
		end
	end
end

if MOAIInputMgr.device.pointer then
	-- mouse input
	-- MOAIInputMgr.device.pointer:setCallback(pointerCallback)
	-- MOAIInputMgr.device.mouseLeft:setCallback(clickCallbackL)
	-- MOAIInputMgr.device.mouseRight:setCallback(clickCallbackR)
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