local ui = require("ui")
local resource = require("resource")
local compat = require("moai.compat")
local util = require("util")
local url = require("url")
local breakstr = util.breakstr
local Projectile = {}
Projectile.__index = Projectile
function Projectile.new(texture, aset)
  local self = ui.new(MOAIProp2D.new())
  if texture then
    if string.find(texture, ".pex") then
      do
        local particle = self:add(ui.ParticleSystem.new(texture))
        if aset then
          aset:wrap(particle)
        end
        particle:startSystem()
        self.particle = particle
      end
    elseif string.find(texture, "anim=") then
      do
        local _, queryStr = breakstr(texture, "?")
        local anim
        if queryStr ~= nil then
          local q = url.parse_query(queryStr)
          anim = q.anim
        end
        local p = self:add(ui.Anim.new(texture))
        local action = p:loop(anim)
        if aset then
          aset:wrap(action)
        end
        self.anim = p
      end
    else
      self.texture = self:add(ui.Image.new(texture))
    end
  end
  self.update = Projectile.update
  self.destroy = Projectile.destroy
  return self
end
function Projectile:update()
end
function Projectile:destroy()
  if self.texture then
    self.texture:remove()
    self.texture = nil
  end
  if self.anim then
    self.anim:stop()
    self.anim:remove()
    self.anim = nil
  end
  if self.particle then
    self.particle:stopSystem()
    self.particle:remove()
    self.particle = nil
  end
  self:remove()
end
return Projectile
