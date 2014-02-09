
local Node = {}

local function Node_setLayer(self, layer)
	if self._layer == layer then
		return
	end
	if layer ~= nil then
		layer:insertProp(self)
		self._layer = layer
		if self._children ~= nil then
			for k, v in pairs(self._children) do
				Node_setLayer(v, layer)
			end
		end
	elseif self._layer ~= nil then
		self._layer:removeProp(self)
		self._layer = nil
		if self._children ~= nil then
			for k, v in pairs(self._children) do
				Node_setLayer(v, nil)
			end
		end
	end
end

local function Node_unparentChild(child)
	Node_setLayer(child, nil)
	child._parent = nil
	child:setParent(nil)
end

local function Node_add(self, child)
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
	Node_setLayer(child, self._layer)
	return child
end

local function Node_removeAll(self, fullClear)
	if self._children ~= nil then
		for k, v in pairs(self._children) do
			Node_unparentChild(v)
			if fullClear then
				Node_removeAll(v)
			end
		end
		self._children = nil
	end
end

local function Node_remove(self, child)
	if child == nil then
		if self._parent ~= nil then
			return Node_remove(self._parent, self)
		end
		return false
	end
	if child._parent ~= self then
		return false
	end
	if self._children ~= nil then
		if self._children[child] ~= nil then
			Node_unparentChild(child)
			self._children[child] = nil
		end
	end
	return false
end

local function Node_destroy(self)
	self:remove()
	if self._children ~= nil then
		for k, v in pairs(self._children) do
			v:destroy()
		end
		self._children = nil
	end
	if self._oldreNodeDestroy then
		self._olderNodeDestroy(self)
	end
end

function Node.new(o)
	assert(type(o) == "userdata" and getmetatable(o) ~= nil, "Improper use of Node.new")
	o._olderNodeDestroy = o.destroy
	o.destroy = Node_destroy
	o.add = Node_add
	o.setLayer = Node_setLayer
	o.remove = Node_remove
	o.removeAll = Node_removeAll
	return o
end

return Node