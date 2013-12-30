
local Prim = {}

local function Prim_setLayer(self, layer)
	if self._layer == layer then
		return
	end
	if layer ~= nil then
		layer:insertProp(self)
		self._layer = layer
		if self._children ~= nil then
			for k, v in pairs(self._children) do
				Prim_setLayer(v, layer)
			end
		end
	elseif self._layer ~= nil then
		self._layer:removeProp(self)
		self._layer = nil
		if self._children ~= nil then
			for k, v in pairs(self._children) do
				Prim_setLayer(v, nil)
			end
		end
	end
end

local function Prim_unparentChild(child)
	Prim_setLayer(child, nil)
	child._parent = nil
	child:setParent(nil)
end

local function Prim_add(self, child)
	assert(child ~= nil, "Child must not be null")
	assert(child._layer == nil or child._layer ~= child, "Nested viewports not supported")
	if child._parent ~= nil then
		if child._parent == self then
			return
		end
		child._parent:remove(child)
	end
	if self._children == nil then
		self._children = {}
	end
	self._children[child] = child
	child:setParent(self)
	child._parent = self
	Prim_setLayer(child, self._layer)
	return child
end

local function Prim_removeAll(self, fullClear)
	if self._children ~= nil then
		for k, v in pairs(self._children) do
			Prim_unparentChild(v)
			if fullClear then
				Prim_removeAll(v)
			end
		end
		self._children = nil
	end
end

local function Prim_remove(self, child)
	if child == nil then
		if self._parent ~= nil then
			return Prim_remove(self._parent, self)
		end
		return false
	end
	if child._parent ~= self then
		return false
	end
	if self._children ~= nil then
		if self._children[child] ~= nil then
			Prim_unparentChild(child)
			self._children[child] = nil
		end
	end
	return false
end

function Prim.new(o)
	assert(type(o) == "userdata" and getmetatable(o) ~= nil, "Improper use of Prim_new")
	o.add = Prim_add
	o.setLayer = Prim_setLayer
	o.remove = Prim_remove
	o.removeAll = Prim_removeAll
	return o
end

return Prim