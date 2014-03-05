
local node = require "node"
local device = require "device"
local util = require "moai.util"

local layer = {}

function layer.clear(self)
	ui_removeAll(self)
	local mt = util.get_moai_mt(self)
	mt.clear(self)
end

function layer.setViewport(self, vp)
	self._viewport = vp
	local mt = util.get_moai_mt(self)
	mt.setViewport(self, vp)
end

function layer.getViewport(self)
	return self._viewport
end

function layer.new(viewport, scale)
	if viewport == nil or type(viewport) == "table" then
		local left = 0
		local top = 0
		local right = device.width
		local bottom = device.height
		if viewport ~= nil then
			if viewport.left ~= nil then
				left = viewport.left
			end
			if viewport.top ~= nil then
				top = viewport.top
			end
			if viewport.right ~= nil then
				right = viewport.right
			end
			if viewport.bottom ~= nil then
				bottom = viewport.bottom
			end
		end
		viewport = MOAIViewport.new()
		viewport:setSize(left, top, right, bottom)
		if scale then
			viewport:setScale(right - left, bottom - top)
		else
			viewport:setScale(0, 0)
		end
	elseif type(viewport) ~= "userdata" then
		error("Invalid viewport: " .. tostring(viewport))
	end
	local o = node.new(MOAILayer2D.new())
	o._layer = o
	o.clear = layer.clear
	o.setViewport = layer.setViewport
	o.getViewport = layer.getViewport
	o:setViewport(viewport)
	MOAISim.pushRenderPass(o)
	return o
end

return layer