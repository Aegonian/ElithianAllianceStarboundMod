require "/scripts/vec2.lua"

TheaLaserSight = WeaponAbility:new()

function TheaLaserSight:init()
  self:reset()
end

function TheaLaserSight:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.fireMode == "alt" and self.lastFireMode ~= "alt" then
    self.active = not self.active
	--Activate lights and play sound
    animator.setLightActive("flashlight", self.active)
    animator.setLightActive("flashlightSpread", self.active)
    animator.playSound("toggleLight")
	if self.active == true then
	  --Enable the laser
	  activeItem.setScriptedAnimationParameter("laserColour", self.laserColourActive)
	  --Show the laser sprite overlay
	  animator.setAnimationState("laser", "on")
	else
	  --Disable the laser
	  activeItem.setScriptedAnimationParameter("laserColour", self.laserColourInactive)
	  --Hide the laser sprite overlay
	  animator.setAnimationState("laser", "off")
	end
  end
  self.lastFireMode = fireMode
end

function TheaLaserSight:reset()
  --Disable the lights
  --animator.setLightActive("flashlight", false)
  --animator.setLightActive("flashlightSpread", false)
  --Disable the laser
  --activeItem.setScriptedAnimationParameter("laserColour", self.laserColourInactive)
  --Hide the laser sprite overlay
  if animator.animationState("laser") == "on" then
	self.active = true
  else
	self.active = false
  end
  
  --Optionally reposition the laser. Useful when the laser is configured through a modular alt ability
  if self.positionRelativeToMuzzle then
	activeItem.setScriptedAnimationParameter("positionRelativeToMuzzle", true)
	activeItem.setScriptedAnimationParameter("offset", vec2.add(self.laserOffset, self.weapon.muzzleOffset))
	--activeItem.setScriptedAnimationParameter("offset", {5, 1})
  end
end

function TheaLaserSight:uninit()
  self:reset()
end
