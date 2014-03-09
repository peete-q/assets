
local ui = require "ui"
local node = require "node"
local Unit = require "Unit"
local profile = require "UserProfile"
local device = require "device"
local Sprite = require "Sprite"

local blockOn = MOAIThread.blockOnAction
local SpaceStage = {}
local self = SpaceStage
local VISTA_PARALLAX = 0.2

function SpaceStage:init(homeStgae, gameStage)
	self._homeStage = homeStage
	self._gameStage = gameStage
end

function SpaceStage:initStageBG()
	local bg = self._farRoot:add(node.new())
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
	self._sceneRoot = node.new()
	self._farRoot = node.new()
	self._nearRoot = node.new()
	self._unitRoot = self._sceneRoot:add(node.new())
	self:initStageBG()
end

function SpaceStage:startFighting(o)
	self:close()
	self._gameStage:open(self, o._level)
end

function SpaceStage.onClickUnit(o, touchIdx, x, y, tapCount)
	self._motherShip:moveTo(x, y)
	self._motherShip:whenArrive(function()
		self:startFighting(o)
	end)
end

local space = {
	units = {},
	width = device.width * 2,
	height = device.height * 2,
	spawnX = 0,
	spawnY = 0,
	initX = 0,
	initY = 0,
}

function SpaceStage:loadSpace(data)
	local planet = self._nearRoot:add(Sprite.new("mars.png"))
	planet:setLoc(-500, 0)
	
	local planet = self._nearRoot:add(Sprite.new("planet01.png?scl=0.6"))
	planet:setLoc(0, -100)
	
	local planet = self._nearRoot:add(Sprite.new("planet04.png?scl=0.5"))
	planet:setLoc(330, 100)
	
	self._forces = Unit.newForceList()
	local enemy = self._forces[Unit.FORCE_ENEMY]
	local player = self._forces[Unit.FORCE_PLAYER]
	self._unitRoot:removeAll()
	for i, v in ipairs(data.units) do
		local o = self._unitRoot:add(Unit.new(v.props, enemy))
		o:setLoc(v.x, v.y)
		o._level = v.level
		o.onClick = self.onClickUnit
	end
	self._motherShip = self._unitRoot:add(Unit.new(profile.motherShip, player))
	self._motherShip:setLoc(data.spawnX, data.spawnY)
	camera:setLoc(data.initX, data.initY)
	self._xMin = (device.width - data.width) / 2
	self._xMax = (data.width - device.width) / 2
	self._yMin = (device.height - data.height) / 2
	self._yMax = (data.height - device.height) / 2
end

local draging, lastX, lastY, downX, downY
function SpaceStage.onTouchDown(touchIdx, x, y, tapCount)
	downX = x
	downY = y
	lastX = x
	lastY = y
	draging = true
end

function SpaceStage.onTouchMove(touchIdx, x, y, tapCount)
	local diffX = x - lastX
	local diffY = y - lastY
	lastX = x
	lastY = y
	local x, y = camera:getLoc()
	x = math.clamp(x - diffX, self._xMin, self._xMax)
	y = math.clamp(y + diffY, self._yMin, self._yMax)
	camera:setLoc(x, y)
end

function SpaceStage.onTouchUp(touchIdx, x, y, tapCount)
	local absX = math.abs(x - downX)
	local absY = math.abs(y - downY)
	if absX < 3 and absY < 3 then
		local wx, wy = sceneLayer:wndToWorld(x, y)
		self._motherShip:moveTo(wx, wy)
		self._motherShip:whenArrive(nil)
	end
	draging = false
end

function SpaceStage:open()
	if not self._loaded then
		self:load()
		self._loaded = true
	end
	self:loadSpace(space)
	
	farLayer:add(self._farRoot)
	nearLayer:add(self._nearRoot)
	sceneLayer:add(self._sceneRoot)
	uiLayer:add(self._uiRoot)
	
	ui.insertLayer(farLayer, 1)
	ui.insertLayer(nearLayer, 2)
	ui.insertLayer(sceneLayer, 3)
	
	ui.setDefaultTouchCallback(self)
end

function SpaceStage:close()
	farLayer:remove(self._farRoot)
	nearLayer:remove(self._nearRoot)
	sceneLayer:remove(self._sceneRoot)
	uiLayer:remove(self._uiRoot)
	
	ui.removeLayer(farLayer)
	ui.removeLayer(nearLayer)
	ui.removeLayer(sceneLayer)
end

return SpaceStage