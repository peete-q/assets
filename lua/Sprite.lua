local url = require "url"
local util = require "util"
local node = require "node"

local breakstr = util.breakstr

local Sprite = {}

local function Sprite_getSize(self)
	if not self or not self._deck or not self._deck.getSize then
		return nil
	end
	return self._deck:getSize(self.deckLayer)
end

local function Sprite_parse(self, imageName)
	local imageName, queryStr = breakstr(imageName, "?")
	local deckName, layerName = breakstr(imageName, "#")
	local deck = resource.deck(deckName)
	self:setDeck(deck)
	if layerName then
		self:setIndex(deck:indexOf(layerName))
		self.deckLayer = layerName
		self.deckIndex = deck:indexOf(layerName)
	end
	if queryStr then
		local q = url.parse_query(queryStr)
		local dur
		if q.dur then
			dur = tonumber(q.dur)
		end
		if q.scl then
			local scl = tonumber(q.scl)
			self:setScl(scl, scl)
		end
		if q.rot then
			local rot = tonumber(q.rot)
			self:setRot(rot)
		end
		if q.pri then
			local pri = tonumber(q.pri)
			self:setPriority(pri)
		end
		if q.loc then
			local x, y = breakstr(q.loc, ",")
			self:setLoc(tonumber(x), tonumber(y))
		end
		if q.alpha then
			self:setColor(1, 1, 1, tonumber(q.alpha))
		end
		if q.image then
			self:setIndex(deck:indexOf(q.image))
		elseif q.index then
			self:setIndex(tonumber(q.index))
		elseif q.play then
			self:playAnim(q.play, nil, true)
		elseif q.playOnce then
			self:playAnim(q.playOnce)
		end
	end
end

local function Sprite_setImage(self, name)
	local index = self._deck:indexOf(name)
	self:setIndex(index)
end

local function Sprite_destroy(self)
	self:stopAnim()
	
	if self.onDestroy then
		self:onDestroy()
	end
	
	if self._olderSpriteDestroy then
		self._olderSpriteDestroy(self)
	end
end

local function Sprite_stopAnim(self)
	if self._anim then
		self._anim:stop()
		self._anim = nil
	end
	if self._animProp then
		self:remove(self._animProp)
		self._animProp = nil
	end
end

local function Sprite_playAnim(self, animName, callback, looping)
	if self._anim then
		self._anim:stop()
		self._anim:clear()
		self._anim = nil
	end
	if self._animProp then
		self:remove(self._animProp)
		self._animProp = nil
	end
	if not looping and not callback then
		callback = Sprite_destroy
	end
	if not animName or not self._deck or not self._deck._animCurves then
		return nil
	end
	local curve = self._deck._animCurves[animName]
	if not curve then
		return nil
	end
	local anim = MOAIAnim.new()
	if self._deck.type == "tweendeck" then
		do
			local consts = self._deck._animConsts[animName]
			local curLink = 1
			self._animProp = node.new(MOAIProp2D.new())
			self._animProp:setDeck(self._deck)
			self:add(self._animProp)
			anim:reserveLinks(self._deck._numCurves[animName])
			for animType, entry in pairs(curve) do
				anim:setLink(curLink, entry, self._animProp, animType)
				if animType == MOAIColor.ATTR_A_COL then
					anim:setLink(curLink + 1, entry, self._animProp, MOAIColor.ATTR_R_COL)
					anim:setLink(curLink + 2, entry, self._animProp, MOAIColor.ATTR_G_COL)
					anim:setLink(curLink + 3, entry, self._animProp, MOAIColor.ATTR_B_COL)
					curLink = curLink + 3
				end
				curLink = curLink + 1
			end
			for animType, entry in pairs(consts) do
				if animType == "id" then
					self._animProp:setIndex(entry)
				elseif animType == "x" then
					do
						local x, y = self:getLoc()
						self._animProp:setLoc(entry, y)
					end
				elseif animType == "y" then
					do
						local x = self:getLoc()
						self._animProp:setLoc(x, entry)
					end
				elseif animType == "r" then
					self._animProp:setRot(entry)
				elseif animType == "xs" then
					do
						local x, y = self:getScl()
						self._animProp:setScl(entry, y)
					end
				elseif animType == "ys" then
					do
						local x = self:getScl()
						self._animProp:setScl(x, entry)
					end
				elseif animType == "a" then
					self._animProp:setColor(entry, entry, entry, entry)
				end
			end
		end
	else
		anim:reserveLinks(1)
		anim:setLink(1, curve, self, MOAIProp2D.ATTR_INDEX)
	end
	if looping == true then
		anim:setMode(MOAITimer.LOOP)
	else
		anim:setListener(MOAITimer.EVENT_STOP, function()
			callback(self)
		end)
	end
	self._anim = anim
	return anim:start()
end

local function Sprite_setDeck(self, deck)
	self._deck = deck
	self._olderSpriteSetDeck(self, deck)
end

function Sprite.new(data)
	assert(data, "need 'userdata' or url")
	
	local o = node.new(MOAIProp2D.new())
	o._olderSpriteSetDeck = o.setDeck
	o.setDeck = Sprite_setDeck
	o._olderSpriteDestroy = o.destroy
	o.destroy = Sprite_destroy
	o.getSize = Sprite_getSize
	o.parse = Sprite_parse
	o.setImage = Sprite_setImage
	o.playAnim = Sprite_playAnim
	o.stopAnim = Sprite_stopAnim
	
	if type(data) == "userdata" then
		local deck = MOAIGfxQuad2D.new()
		do
			local tex = data
			deck:setTexture(tex)
			local w, h = tex:getSize()
			deck:setRect(-w / 2, -h / 2, w / 2, h / 2)
			o:setDeck(deck)
		end
		o._sourceName = tostring(data)
	else
		Sprite_parse(o, data)
		o._sourceName = data
	end
	return o
end

return Sprite