
local delegate = {}

delegate.__index = delegate

function delegate.new()
	local self = {
		_handles = {},
	}
	setmetatable(self._handles, {__mode = "kv"})
	setmetatable(self, delegate)
	return self
end

local function _cancel(self)
	self._delegate._handles[self] = nil
end

function delegate:register(cb)
	local handle = {
		_delegate = self,
		cancel = _cancel,
		cb = cb,
	}
	self._handles[handle] = handle
	return handle
end

function delegate:invoke(...)
	local tb = table.copy(self._handles)
	for k, v in pairs(tb) do
		v.cb(...)
	end
end