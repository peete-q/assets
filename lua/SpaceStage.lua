
local ui = require "ui"
local node = require "node"
local profile = require "UserProfile"

local SpaceStage = {}

function SpaceStage:init(homeStgae, gameStage)
	self._homeStage = homeStage
	self._gameStage = gameStage
end

function SpaceStage:initStageBG()
	self._sceneRoot = node.new()
	
	local bg = self._sceneRoot:add(node.new())
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
end

function SpaceStage:open()
	if not self._loaded then
		self:load()
		self._loaded = true
	end
	uiLayer:add(self._uiRoot)
	sceneLayer:add(self._sceneRoot)
end

function SpaceStage:close()
	uiLayer:remove(self._uiRoot)
	sceneLayer:remove(self._sceneRoot)
end

return SpaceStage