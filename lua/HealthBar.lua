local DLS = require("DynLineStrip")
local ui = require("ui")
local device = require("device")
local resource = require("resource")
local compat = require("moai.compat")
local HealthBar = {}
HealthBar.__index = HealthBar
function HealthBar.new(large, maxval, flash, TypeIn)
  local self
  assert(maxval ~= nil, "maxval needs to be specified")
  local size = "Small"
  if large then
    size = "Large"
  end
  self = ui.new(MOAIProp2D.new())
  if TypeIn == "asteroid" then
    self.fill = self:add(ui.FillBar.new("healthBar" .. size .. "FillBLUE.png"))
  else
    self.fill = self:add(ui.FillBar.new("healthBar" .. size .. "Fill.png"))
  end
  if flash then
    self.flash = ui.Image.new("hud.atlas.png#healthBarLargeFlash.png")
  end
  self.frame = self:add(ui.Image.new("hud.atlas.png#healthBar" .. size .. "Frame.png"))
  self.update = HealthBar.update
  self.destroy = HealthBar.destroy
  self.maxval = maxval
  self:update(maxval)
  return self
end
function HealthBar:clearEmblems()
  if self.warningEmblem ~= nil then
    self.warningEmblem:remove()
    self.warningEmblem = nil
  end
  if self.criticalEmblem ~= nil then
    self.criticalEmblem:remove()
    self.criticalEmblem = nil
  end
end
function HealthBar:onLayerChanged(layer)
  if layer == nil then
    self:clearEmblems()
  end
end
function HealthBar.toggleFlash(timer, val)
  if timer.object.flashOn then
    timer.object.flash:remove()
  else
    timer.object:add(timer.object.flash)
  end
  timer.object.flashOn = not timer.object.flashOn
end
function HealthBar:update(value, maxval, warning)
  if maxval ~= nil then
    self.maxval = maxval
  else
    maxval = self.maxval
  end
  local pct = value / maxval
  if self.flash then
    if warning and not self.action then
      self.action = levelAS:repeatcall(0.5, HealthBar.toggleFlash, self, self)
      self.action.object = self
    elseif not warning and self.action then
      self.action:stop()
      self.action = nil
      self.flash:remove()
    end
  end
  self:setVisible(value < maxval)
  self.frame:setVisible(value < maxval)
  self.fill:setFill(0, pct)
end
function HealthBar:destroy()
  self.fill:remove()
  self.fill = nil
  self.frame:remove()
  self.frame = nil
  if self.action then
    self.action:stop()
    self.action = nil
  end
  if self.flash then
    self.flash:remove()
  end
  self.flash = nil
  self:remove()
end
return HealthBar
