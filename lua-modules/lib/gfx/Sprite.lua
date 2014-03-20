
local url = require "url"
local node = require "node"

local Sprite = {}

local function Sprite_getSize(self)
	if not self._deck or not self._deck.getSize then
		return nil
	end
	return self._deck:getSize(self.deckLayer)
end

local function Sprite_loadImage(self, urlStr)
	self:stopAnim()
	
	local imageName, queryStr = string.split(urlStr, "?")
	local deckName, layerName = string.split(imageName, "#")
	local deck = resource.deck(deckName)
	self:setDeck(deck)
	if layerName then
		self:setIndex(deck:indexOf(layerName))
		self.deckLayer = layerName
		self.deckIndex = deck:indexOf(layerName)
	end
	if queryStr then
		local q = url.parse_query(queryStr)
		if q.scl then
			local x, y = string.split(q.scl, ",")
			self:setScl(tonumber(x), tonumber(x or y))
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
			local x, y = string.split(q.loc, ",")
			self:setLoc(tonumber(x), tonumber(y))
		end
		if q.alpha then
			self:setColor(1, 1, 1, tonumber(q.alpha))
		end
	end
end

local function Sprite_loadAnim(self, urlStr)
	self:stopAnim()
	
	local animName, queryStr = string.split(urlStr, "?")
	local deckName, layerName = string.split(animName, "#")
	local deck = resource.deck(deckName)
	self:setDeck(deck)
	if layerName then
		self:playAnim(layerName)
	end
	if queryStr then
		local q = url.parse_query(queryStr)
		local dur
		if q.dur then
			dur = tonumber(q.dur)
		end
		if q.scl then
			local x, y = string.split(q.scl, ",")
			self:setScl(tonumber(x), tonumber(x or y))
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
			local x, y = string.split(q.loc, ",")
			self:setLoc(tonumber(x), tonumber(y))
		end
		if q.alpha then
			self:setColor(1, 1, 1, tonumber(q.alpha))
		end
	end
end

local function Sprite_setImage(self, name)
	self:stopAnim()
	
	local index = self._deck:indexOf(name)
	self:setIndex(index)
end

local function Sprite_destroy(self)
	self:stopAnim()
	
	if self.onDestroy then
		self:onDestroy()
	end
	
	if self._preSpriteDestroy then
		self._preSpriteDestroy(self)
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
	self:stopAnim()
	
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
	self._preSpriteSetDeck(self, deck)
end

local function Sprite_throttle(self, num)
	self._anim:throttle(num)
end

local function _sequencedeck_getSize(self)
	return unpack(self._size)
end

local function Sprite_loadSequence(self, textureName, animName, numFrames, interval)
	self:stopAnim()
	
	local tex = resource.texture(textureName)
	local w, h = tex:getSize()
	local deck = MOAIGfxQuadDeck2D.new()
	deck:reserve(numFrames)
	deck._map = {}
	deck._sizes = {}
	local hw = w / numFrames / 2
	local curve = MOAIAnimCurve.new()
	curve:reserveKeys (numFrames)
	for i = 1, numFrames do
		deck:setUVRect(i, (i - 1) / numFrames, 0, i / numFrames, 1)
		deck:setRect(i, -hw, 0, hw, h)
		curve:setKey(i, (i - 1) * interval, i, MOAIEaseType.FLAT)
	end
	if not deck._animCurves then
		deck._animCurves = {}
	end
	deck._animCurves[animName] = curve
	deck:setTexture(tex)
	deck.type = "sequencedeck"
	deck.numFrames = numFrames
	deck.getSize = _sequencedeck_getSize
	deck._size = {hw * 2, h}
	self:setDeck(deck)
	self._sourceName = tostring(deck)
end

function Sprite.new(data)
	local o = node.new(MOAIProp2D.new())
	o._preSpriteSetDeck = o.setDeck
	o.setDeck = Sprite_setDeck
	o._preSpriteDestroy = o.destroy
	o.destroy = Sprite_destroy
	o.getSize = Sprite_getSize
	o.setImage = Sprite_setImage
	o.playAnim = Sprite_playAnim
	o.stopAnim = Sprite_stopAnim
	o.loadImage = Sprite_loadImage
	o.loadAnim = Sprite_loadAnim
	o.loadSequence = Sprite_loadSequence
	o.throttle = Sprite_throttle
	
	local tname = type(data)
	if tname == "userdata" then
		local deck = MOAIGfxQuad2D.new()
		do
			local tex = data
			deck:setTexture(tex)
			local w, h = tex:getSize()
			deck:setRect(-w / 2, -h / 2, w / 2, h / 2)
			o:setDeck(deck)
		end
		o._sourceName = tostring(data)
	elseif tname == "string" then
		Sprite_loadImage(o, data)
		o._sourceName = data
	end
	return o
end

return Sprite