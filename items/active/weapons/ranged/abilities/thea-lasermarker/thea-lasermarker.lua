TheaLaserMarker = WeaponAbility:new()

function TheaLaserMarker:init()
  self:reset()
end

function TheaLaserMarker:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  --Enable or disable the laser using the fire button
  if self.fireMode == "alt" and self.lastFireMode ~= "alt" and not status.resourceLocked("energy") then
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
	  animator.stopAllSounds("targetingLoop")
	  self.loopSoundPlaying = false
	end
  end
  self.lastFireMode = fireMode
  
  --If active, look for targets to mark and drain energy
  if self.active then
	--Only continue if we have energy left
	if status.overConsumeResource("energy", self.energyUsage*dt) then
	  if self.loopSoundPlaying == false then
		animator.playSound("targetingLoop", -1)
		self.loopSoundPlaying = true
	  end
	  local beamStart = self:startPosition()
	  local beamEnd = vec2.add(beamStart, vec2.mul(vec2.norm(self:aimVector(0)), self.maxSearchDistance))
	
	  local collidePoint = world.lineCollision(beamStart, beamEnd)
	  if collidePoint then
		beamEnd = collidePoint
	  end
	
	  local targets = world.entityLineQuery(beamStart, beamEnd, {
		withoutEntityId = activeItem.ownerEntityId(),
		includedTypes = {"creature"},
		order = "nearest"
	  })
	  for _, target in ipairs(targets) do
		--Make sure we can damage the targeted entity
		if world.entityCanDamage(activeItem.ownerEntityId(), target) then
		  world.spawnProjectile("targethighlight", world.entityPosition(target), activeItem.ownerEntityId(), {0,0}, false, nil)
		end
	  end
	end
  end
  
  --If out of energy, disable the laser
  if status.resourceLocked("energy") then
	if self.active == true then
	  animator.playSound("toggleLight")
	end
	self.active = false
	animator.setLightActive("flashlight", false)
    animator.setLightActive("flashlightSpread", false)
	activeItem.setScriptedAnimationParameter("laserColour", self.laserColourInactive)
	animator.setAnimationState("laser", "off")
	self.loopSoundPlaying = false
	animator.stopAllSounds("targetingLoop")
  end
end

function TheaLaserMarker:startPosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.laserOffset))
end

function TheaLaserMarker:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaLaserMarker:reset()
  --Disable the lights
  animator.setLightActive("flashlight", false)
  animator.setLightActive("flashlightSpread", false)
  --Disable the laser
  activeItem.setScriptedAnimationParameter("laserColour", self.laserColourInactive)
  --Hide the laser sprite overlay
  animator.setAnimationState("laser", "off")
  self.active = false
  self.loopSoundPlaying = false
  animator.stopAllSounds("targetingLoop")
end

function TheaLaserMarker:uninit()
  self:reset()
end
