TheaFlashlight = WeaponAbility:new()

function TheaFlashlight:init()
  self:reset()
end

function TheaFlashlight:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.fireMode == "alt" and self.lastFireMode ~= "alt" then
    self.active = not self.active
    animator.setLightActive("flashlight", self.active)
    animator.setLightActive("flashlightSpread", self.active)
    animator.playSound("flashlight")
	if self.active then
	  animator.setAnimationState("light", "on")
	else
	  animator.setAnimationState("light", "off")
	end
  end
  self.lastFireMode = fireMode
end

function TheaFlashlight:reset()
  animator.setLightActive("flashlight", false)
  animator.setLightActive("flashlightSpread", false)
  animator.setAnimationState("light", "off")
  self.active = false
end

function TheaFlashlight:uninit()
  self:reset()
end
