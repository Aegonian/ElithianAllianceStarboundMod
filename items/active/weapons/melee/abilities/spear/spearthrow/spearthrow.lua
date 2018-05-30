require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

SpearThrow = WeaponAbility:new()

function SpearThrow:init()
  self:reset()
  
  self.projectileGravityMultiplier = root.projectileGravityMultiplier(self.projectileType)
  self.thrownProjectile = nil
  self.aimOutOfReach = false
  self.aimTypeSwitchTimer = 0
  self.cooldownSoundHasPlayed = false
  
  self.cooldownTimer = self.cooldownTime
end

function SpearThrow:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  if self.thrownProjectile == nil or not world.entityExists(self.thrownProjectile) then
	activeItem.setHoldingItem(true)
  end
  
  --Optionally play a looping idle sound
  if animator.hasSound("idleLoop") and not self.idleLoopPlaying then
	animator.playSound("idleLoop", -1)
	self.idleLoopPlaying = true
  end
  
  --Optionally turn lights on and off depending on cooldown status
  if self.cooldownLightsOff then
	if self.cooldownTimer == 0 then
	  animator.setAnimationState("lights", "on")
	else
	  animator.setAnimationState("lights", "off")
	end
  end

  --Optionally play a sound when the trhow ability is ready for use
  if animator.hasSound("cooldownReady") and not self.cooldownSoundHasPlayed and self.cooldownTimer == 0 then
	animator.playSound("cooldownReady")
	self.cooldownSoundHasPlayed = true
  end
  
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  self.aimTypeSwitchTimer = math.max(0, self.aimTypeSwitchTimer - self.dt)
  
  if not self.weapon.currentAbility
	and self.fireMode == (self.activatingFireMode or self.abilitySlot)
	and self.cooldownTimer == 0
	and self.windupTimer > 0
	and not status.resourceLocked("energy") then
	  self:setState(self.windup)
  end
end

function SpearThrow:windup()
  self.weapon:updateAim()

  --Optionally turn off idle loop sound
  if animator.hasSound("idleLoop") then
	animator.stopAllSounds("idleLoop")
	self.idleLoopPlaying = true
  end
  
  --Optionally play windup animations
  if self.windupParticles then
	animator.setParticleEmitterActive("windup", true)
  end
  if animator.hasSound("windupLoop") then
	animator.playSound("windupLoop", -1)
  end
  if animator.hasSound("windupStart") then
	animator.playSound("windupStart")
  end
  
  while self.windupTimer > 0 and self.fireMode == (self.activatingFireMode or self.abilitySlot) do
	self.windupTimer = math.max(0, self.windupTimer - self.dt)
	activeItem.emote("sleep")

	if self.walkWhileFiring then mcontroller.controlModifiers({runningSuppressed = true}) end

	--Force the aim angle into a set position
	self.weapon.aimAngle = 0
	self.weapon:setStance(self.stances.windup)
    coroutine.yield()
  end
  
  --Optionally turn off windup animations
  if self.windupParticles then
	animator.setParticleEmitterActive("windup", false)
  end
  if animator.hasSound("windupLoop") then
	animator.stopAllSounds("windupLoop")
  end
  if self.windupTimer == 0 then
	self:setState(self.aiming)
  end
end

function SpearThrow:aiming()
  if self.windupTimer == 0 then
	self.weapon:setStance(self.stances.aiming)
	activeItem.emote("annoyed")
  end
  
  --Optionally play aiming animations
  if self.aimingParticles then
	animator.setParticleEmitterActive("aiming", true)
  end
  if animator.hasSound("aimingLoop") then
	animator.playSound("aimingLoop", -1)
  end
  if animator.hasSound("aimingReady") then
	animator.playSound("aimingReady")
  end
  
  --While holding the mouse button, update our aim and wait for player to release
  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.windupTimer == 0 do
	local aimVec = self:idealAimVector()
    if self.aimOutOfReach or self.aimTypeSwitchTimer > 0 then
	  local aimAngle, aimDirection = activeItem.aimAngleAndDirection(self.weapon.aimOffset, activeItem.ownerAimPosition())
	  self.weapon.aimAngle = aimAngle
	  
	  self.weapon:updateAim()
	  
	  world.debugLine(self:firePosition(), vec2.add(self:firePosition(), vec2.mul(vec2.norm(self:idealAimVector()), 3)), "yellow")
	  --world.debugText("aimAngle = " .. aimAngle, vec2.add(mcontroller.position(), {0,1}), "red")
	  --world.debugText("timer = " .. self.aimTypeSwitchTimer, vec2.add(mcontroller.position(), {0,2}), "red")
	else
	  aimVec[1] = aimVec[1] * self.weapon.aimDirection
	  self.weapon.aimAngle = 0 --Reset the aimAngle every frame to prevent values from continously stacking, causing the weapon to spasm
      self.weapon.aimAngle = self.weapon.aimAngle + vec2.angle(aimVec)
	
	  world.debugLine(self:firePosition(), vec2.add(self:firePosition(), vec2.mul(vec2.norm(self:idealAimVector()), 3)), "green")
	  --world.debugText("self.weapon.aimAngle = " .. self.weapon.aimAngle, vec2.add(mcontroller.position(), {0,1}), "red")
	  --world.debugText("aimVec Angle = " .. vec2.angle(aimVec), vec2.add(mcontroller.position(), {0,2}), "red")
	end
	
	if self.walkWhileFiring then
	  mcontroller.controlModifiers({runningSuppressed = true})
	end
	
	coroutine.yield()
  end
  
  --Optionally turn off aiming animations
  if self.aimingParticles then
	animator.setParticleEmitterActive("aiming", false)
  end
  if animator.hasSound("aimingLoop") then
	animator.stopAllSounds("aimingLoop")
  end
  
  if self.windupTimer == 0 then
	self:setState(self.fire)
  else
    self:reset()
  end
end

function SpearThrow:fire()
  self.weapon:setStance(self.stances.fire)
  
  if not world.pointTileCollision(self:firePosition()) and status.overConsumeResource("energy", self.energyPerShot) then
    local params = copy(self.projectileParameters)
	params.power = params.power * config.getParameter("damageLevelMultiplier")
    params.powerMultiplier = activeItem.ownerPowerMultiplier()

    self.thrownProjectile = world.spawnProjectile(
	  self.projectileType,
	  self:firePosition(),
	  activeItem.ownerEntityId(),
	  self:idealAimVector(),
	  false,
	  params
	)

	--Play the throwing sound and hide the weapon using animation states
    animator.playSound("throw")
	animator.setAnimationState("weapon", "hidden")
	
    self.windupTimer = 0

    util.wait(self.stances.fire.duration)
  end
  
  if self.thrownProjectile then
    self:setState(self.cooldown)
  end
end

function SpearThrow:cooldown()
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  self.weapon:setStance(self.stances.cooldown)
  
  while world.entityExists(self.thrownProjectile) do
    world.debugText("Active projectiles detected!", mcontroller.position(), "yellow")
	activeItem.setHoldingItem(false)
    coroutine.yield()
  end
  
  --Return the weapon to the player's hand
  animator.setAnimationState("weapon", "returning")
  activeItem.setHoldingItem(true)
  
  --Optionally turn off ready and idle sounds
  if animator.hasSound("idleLoop") then
	animator.stopAllSounds("idleLoop")
  end
  self.idleLoopPlaying = false
end

function SpearThrow:idealAimVector()
  self.aimOutOfReach = true
  --If we are at a zero G position, use regular aiming instead of arc-adjusted aiming
  if mcontroller.zeroG() then
	local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle)
	aimVector[1] = aimVector[1] * mcontroller.facingDirection()
	self.aimTypeSwitchTimer = 0.1 --Hold the last aiming type for a brief moment to smooth transitions
	return aimVector
  else
	local targetOffset = world.distance(activeItem.ownerAimPosition(), self:firePosition())
	
	--Code taken from util.lua to determine when the aim position is out of range
	local x = targetOffset[1]
	local y = targetOffset[2]
	local g = self.projectileGravityMultiplier * world.gravity(mcontroller.position())
	local v = self.projectileParameters.speed
	local reverseGravity = false
	if g < 0 then
	  reverseGravity = true
	  g = -g
	  y = -y
	end
	local term1 = v^4 - (g * ((g * x * x) + (2 * y * v * v)))
	
	if term1 > 0 then
	  self.aimOutOfReach = false
	  return util.aimVector(targetOffset, self.projectileParameters.speed, self.projectileGravityMultiplier, false)
	else
	  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle)
	  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
	  self.aimTypeSwitchTimer = 0.1 --Hold the last aiming type for a brief moment to smooth transitions
	  return aimVector
	end
  end
end

function SpearThrow:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end

function SpearThrow:reset()
  self.windupTimer = self.windupTime
  self.cooldownTimer = self.cooldownTime
  self.cooldownSoundHasPlayed = false
  
  if animator.animationState("weapon") ~= "visible" then
	--Return the weapon to the player's hand
	animator.setAnimationState("weapon", "returning")
  end
  
  --Optionally turn off windup animations
  if self.windupParticles then
	animator.setParticleEmitterActive("windup", false)
  end
  if animator.hasSound("windupLoop") then
	animator.stopAllSounds("windupLoop")
  end
  
  --Optionally turn off aiming animations
  if self.aimingParticles then
	animator.setParticleEmitterActive("aiming", false)
  end
  if animator.hasSound("aimingLoop") then
	animator.stopAllSounds("aimingLoop")
  end
  
  --Optionally turn off ready and idle sounds
  if animator.hasSound("idleLoop") then
	animator.stopAllSounds("idleLoop")
  end
  self.idleLoopPlaying = false
end

function SpearThrow:uninit()
  if self.thrownProjectile then
	world.sendEntityMessage(self.thrownProjectile, "kill")
  end
  self:reset()
end
