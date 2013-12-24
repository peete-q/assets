local _M = {}
local device = require("device")
local ui = require("ui")
local url = require("url")
local util = require("util")
local Particle = require("Particle")
local breakstr = util.breakstr
function _M.createTilingBG(texname)
  local tex = resource.texture(texname)
  local w, h = tex:getSize()
  local tileDeck = MOAITileDeck2D.new()
  tileDeck:setTexture(tex)
  tileDeck:setSize(1, 1)
  local grid = MOAIGrid.new()
  grid:setSize(1, 1, w, h)
  grid:setRow(1, 1)
  grid:setRepeat(true)
  local prop = ui.new(MOAIProp2D.new())
  prop:setDeck(tileDeck)
  prop:setGrid(grid)
  prop:setLoc(-device.width / 2 - w / 2, 0)
  prop.height = h
  prop.width = w
  return prop
end
function _M.addImages(o, images, uiname)
  if images == nil then
    return
  end
  local pri = 0
  if o.getPriority then
    pri = (o:getPriority() or 0) + 1
  end
  if type(images) == "string" then
    do
      local i = o:add(ui.Image.new(images))
      if uiname ~= nil then
        i._uiname = uiname
        i:setPriority(pri)
      end
    end
  elseif type(images) == "table" then
    for i = 1, #images do
      local img = o:add(ui.Image.new(images[i]))
      if uiname ~= nil then
        img._uiname = uiname .. "_" .. i
        img:setPriority(pri)
      end
    end
  else
    error("Invalid images type: " .. tostring(images))
  end
end
function _M.addAssets(o, images, uiname, aset)
  if images == nil then
    return
  end
  local pri = 0
  local isAnim, q
  if o.getPriority then
    pri = (o:getPriority() or 0) + 1
  end
  if type(images) == "string" then
    do
      local texture, queryStr = breakstr(images, "?")
      local nPri = pri
      local rot, x, y, loop
      if queryStr ~= nil then
        q = url.parse_query(queryStr)
        if q.anim then
          isAnim = true
          if not o._gfxanims then
            o._gfxanims = {}
          end
        end
        if q.pri then
          nPri = nPri - 1 + tonumber(q.pri)
        end
        if q.rot ~= nil then
          rot = tonumber(q.rot)
        end
        if q.loc ~= nil then
          x, y = breakstr(q.loc, ",")
          x = tonumber(x)
          y = tonumber(y)
        end
        loop = q.looping
      end
      local i
      if string.find(images, ".pex") then
        if not o._gfxparticles then
          o._gfxparticles = {}
        end
        i = o:add(Particle.new(images, aset or levelAS))
        if rot then
          i:setRot(rot)
        end
        if x then
          i:setLoc(x, y)
        end
        o._gfxparticles[#o._gfxparticles + 1] = i
      elseif isAnim then
        i = o:add(ui.Anim.new(images))
        i.animName = q.anim
        i.looping = loop
        o._gfxanims[#o._gfxanims + 1] = i
      else
        i = o:add(ui.Image.new(images))
      end
      if not o._gfxobjects then
        o._gfxobjects = {}
      end
      o._gfxobjects[#o._gfxobjects + 1] = i
      if uiname ~= nil then
        i._uiname = uiname
        i:setPriority(nPri)
      end
    end
  elseif type(images) == "table" then
    for i = 1, #images do
      local texture, queryStr = breakstr(images[i], "?")
      local nPri = pri
      local rot, x, y, loop
      isAnim = false
      if queryStr ~= nil then
        q = url.parse_query(queryStr)
        if q.anim then
          isAnim = true
          if not o._gfxanims then
            o._gfxanims = {}
          end
        end
        if q.pri then
          nPri = nPri - 1 + tonumber(q.pri)
        end
        if q.rot ~= nil then
          rot = tonumber(q.rot)
        end
        if q.loc ~= nil then
          x, y = breakstr(q.loc, ",")
          x = tonumber(x)
          y = tonumber(y)
        end
        loop = q.looping
      end
      local img
      if string.find(texture, ".pex") then
        if not o._gfxparticles then
          o._gfxparticles = {}
        end
        img = o:add(Particle.new(images[i], aset or levelAS))
        if rot then
          img:setRot(rot)
        end
        if x then
          img:setLoc(x, y)
        end
        o._gfxparticles[#o._gfxparticles + 1] = img
      elseif isAnim then
        img = o:add(ui.Anim.new(images[i]))
        img.animName = q.anim
        img.looping = loop
        o._gfxanims[#o._gfxanims + 1] = img
      else
        img = o:add(ui.Image.new(images[i]))
      end
      if not o._gfxobjects then
        o._gfxobjects = {}
      end
      o._gfxobjects[#o._gfxobjects + 1] = img
      if uiname ~= nil then
        img._uiname = uiname .. "_" .. i
        img:setPriority(nPri)
      end
    end
  else
    error("Invalid images type: " .. tostring(images))
  end
end
function _M.playAssets(o)
  local list = o._gfxanims
  if list then
    for _, anim in ipairs(list) do
      if anim.looping then
        anim:loop(anim.animName)
        o:add(anim)
      else
        anim:play(anim.animName)
        o:add(anim)
      end
    end
  end
  list = o._gfxobjects
  if list then
    for _, obj in ipairs(list) do
      if obj.updateSystem then
        obj:updateSystem()
        obj:begin()
      else
        obj:forceUpdate()
      end
    end
  end
end
function _M.stopAssets(o, removeAssets)
  local list = o._gfxanims
  if list then
    for _, anim in pairs(list) do
      anim:stop()
      if removeAssets then
        anim:remove()
      end
    end
  end
  list = o._gfxparticles
  if list then
    for _, particle in pairs(list) do
      particle:cancel()
      if removeAssets then
        particle:remove()
      end
    end
  end
end
function _M.removeAssets(o)
  local list = o._gfxanims
  if list then
    for _, anim in pairs(list) do
      anim:stop()
      anim:remove()
    end
  end
  list = o._gfxparticles
  if list then
    for _, particle in pairs(list) do
      particle:destroy()
    end
  end
  o._gfxanims = nil
  o._gfxparticles = nil
  o:remove()
end
return _M
