require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

function init()
  animator.setGlobalTag("paletteSwaps", config.getParameter("paletteSwaps", ""))
  animator.setGlobalTag("directives", "")
  animator.setGlobalTag("bladeDirectives", "")

  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, util.toRadians(config.getParameter("baseWeaponRotation", 0)))
  self.weapon:addTransformationGroup("swoosh", {0,0}, math.pi/2)

  self.primaryAbility = getPrimaryAbility()
  self.weapon:addAbility(self.primaryAbility)

  self.altAbility = getAltAbility()
  self.weapon:addAbility(self.altAbility)

  self.weapon:init()

  self.primaryAbility.active = false
  self.altAbility.active = false
end

function update(dt, fireMode, shiftHeld)
  self.weapon:update(dt, fireMode, shiftHeld)

  --Code for sharing active status boolean across abilities. Bool is changed by alt ability
  if self.altAbility.active == true then
	self.primaryAbility.active = true
  elseif self.altAbility.active == false then
	self.primaryAbility.active = false
  end
  
  if not status.resourcePositive("energy") then
	self.primaryAbility.active = false
	self.altAbility.active = false
  end
end

function uninit()
  self.weapon:uninit()
end
