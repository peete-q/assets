require "constants"
local device = require "device"
local util = require "util"
local ui = require "ui"
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

spaceLayer = MOAILayer2D.new()
spaceLayer:setViewport(viewport)
MOAISim.pushRenderPass(spaceLayer)

sceneLayer = MOAILayer2D.new()
sceneLayer:setViewport(viewport)
MOAISim.pushRenderPass(sceneLayer)

uiLayer = ui.Layer.new(viewport)
uiLayer._uiname = "uiLayer"
uiLayer:setSortMode(MOAILayer2D.SORT_PRIORITY_ASCENDING)
uiLayer:setPriority(1)

popupLayer = ui.Layer.new(viewport)
popupLayer._uiname = "popupLayer"
popupLayer:setSortMode(MOAILayer2D.SORT_PRIORITY_ASCENDING)
popupLayer:setPriority(1)

local HomeStage = require "HomeStage"
local GameStage = require "GameStage"
local Scene = require "Scene"
local Unit = require "Unit"
local Bullet = require "Bullet"
local timer = require "timer"

HomeStage:init()
HomeStage:load()

local lastdate
timer.new(0.1, function()
	HomeStage:update()
	local tb = lfs.attributes("test.lua")
	if lastdate ~= tb.modification then
		lastdate = tb.modification
		dofile "test.lua"
	end
end)

if true then return end

W, H = device.width, device.height
layer = uiLayer

scene = Scene.new(W, H, layer)

local aiProps = {
	bodyGfx="icon-earth.png",
	attackRange = 10,
	movable = false,
}

local playerProps = {
	bodyGfx="icon-earth.png",
	movable = true,
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

timer.new(0.1, function()
	scene:update()
end)

function pointerCallback(x, y)
    X, Y = layer:wndToWorld(x, y)
end

function clickCallbackL(down)
	if down then
		local p = scene:spawnPlayerUnit(playerProps)
		p._logging = true
	end
end

function clickCallbackR(down)
	if down then
		for i = 1, 1 do
			scene:spawnEnemyUnit(aiProps)
		end
	end
end

if MOAIInputMgr.device.pointer then
	-- mouse input
	MOAIInputMgr.device.pointer:setCallback(pointerCallback)
	MOAIInputMgr.device.mouseLeft:setCallback(clickCallbackL)
	MOAIInputMgr.device.mouseRight:setCallback(clickCallbackR)
end