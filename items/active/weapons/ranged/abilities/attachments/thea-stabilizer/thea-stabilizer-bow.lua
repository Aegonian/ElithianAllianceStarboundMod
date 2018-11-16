require "/scripts/vec2.lua"

TheaBowStabilizer = WeaponAbility:new()

function TheaBowStabilizer:init()
  self:adaptAbility()
end

function TheaBowStabilizer:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
end

function TheaBowStabilizer:adaptAbility()
  local ability = self.weapon.abilities[self.adaptedAbilityIndex]
  local newAbility = {}
  
  --Adjust various animation parameters and allow custom projectile parameters to be set
  newAbility = self.specialAbility
  newAbility.drawTime = ability.drawTime - self.drawTimeReduction
  
  util.mergeTable(ability, newAbility)
end

function TheaBowStabilizer:uninit()
end
