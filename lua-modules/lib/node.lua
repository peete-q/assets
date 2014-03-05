
local node = {}

local function node_setLayer(self, layer)
	if self._layer == layer then
		return
	end
	if layer ~= nil then
		layer:insertProp(self)
		self._layer = layer
		if self._children ~= nil then
			for k, v in pairs(self._children) do
				node_setLayer(v, layer)
			end
		end
	elseif self._layer ~= nil then
		self._layer:removeProp(self)
		self._layer = nil
		if self._children ~= nil then
			for k, v in pairs(self._children) do
				node_setLayer(v, nil)
			end
		end
	end
end

local function node_unparentChild(child)
	node_setLayer(child, nil)
	child._parent = nil
	child:setParent(nil)
	child:setScissorRect(nil)
end

function node.setScissorRect(self, rect)
	self._scissorRect = rect
	local mt = util.get_moai_mt(self)
	mt.setScissorRect(self, rect)
end

function node.getScissorRect(self)
	return self._scissorRect
end

function node.add(self, child)
	assert(child ~= nil, "Child must not be null")
	assert(child._layer == nil or child._layer ~= child, "Nested viewports not supported")
	if child._parent ~= nil then
		if child._parent == self then
			return
		end
		child._parent:remove(child)
	end
	local priority = self:getPriority()
	if priority and not child:getPriority() then
		child:setPriority(priority + 1)
	end
	if self._scissorRect then
		child:setScissorRect(self._scissorRect)
	end
	if self._children == nil then
		self._children = {}
	end
	self._children[child] = child
	child:setParent(self)
	child._parent = self
	node_setLayer(child, self._layer)
	return child
end

function node.removeAll(self, fullClear)
	if self._children ~= nil then
		for k, v in pairs(self._children) do
			node_unparentChild(v)
			if fullClear then
				node.removeAll(v)
			end
		end
		self._children = nil
	end
end

function node.remove(self, child)
	if child == nil then
		if self._parent ~= nil then
			return node.remove(self._parent, self)
		end
		return false
	end
	if child._parent ~= self then
		return false
	end
	if self._children ~= nil then
		if self._children[child] ~= nil then
			node_unparentChild(child)
			self._children[child] = nil
		end
	end
	return false
end

function node.destroy(self)
	self:remove()
	if self._children ~= nil then
		for k, v in pairs(self._children) do
			v:destroy()
		end
		self._children = nil
	end
	if self._olderNodeDestroy then
		self._olderNodeDestroy(self)
	end
end

function node.new(o)
	o = o or MOAIProp2D.new()
	o._olderNodeDestroy = o.destroy
	o.destroy = node.destroy
	o.add = node.add
	o.remove = node.remove
	o.removeAll = node.removeAll
	o.setScissorRect = node.setScissorRect
	o.getScissorRect = node.getScissorRect
	return o
end

return node