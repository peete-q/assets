
local util = require "util"
local Prim = require "Prim"
local breakstr = util.breakstr

local Sprite = {}

local function Sprite_getSize(self)
	if not self or not self._deck or not self._deck.getSize then
		return nil
	end
	return self._deck:getSize(self.deckLayer)
end

local function Sprite_setUrl(self, url)
	local deckName, queryStr = breakstr(url, "?")
	deck = resource.deck(deckName)
	self:setDeck(deck)
	if queryStr then
		local q = url.parse_query(queryStr)
		if q.image then
			self:setIndex(deck:indexOf(q.image))
		elseif q.index then
			self:setIndex(tonumber(q.index))
		elseif q.anim then
			self:playAnim(q.anim)
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
	end
end

local function Sprite_setImage(self, name)
	local index = self._deck:indexOf(name)
	self:setIndex(index)
end

local function Sprite_stopAnim(self)
	if self._anim then
		self._anim:stop()
		self._anim = nil
	end
	if self._animProp then
		self.remove(self._animProp)
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
		self.remove(self._animProp)
		self._animProp = nil
	end
	if not looping and callback == nil then
		callback = Sprite_stopAnim
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
			self._animProp = ui_new(MOAIProp2D.new())
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
	if looping then
		anim:setMode(MOAITimer.LOOP)
	else
		anim:setListener(MOAITimer.EVENT_TIMER_LOOP, function()
			callback(self)
		end)
	end
	self._anim = anim
	return anim:start()
end

function Sprite.new(source, layer)
	local o = Prim.new(MOAIProp2D.new())
	local deck
	if type(source) == "userdata" then
		deck = MOAIGfxQuad2D.new()
		do
			local tex = source
			deck:setTexture(tex)
			local w, h = tex:getSize()
			deck:setRect(-w / 2, -h / 2, w / 2, h / 2)
			o:setDeck(deck)
		end
		o._sourceName = tostring(source)
	else
		Sprite_setUrl(o, source)
		o._sourceName = source
	end
	if layer then
		o:setLayer(layer)
	end
	o._deck = deck
	o.getSize = Sprite_getSize
	o.setUrl = Sprite_setUrl
	o.setImage = Sprite_setImage
	o.playAnim = Sprite_playAnim
	o.stopAnim = Sprite_stopAnim
	return o
end

return Sprite