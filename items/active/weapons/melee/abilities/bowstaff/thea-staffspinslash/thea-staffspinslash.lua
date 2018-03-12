require "/scripts/util.lua"
require "/scripts/poly.lua"
require "/scripts/status.lua"
require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/items/active/weapons/weapon.lua"

TheaStaffSpinSlash = WeaponAbility:new()

function TheaStaffSpinSlash:init()
  self.cooldownTimer = self.cooldownTime
  self.chargeTimer = 0
  self.queryDamageSince = 0
end

function TheaStaffSpinSlash:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility
     and self.cooldownTimer == 0
     and self.fireMode == "alt"
     and mcontroller.onGround()
     and not status.statPositive("activeMovementAbilities")
     and not status.resourceLocked("energy") then

    self:setState(self.windup)
  elseif not self.weapon.currentAbility
     and self.cooldownTimer == 0
     and self.fireMode == "alt"
     and not mcontroller.onGround()
     and not status.statPositive("activeMovementAbilities")
     and not status.resourceLocked("energy") then

    self:setState(self.flip, 0, true)
  end
  
  world.debugText(self.queryDamageSince, mcontroller.position(), "red")
end

function TheaStaffSpinSlash:windup()
  self.weapon:setStance(self.stances.windup)

  status.setPersistentEffects("weaponMovementAbility", {{stat = "activeMovementAbilities", amount = 1}})
  local waitTime = self.stances.windup.duration
  local allowCharge = true
  
  while (self.fireMode == "alt" or waitTime > 0) and allowCharge do
	self.chargeTimer = math.min(self.chargeTime, self.chargeTimer + self.dt)
	waitTime = math.max(0, waitTime - self.dt)
	
	mcontroller.controlCrouch()
	mcontroller.controlModifiers({
	  runningSuppressed = true
	})
	
	--Controlling arm and weapon rotation and offset
	local chargeRatio = math.sin(self.chargeTimer / self.chargeTime * 1.57)
    self.weapon.relativeArmRotation = util.toRadians(util.lerp(chargeRatio, {self.stances.windup.armRotation, self.stances.windup.endArmRotation}))
    self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(chargeRatio, {self.stances.windup.weaponRotation, self.stances.windup.endWeaponRotation}))
	
	if self.stances.windup.endWeaponOffset then
	  local from = self.stances.windup.weaponOffset or {0,0}
	  local to = self.stances.windup.endWeaponOffset or {0,0}
	  self.weapon.weaponOffset = {interp.linear(chargeRatio, from[1], to[1]), interp.linear(chargeRatio, from[2], to[2])}
	end
	
	if self.chargeTimer == self.chargeTime and self.releaseOnReady then
	  allowCharge = false
	end
	coroutine.yield()
  end
  
  if mcontroller.onGround() then
	self:setState(self.flip, self.chargeTimer / self.chargeTime, false)
  else
	self.cooldownTimer = 0.25
  end
end

function TheaStaffSpinSlash:flip(chargePercentage, fromJump)
  self.weapon:setStance(self.stances.flip)
  self.weapon:updateAim()

  --Animation
  animator.setAnimationState("swoosh", "flip")
  animator.playSound(self.fireSound or "spinSlash")
  animator.setParticleEmitterActive("flip", true)

  --Setup
  self.flipTime = self.maxRotations * self.rotationTime
  self.flipTimer = 0
  self.jumpTimer = self.jumpDuration
  local allowFlip = true
  local allowJump = true
  
  --Energy drain
  status.overConsumeResource("energy", self.energyUsage)

  --While spinning
  while self.flipTimer < self.flipTime and allowFlip do
    self.flipTimer = self.flipTimer + self.dt

    mcontroller.controlParameters(self.flipMovementParameters)

	--Set jump velocity
    if self.jumpTimer > 0 and not fromJump and allowJump then
      self.jumpTimer = self.jumpTimer - self.dt
	  
	  local xVelocity = self.jumpVelocity[1] + (chargePercentage * (self.chargedJumpVelocity[1] - self.jumpVelocity[1]))
	  local yVelocity = self.jumpVelocity[2] + (chargePercentage * (self.chargedJumpVelocity[2] - self.jumpVelocity[2]))
      mcontroller.setVelocity({xVelocity * self.weapon.aimDirection, yVelocity})
    elseif fromJump and allowJump then
	  mcontroller.setYVelocity(self.midAirJumpVelocity)
	  allowJump = false
	end

	--If we've completed at least one spin cycle and hit an enemy, launch us into the air
	local damageNotifications, nextStep = status.inflictedDamageSince(self.queryDamageSince)
	self.queryDamageSince = nextStep
	for _, notification in ipairs(damageNotifications) do
	  --sb.logInfo(sb.printJson(notification, 1))
	  --sb.logInfo(sb.printJson(world.entityType(notification.targetEntityId)))
	  if notification.healthLost > 0 and notification.sourceEntityId ~= notification.targetEntityId and world.entityType(notification.targetEntityId) ~= "object" and self.launchAfterHit then
		if math.floor(self.flipTimer / self.rotationTime) >= 1 then
		  if status.overConsumeResource("energy", self.launchEnergyUsage) then
			self:setState(self.launch)
		  end
		else
		  mcontroller.setVelocity({0,0})
		end
		break
	  end
	end
	
	--Set damage area
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)

	--Set player rotation
    mcontroller.setRotation(-math.pi * 2 * self.weapon.aimDirection * (self.flipTimer / self.rotationTime))
	
	--Taking the player out of the flip when hitting the ground
	if mcontroller.onGround() and self.flipTimer > self.minRotations * self.rotationTime then
	  allowFlip = false
	end
	
	--Taking the player out of the flip when using primary fireMode
	if self.fireMode == "primary" then
	  allowFlip = false
	end

	--world.debugText(math.floor(self.flipTimer / self.rotationTime), mcontroller.position(), "red")
	
    coroutine.yield()
  end

  status.clearPersistentEffects("weaponMovementAbility")

  animator.setAnimationState("swoosh", "idle")
  mcontroller.setRotation(0)
  animator.setParticleEmitterActive("flip", false)
  self.cooldownTimer = self.cooldownTime
  self.chargeTimer = 0
end

function TheaStaffSpinSlash:launch()
  self.weapon:setStance(self.stances.launch)

  --Reset flip state
  status.clearPersistentEffects("weaponMovementAbility")
  
  animator.setAnimationState("swoosh", "idle")
  mcontroller.setRotation(0)
  animator.setParticleEmitterActive("flip", false)
  self.cooldownTimer = self.cooldownTime
  self.chargeTimer = 0
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  animator.playSound("launch")
  mcontroller.setVelocity({0,0})

  util.wait(self.stances.launch.duration, function()
    mcontroller.setYVelocity(self.launchVelocity)
	mcontroller.setRotation(0)
  end)
end

function TheaStaffSpinSlash:uninit()
  status.clearPersistentEffects("weaponMovementAbility")
  animator.setAnimationState("swoosh", "idle")
  mcontroller.setRotation(0)
  animator.setParticleEmitterActive("flip", false)
end
