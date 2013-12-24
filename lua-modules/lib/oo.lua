local oo = {}
local getmetatable = getmetatable
local setmetatable = setmetatable
local pairs = pairs
local rawget = rawget
local oo_classof = getmetatable
local function oo_rawnew(class, object)
  return setmetatable(object or {}, class)
end
local function oo_new(class, obj, ...)
  assert(class ~= nil, "invalid class")
  local new = class.__new
  if new then
    obj = new(class, obj, ...)
    assert(oo_classof(obj) == class, "Custom __new constructor did not return a valid class")
  else
    obj = oo_rawnew(class, obj)
  end
  local init = class.__init
  if init then
    init(obj, ...)
  end
  return obj
end
local function oo_initclass(class)
  if class == nil then
    class = {}
  end
  if class.__index == nil then
    class.__index = class
  end
  if class.new == nil then
    if class.__new then
      function class.new(...)
        return oo_new(class, ...)
      end
    else
      function class.new(...)
        return oo_new(class, nil, ...)
      end
    end
  end
  return class
end
local MetaClass = {}
MetaClass.__index = MetaClass
local DerivedClassCache
local function oo_class(class, super)
  if super then
    return setmetatable(oo_initclass(class), DerivedClassCache[super])
  else
    return setmetatable(oo_initclass(class), MetaClass)
  end
end
DerivedClassCache = setmetatable({}, {
  __mode = "k",
  __index = function(self, super)
    if super ~= nil then
      local c = {__index = super}
      rawset(self, super, c)
      return c
    end
  end
})
local function oo_isclass(class)
  local metaclass = oo_classof(class)
  if metaclass then
    return metaclass == rawget(DerivedClassCache, metaclass.__index) or metaclass == MetaClass
  end
  return false
end
local function oo_superclass(class)
  local metaclass = oo_classof(class)
  if metaclass then
    local c = metaclass.__index
    if c ~= metaclass then
      return c
    end
  end
  return nil
end
local function oo_subclassof(class, super)
  while class do
    if class == super then
      return true
    end
    class = oo_superclass(class)
  end
  return false
end
local function oo_instanceof(object, class)
  return oo_subclassof(oo_classof(object), class)
end
oo.rawnew = oo_rawnew
oo.initclass = oo_initclass
oo.classof = oo_classof
oo.members = pairs
oo.new = oo_new
oo.class = oo_class
oo.isclass = oo_isclass
oo.superclass = oo_superclass
oo.subclassof = oo_subclassof
oo.instanceof = oo_instanceof
return oo
