
local ui = require "ui"
local node = require "node"
local Unit = require "Unit"
local profile = require "UserProfile"
local device = require "device"

local blockOn = MOAIThread.blockOnAction
local SpaceStage = {}
local self = HomeStage

function SpaceStage:init(homeStgae, gameStage)
	self._homeStage = homeStage
	self._gameStage = gameStage
end

function SpaceStage:initStageBG()
	self._sceneRoot = node.new()
	
	self._deepRoot = node.new()
	local bg = self._deepRoot:add(node.new())
	local deck = MOAITileDeck2D.new()
	local tex = resource.texture("starfield.jpg")
	deck:setTexture(tex)
	local w, h = tex:getSize()
	deck:setSize(1, 1)
	deck:setRect (-0.5, 0.5, 0.5, -0.5)
	local grid = MOAIGrid.new ()
	grid:setSize(1, 1, w, h)
	grid:setRepeat ( true )
	grid:setRow(1, 1)
	bg:setDeck(deck)
	bg:setGrid(grid)
	
	self._bgAnimating = MOAIThread.new()
	self._bgAnimating:run(function()
		while true do
			blockOn(bg:moveLoc(-w, 0, w / 3, MOAIEaseType.LINEAR))
		end
	end)
end

function SpaceStage:load()
	self._uiRoot = ui.new()
	self:initStageBG()
	
	self._motherShip = self._sceneRoot:add(profile.motherShip)
end

function SpaceStage.onClickUnit(o, touchIdx, x, y, tapCount)
	self._motherShip:moveTo(x, y)
	self._motherShip:whenArrive(function()
		self.startFighting(o)
	end)
end

function SpaceStage:loadLevel(level)
	local force = {}
	for i, v in ipairs(level.units) do
		local o = self._sceneRoot:add(Unit.new(v.props, force))
		o:setLoc(v.x, v.y)
		o.onClick = self.onClickUnit
	end
	self._motherShip = self._sceneRoot:add(Unit.new(profile.motherShip))
	self._motherShip:setLoc(level.motherShipX, level.motherShipY)
	self._sceneRoot:setLoc(level.initX, level.initY)
	self._xMin = (device.width - w) / 2
	self._xMax = (w - device.width) / 2
	self._yMin = (device.height - h) / 2
	self._yMax = (h - device.height) / 2
end

local draging, lastX, lastY, downX, downY
function HomeStage.onTouchDown(touchIdx, x, y, tapCount)
	downX = x
	downY = y
	lastX = x
	lastY = y
	draging = true
end

function HomeStage.onTouchMove(touchIdx, x, y, tapCount)
	local diffX = x - lastX
	local diffY = y - lastY
	lastX = x
	lastY = y
	local x, y = self._sceneRoot:getLoc()
	x = math.clamp(x + diffX, self._xMin, self._xMax)
	y = math.clamp(y + diffY, self._yMin, self._yMax)
	self._sceneRoot:setLoc(x, y)
end

function HomeStage.onTouchUp(touchIdx, x, y, tapCount)
	local absX = math.abs(x - downX)
	local absY = math.abs(y - downY)
	if absX < 3 and absY < 3 then
		self._motherShip:moveTo(x, y)
		self._motherShip:whenArrive(nil)
	end
	draging = false
end

function SpaceStage:open()
	if not self._loaded then
		self:load()
		self._loaded = true
	end
	uiLayer:add(self._uiRoot)
	sceneLayer:add(self._sceneRoot)
	deepLayer:add(self._deepRoot)
	ui.insertLayer(sceneLayer)
	ui.setDefaultTouchCallback(self)
end

function SpaceStage:close()
	uiLayer:remove(self._uiRoot)
	sceneLayer:remove(self._sceneRoot)
	deepLayer:remove(self._deepRoot)
	ui.removeLayer(sceneLayer)
end

return SpaceStage