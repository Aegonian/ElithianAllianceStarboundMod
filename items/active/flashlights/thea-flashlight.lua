require "/scripts/vec2.lua"

function init()
  self.aimOffset = config.getParameter("aimOffset")
  self.active = true
  self.lastFireMode = "none"
  
  animator.setAnimationState("flashlight", "active")
end

function update(dt, fireMode, shiftHeld)
  updateAim()

  --If pressing the mouse button, switch the flashlight state
  if fireMode == "primary" and self.lastFireMode ~= "primary" then
	animator.playSound("switch")
	
	if self.active then
	  animator.setAnimationState("flashlight", "inactive")
	  self.active = false
	else
	  animator.setAnimationState("flashlight", "active")
	  self.active = true
	end
  end
  
  self.lastFireMode = fireMode
end

function updateAim()
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(self.aimOffset, activeItem.ownerAimPosition())
  activeItem.setArmAngle(self.aimAngle)
  activeItem.setFacingDirection(self.aimDirection)
end
