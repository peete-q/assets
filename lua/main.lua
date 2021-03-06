require "constants"
local device = require "device"
local util = require "util"
local ui = require "ui"
local layer = require "layer"
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

camera = MOAICamera2D.new ()

viewport = MOAIViewport.new()
viewport:setScale(device.width, device.height)
viewport:setSize(0, 0, device.width, device.height)

farLayer = layer.new(viewport)
farLayer:setCamera(camera)
farLayer:setParallax(0.1, 0.1)
farLayer:setSortMode(MOAILayer2D.SORT_PRIORITY_ASCENDING)
farLayer._uiname = "farLayer"

nearLayer = layer.new(viewport)
nearLayer:setCamera(camera)
nearLayer:setParallax(0.3, 0.3)
nearLayer:setSortMode(MOAILayer2D.SORT_PRIORITY_ASCENDING)
nearLayer._uiname = "nearLayer"

sceneLayer = layer.new(viewport)
sceneLayer:setCamera (camera)
sceneLayer:setSortMode(MOAILayer2D.SORT_PRIORITY_ASCENDING)
sceneLayer._uiname = "sceneLayer"

uiLayer = layer.new(viewport)
uiLayer:setSortMode(MOAILayer2D.SORT_PRIORITY_ASCENDING)
uiLayer._uiname = "uiLayer"

popupLayer = layer.new(viewport)
popupLayer:setSortMode(MOAILayer2D.SORT_PRIORITY_ASCENDING)
popupLayer._uiname = "popupLayer"

ui.init()
ui.insertLayer(uiLayer)
ui.insertLayer(popupLayer)

mainAS = actionset.new()

local HomeStage = require "HomeStage"
local GameStage = require "GameStage"
local SpaceStage = require "SpaceStage"
local Battlefield = require "Battlefield"
local Unit = require "Unit"
local Bullet = require "Bullet"
local timer = require "timer"

HomeStage:init(SpaceStage, GameStage)
SpaceStage:init(HomeStage, GameStage)
GameStage:init(SpaceStage, HomeStage)

GameStage:open()

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

scene = Battlefield.new(W, H, layer)

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