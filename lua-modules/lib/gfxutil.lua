
local Image = require "gfx.Image"
local Sprite = require "gfx.Sprite"
local ParticleSystem = require "gfx.ParticleSystem"

local gfxutil = {}

function gfxutil.parse(o)
	if type(o) == "string" then
		return Image.new(o)
	elseif type(o) == "userdata" then
		return o
	end
	return o
end

function gfxutil.createTilingBG(texname)
	local tex = resource.texture(texname)
	local w, h = tex:getSize()
	local tileDeck = MOAITileDeck2D.new()
	tileDeck:setTexture(tex)
	tileDeck:setSize(1, 1)
	local grid = MOAIGrid.new()
	grid:setSize(1, 1, w, h)
	grid:setRow(1, 1)
	grid:setRepeat(true)
	local prop = ui.new(MOAIProp2D.new())
	prop:setDeck(tileDeck)
	prop:setGrid(grid)
	prop:setLoc(-device.width / 2 - w / 2, 0)
	prop.height = h
	prop.width = w
	return prop
end

return gfxutil