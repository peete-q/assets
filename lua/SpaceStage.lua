
local ui = require "ui"
local node = require "node"
local Unit = require "Unit"
local profile = require "UserProfile"
local device = require "device"
local Sprite = require "gfx.Sprite"

local blockOn = MOAIThread.blockOnAction
local SpaceStage = {}

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
	
	self._bgMoving = MOAIThread.new()
	self._bgMoving:run(function()
		while true do
			blockOn(bg:moveLoc(-w, 0, w / 3, MOAIEaseType.LINEAR))
		end
	end)
end

function SpaceStage:initMenu()
	local menuPanel = self._menuRoot:add(Image.new("menu-panel.png"))
	local w, h = menuPanel:getSize()
	menuPanel:setAnchor("RB", -w / 2, h / 2)
	menuPanel:setPriority(1)
	menuBack = self._menuRoot:add(ui.Button.new("menu-icon.png?scl=-1,1", "menu-icon.png?scl=-1.1,1.1"))
	menuBack:setPriority(2)
end

function SpaceStage:load()
	self._uiRoot = node.new()
	self._sceneRoot = node.new()
	self._farRoot = node.new()
	self._nearRoot = node.new()
	self._unitRoot = self._sceneRoot:add(node.new())

	self._ring = node.new()
	local ring01 = self._ring:add(Sprite.new("ring.png"))
	local ring02 = self._ring:add(Sprite.new("ring.png"))
	ring02:setColor(0, 0, 0, 0)
	self._ring:setTreePriority(1)
	local ringing = MOAIThread.new()
	ringing:run(function()
		while true do
			ring01:setScl(0, 0)
			ring01:setColor(0, 0, 0, 0)
			ring01:seekScl(0.5, 0.5, 1, MOAIEaseType.SOFT_EASE_IN)
			blockOn(ring01:seekColor(1, 1, 1, 1, 1, MOAIEaseType.SOFT_EASE_IN))
			
			ring02:setScl(0, 0)
			ring02:setColor(0, 0, 0, 0)
			ring02:seekScl(0.5, 0.5, 1, MOAIEaseType.SOFT_EASE_IN)
			ring02:seekColor(1, 1, 1, 1, 1, MOAIEaseType.SOFT_EASE_IN)
			
			ring01:seekScl(1, 1, 1, MOAIEaseType.LINEAR)
			blockOn(ring01:seekColor(0, 0, 0, 0, 1, MOAIEaseType.LINEAR))
			
			ring02:seekScl(1, 1, 1, MOAIEaseType.LINEAR)
			ring02:seekColor(0, 0, 0, 0, 1, MOAIEaseType.LINEAR)
		end
	end)
	
	self:initStageBG()
end

function SpaceStage:startFighting(o)
	self:close()
	self._gameStage:open(self, o._level)
end

local starfieldData = {
	units = {},
	width = device.width * 2,
	height = device.height * 2,
	spawnX = 0,
	spawnY = 0,
	initX = 0,
	initY = 0,
}

function SpaceStage:loadStarfield(data)
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
	self._motherShip:setPriority(10)
	camera:setLoc(data.initX, data.initY)
	self._xMin = (device.width - data.width) / 2
	self._xMax = (data.width - device.width) / 2
	self._yMin = (device.height - data.height) / 2
	self._yMax = (data.height - device.height) / 2
end

local self = SpaceStage
function SpaceStage.onClickUnit(o, touchIdx, x, y, tapCount)
	self._motherShip:moveTo(x, y)
	self._motherShip:whenArrive(function()
		self:startFighting(o)
	end)
end

local lastX, lastY
function SpaceStage:onDragBegin(touchIdx, x, y, tapCount)
	lastX = x
	lastY = y
	return true
end

function SpaceStage:onDragMove(touchIdx, x, y, tapCount)
	local diffX = x - lastX
	local diffY = y - lastY
	lastX = x
	lastY = y
	local x, y = camera:getLoc()
	x = math.clamp(x - diffX, self._xMin, self._xMax)
	y = math.clamp(y + diffY, self._yMin, self._yMax)
	camera:setLoc(x, y)
end

function SpaceStage:onClick(touchIdx, x, y, tapCount)
	local wx, wy = sceneLayer:wndToWorld(x, y)
	self._motherShip:moveTo(wx, wy)
	self._sceneRoot:add(self._ring)
	self._ring:setLoc(wx, wy)
	self._motherShip:whenArrive(function()
		self._sceneRoot:remove(self._ring)
	end)
end

function SpaceStage:open()
	if not self._loaded then
		self:load()
		self._loaded = true
	end
	self:loadStarfield(starfieldData)
	
	farLayer:add(self._farRoot)
	nearLayer:add(self._nearRoot)
	sceneLayer:add(self._sceneRoot)
	uiLayer:add(self._uiRoot)
	
	ui.insertLayer(sceneLayer, 1)
	ui.defaultTouchHandler = self
end

function SpaceStage:close()
	farLayer:remove(self._farRoot)
	nearLayer:remove(self._nearRoot)
	sceneLayer:remove(self._sceneRoot)
	uiLayer:remove(self._uiRoot)
	
	ui.removeLayer(sceneLayer)
	ui.defaultTouchHandler = nil
end

return SpaceStage