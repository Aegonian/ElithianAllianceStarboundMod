require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

-- Custom ability that plays a windup animation, releases a drone projectile, then plays a windown animation. Uses an indicator light to signal when the ability is ready to be used again
TheaDroneRelease = WeaponAbility:new()

function TheaDroneRelease:init()
  self.cooldownTimer = self.cooldownTime
  self.windupTimer = self.windupTime

  self:reset()

  self.weapon.onLeaveAbility = function()
    self:reset()
  end
end

function TheaDroneRelease:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  world.debugPoint(self:releasePosition(), "yellow")
  world.debugText(self.cooldownTimer, vec2.add(mcontroller.position(), {0,2}), "yellow")
  
  if self.cooldownTimer > 0 then
	animator.setAnimationState("indicator", "cooldown")
  else
	if animator.animationState("indicator") ~= "ready" then
	  animator.playSound("droneReady")
	end
	animator.setAnimationState("indicator", "ready")
  end

  --If holding fire, and nothing is holding back the charging process
  if self.fireMode == "alt"
    and not self.weapon.currentAbility
	and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
	and not world.lineTileCollision(mcontroller.position(), self:releasePosition()) then

    self:setState(self.windup)
  end
end

function TheaDroneRelease:windup()
  self.weapon:setStance(self.stances.windup)

  animator.playSound("windupLoop", -1)
  animator.setAnimationState("weapon", "windup")
  
  --While in windup, count down windup timer and check if windup is still valid
  while self.windupTimer > 0 and not world.lineTileCollision(mcontroller.position(), self:releasePosition()) do
    self.windupTimer = math.max(0, self.windupTimer - self.dt)

	--Prevent energy regen while in windup
	status.setResourcePercentage("energyRegenBlock", 0.6)
	
	--Enable walk while firing
	if self.walkWhileFiring == true then
      mcontroller.controlModifiers({runningSuppressed=true})
	end

    coroutine.yield()
  end
  
  animator.stopAllSounds("windupLoop")
  
  --If the windup state was finished
  if self.windupTimer == 0 and status.overConsumeResource("energy", self:energyPerRelease()) and not world.lineTileCollision(mcontroller.position(), self:releasePosition()) then
	self:setState(self.release)
  --If the windup state was interrupted
  else
    self.shouldDischarge = true
	animator.playSound("releaseFailure")
    self:setState(self.winddown, false)
  end
end

function TheaDroneRelease:release()
  self.weapon:setStance(self.stances.release)
  
  animator.setAnimationState("weapon", "release")
  animator.playSound("release")
  
  --Set up parameters for the drone
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerSecond()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)
  
  --Spawn the drone
  world.spawnProjectile(
	self.projectileType,
	self:releasePosition(),
	activeItem.ownerEntityId(),
	{0,0},
	false,
	params
  )
  
  self.cooldownTimer = self.cooldownTime
  
  if self.stances.release.duration then
    util.wait(self.stances.release.duration)
  end
  self:setState(self.winddown, true)
end

function TheaDroneRelease:winddown(releaseSuccess)
  self.weapon:setStance(self.stances.winddown)

  animator.playSound("winddownLoop", -1)
  
  --Force the windup animation to complete before playing winddown
  while animator.animationState("weapon") == "windup" do
    coroutine.yield()
  end
  
  --Play a winddown animation, based on wether or not the drone was successfully released
  if releaseSuccess then
	animator.setAnimationState("weapon", "winddown")
  else
	animator.setAnimationState("weapon", "winddownFail")
  end
  
  --Wait the stance to end, or for the chosen winddown animation to finish
  if self.stances.winddown.duration then
    util.wait(self.stances.winddown.duration)
  else
	while animator.animationState("weapon") == ("winddown" or "winddownFail") do
	  coroutine.yield()
	end
  end
  
  animator.stopAllSounds("windupLoop")
end

function TheaDroneRelease:releasePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.droneReleasePosition))
end

function TheaDroneRelease:energyPerRelease()
  return self.droneEnergyUsage * (self.energyUsageMultiplier or 1.0)
end

function TheaDroneRelease:damagePerSecond()
  return self.droneDPS * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier")
end

function TheaDroneRelease:uninit()
  self:reset()
end

function TheaDroneRelease:reset()
  animator.setAnimationState("weapon", "idle")
  animator.stopAllSounds("windupLoop")
  animator.stopAllSounds("winddownLoop")
  self.weapon:setStance(self.stances.idle)
  
  self.windupTimer = self.windupTime
end