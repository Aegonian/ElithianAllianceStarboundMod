require "/scripts/vec2.lua"

TheaStatOverride = WeaponAbility:new()

function TheaStatOverride:init()
  self:adaptAbility()
end

function TheaStatOverride:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
end

function TheaStatOverride:adaptAbility()
  local ability = self.weapon.abilities[self.adaptedAbilityIndex]
  local newAbility = {}
  
  --Adjust various animation parameters and allow custom projectile parameters to be set
  newAbility = self.specialAbility
  
  util.mergeTable(ability, newAbility)
end

function TheaStatOverride:uninit()
end
