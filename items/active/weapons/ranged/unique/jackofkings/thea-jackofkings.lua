require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

function init()
  self.cursor = config.getParameter("cursor")
  
  if (self.cursor) then
    activeItem.setCursor(self.cursor)
  else
    activeItem.setCursor("/cursors/reticle0.cursor")
  end
  
  animator.setGlobalTag("paletteSwaps", config.getParameter("paletteSwaps", ""))

  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, 0)
  self.weapon:addTransformationGroup("muzzle", self.weapon.muzzleOffset, 0)

  self.primaryAbility = getPrimaryAbility()
  self.weapon:addAbility(self.primaryAbility)

  self.altAbility = getAltAbility()
  if self.altAbility then
    self.weapon:addAbility(self.altAbility)
  end

  self.weapon:init()
end

function update(dt, fireMode, shiftHeld)
  self.weapon:update(dt, fireMode, shiftHeld)
  
  --Code for sharing data between abilities. Used to reload from alt ability
  if self.altAbility.reloaded then
	self.altAbility.reloaded = false
	self.primaryAbility.currentAmmo = self.primaryAbility.maxAmmo
	activeItem.setInstanceValue("ammoCount", self.primaryAbility.maxAmmo)
  end
  
  world.debugPoint(vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset)), "red")
end

function uninit()
  self.weapon:uninit()
end
