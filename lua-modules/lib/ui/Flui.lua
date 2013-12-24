require("ui")
require("resource")
local ui = ui
local resource = resource
local string = string
local ipairs = ipairs
local dofile = dofile
local print = print
local tostring = tostring
local error = error
local util = require("util")
module(...)
local function createButton(up, down)
  local _up = ui.Group.new()
  local e11 = _up:add(ui.Image.new(up))
  local _down = ui.Group.new()
  local e12 = _down:add(ui.Image.new(down))
  local _item = ui.Button.new(_up, _down)
  _item.up = _up
  _item.down = _down
  return _item
end
local function parse_colon_params(str)
  local t = {}
  local match = string.match
  for k, v in string.gmatch(str, "(%w+)%s*:%s*([^%s]+)") do
    t[k:lower()] = v
  end
  return t
end
local function v1(name, fileData)
  local textureName = name:gsub(".fla.lua", ".fla.png")
  local root = ui.Group.new()
  if fileData.width and fileData.height then
    root:setLayoutSize(fileData.width, fileData.height)
  end
  local buttons = {}
  local e = {}
  root.e = e
  for i, layer in ipairs(fileData.timeline.layers) do
    local p = parse_colon_params(layer.name)
    util.printfln(" %s -> %s", layer.name, util.tostr(p))
    local curr_e
    if p.img ~= nil then
      e[p.img] = root:add(ui.Image.new(textureName .. "#" .. layer.name))
      curr_e = e[p.img]
    elseif p.btn ~= nil then
      if layer.name:find("@press") == nil then
        if buttons[layer.name] == nil then
          buttons[layer.name] = {}
        end
        buttons[layer.name].up = textureName .. "#" .. layer.name
        if buttons[layer.name].up and buttons[layer.name].down then
          e[layer.name] = root:add(createButton(buttons[layer.name].up, buttons[layer.name].down))
          curr_e = e[layer.name]
        end
      else
        local layerName = layer.name:gsub("@press", "")
        if buttons[layerName] == nil then
          buttons[layerName] = {}
        end
        buttons[layerName].down = textureName .. "#" .. layer.name
        if buttons[layerName].up and buttons[layerName].down then
          e[layerName] = root:add(createButton(buttons[layerName].up, buttons[layerName].down))
          curr_e = e[layer.name]
        end
      end
    elseif p.anim ~= nil then
      local a = root:add(ui.Anim.new(textureName))
      if p.loop then
        a:loop(p.anim)
      end
      e[p.anim] = a
      curr_e = e[p.anim]
    end
    if p.anchor ~= nil and curr_e ~= nil then
      curr_e:setAnchor(p.anchor)
    end
  end
  buttons = nil
  return root
end
function new(name)
  local f = resource.path.resolvepath(name)
  if f == nil then
    error("File not found: " .. tostring(name))
  end
  local fileData = dofile(f)
  if fileData.version == "1" or fileData.version == nil then
    return v1(name, fileData)
  else
    error("Unsupported Flui file format: " .. tostring(fileData.version))
  end
end
