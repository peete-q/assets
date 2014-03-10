
local node = require "node"
local util = require "util"
local url = require "url"

local breakstr = util.breakstr

local Image = {}

function Image.getSize(self)
	if not self or not self._deck or not self._deck.getSize then
		return nil
	end
	local w, h = self._deck:getSize(self.deckLayer)
	local x, y = self:getScl()
	return w * x, h * y
end

function Image.setImage(self, imageName)
	if not imageName then
		self:setDeck(nil)
		self._deck = nil
		return
	end
	local imageName, queryStr = breakstr(imageName, "?")
	local deckName, layerName = breakstr(imageName, "#")
	local deck = resource.deck(deckName)
	self:setDeck(deck)
	if layerName ~= nil then
		self:setIndex(deck:indexOf(layerName))
		self.deckLayer = layerName
	end
	self.deckIndex = deck:indexOf(layerName)
	self:setScl(1, 1)
	self:setRot(0)
	self:setLoc(0, 0)
	self:setColor(1, 1, 1, 1)
	if queryStr ~= nil then
		local q = url.parse_query(queryStr)
		if q.scl ~= nil then
			local x, y = breakstr(q.scl, ",")
			self:setScl(tonumber(x), tonumber(y or x))
		end
		if q.rot ~= nil then
			local rot = tonumber(q.rot)
			self:setRot(rot)
		end
		if q.pri ~= nil then
			local pri = tonumber(q.pri)
			self:setPriority(pri)
		end
		if q.loc ~= nil then
			local x, y = breakstr(q.loc, ",")
			self:setLoc(tonumber(x), tonumber(y))
		end
		if q.alpha ~= nil then
			self:setColor(1, 1, 1, tonumber(q.alpha))
		end
	end
	self._deck = deck
end

function Image.new(imageName)
	local o = node.new(MOAIProp2D.new())
	o.getSize = Image.getSize
	o.setImage = Image.setImage
	
	if type(imageName) == "userdata" then
		local tex = imageName
		local deck = MOAIGfxQuad2D.new()
		deck:setTexture(tex)
		local w, h = tex:getSize()
		deck:setRect(-w / 2, -h / 2, w / 2, h / 2)
		o:setDeck(deck)
		o._deck = deck
	else
		o:setImage(imageName)
	end
	return o
end

return Image