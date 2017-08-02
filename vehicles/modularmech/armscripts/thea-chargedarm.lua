require "/vehicles/modularmech/armscripts/base.lua"

TheaChargedArm = MechArm:extend()

function TheaChargedArm:init()
  self.windupTimer = 0
  self.cooldownTimer = 0
  self.fireTimer = 0
  self.chargeStarted = false
end

function TheaChargedArm:update(dt)
  --Count down fire and cooldown timers every frame
  self.fireTimer = math.max(0, self.fireTimer - dt)
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  
  --Activate charge muzzle particles if in windup state
  if animator.animationState(self.armName) == "windup" then
	animator.setParticleEmitterActive(self.armName .. "ChargeMuzzle", true)
  else
	animator.setParticleEmitterActive(self.armName .. "ChargeMuzzle", false)
  end
  
  --Activate muzzle particles if in windup state
  if animator.animationState(self.armName) == ( "windup" or "active" ) then
	animator.setParticleEmitterActive(self.armName .. "Charge", true)
  else
	animator.setParticleEmitterActive(self.armName .. "Charge", false)
  end
  
  --While holding down fire, charge the weapon or fire when ready
  if self.isFiring and self.cooldownTimer == 0 then
	if not self.chargeStarted then
	  animator.setAnimationState(self.armName, "windup")
	  animator.playSound(self.armName .. "Charge", -1)
	  self.chargeStarted = true
	else
	  self.windupTimer = math.min(self.windupTimer + dt, self.windupTime)
	  
	  if self.windupTimer == self.windupTime then
		if self.repeatFire and self.fireTimer == 0 then
		  self:fire()

		  animator.burstParticleEmitter(self.armName .. "Fire")
		  animator.playSound(self.armName .. "Fire")
		  animator.stopAllSounds(self.armName .. "Charge")

		  self.fireTimer = self.fireTime
		else
		  self:fire()

		  animator.burstParticleEmitter(self.armName .. "Fire")
		  animator.playSound(self.armName .. "Fire")
		  animator.stopAllSounds(self.armName .. "Charge")

		  self.chargeStarted = false
		  self.windupTimer = 0
		  self.cooldownTimer = self.cooldownTime
		  animator.setAnimationState(self.armName, "winddown")
		end
	  end
	end
  --If we stopped firing
  elseif self.wasFiring and not self.isFiring and self.chargeStarted == true then
	self.fireTimer = 0
	
	--Stop charge sounds, and play discharge sound if the charge was unfinished
	animator.stopAllSounds(self.armName .. "Charge")
	if self.windupTimer ~= self.windupTime then
	  animator.playSound(self.armName .. "Discharge")
	end
	
	self.chargeStarted = false
	self.windupTimer = 0
	self.cooldownTimer = self.cooldownTime
	animator.setAnimationState(self.armName, "rotate")
  end
  
  --While we have a driver and we are active
  if self.driverId and (self.isFiring or self.cooldownTimer > 0) then
	animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)
	
	self.bobLocked = true
  else
	animator.setAnimationState(self.armName, "idle")

    self.bobLocked = false
  end
end
