require "/scripts/vec2.lua"

TheaSilencer = WeaponAbility:new()

function TheaSilencer:init()
  self:adaptAbility()
end

function TheaSilencer:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  --Turn off the muzzle flash animation immediately after it activates
  if animator.animationState("firing") == "fire" then
	animator.setAnimationState("firing", "off")
  end
end

function TheaSilencer:adaptAbility()
  local ability = self.weapon.abilities[self.adaptedAbilityIndex]
  local newAbility = {}
  
  --Adjust various animation parameters and allow custom projectile parameters to be set
  animator.setSoundPool("fire", self.fireSound)
  animator.setLightColor("muzzleFlash", {0, 0, 0})
  newAbility = self.specialAbility
  
  util.mergeTable(ability, newAbility)
end

function TheaSilencer:uninit()
end
