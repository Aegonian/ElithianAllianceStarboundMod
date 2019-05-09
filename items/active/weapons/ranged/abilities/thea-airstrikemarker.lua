require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

TheaAirstrikeMarker = WeaponAbility:new()

function TheaAirstrikeMarker:init()

  --Set laser colour to "inactive"
  activeItem.setScriptedAnimationParameter("laserColour", self.laserColourInactive)

  self.chargeTimer = self.chargeTime
  self.cooldownTimer = 0
  
  self.shouldDischarge = false

  self:reset()

  self.weapon.onLeaveAbility = function()
    self:reset()
  end
end

function TheaAirstrikeMarker:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  if world.underground(mcontroller.position()) then
	animator.setAnimationState("location", "invalid")
  else
	animator.setAnimationState("location", "valid")
  end
  
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  --If holding fire, and nothing is holding back the charging process
  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
	and self.cooldownTimer == 0
	and not world.underground(mcontroller.position())
    and not status.resourceLocked("energy")
	and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

    self:setState(self.charge)
  --If the charge was prematurely stopped or interrupted somehow
  elseif self.chargeTimer < self.chargeTime and (self.fireMode ~= (self.activatingFireMode or self.abilitySlot) or world.lineTileCollision(mcontroller.position(), self:firePosition())) then
    animator.stopAllSounds("chargeLoop")
	animator.setAnimationState("charge", "off")
	self.chargeTimer = self.chargeTime
  end
end

function TheaAirstrikeMarker:charge()
  self.weapon:setStance(self.stances.charge)
  
  self.chargeHasStarted = true

  animator.playSound("chargeLoop", -1)
  animator.setAnimationState("charge", "charging")
  
  --While charging, but not yet ready, count down the charge timer
  while self.chargeTimer > 0 and self.fireMode == (self.activatingFireMode or self.abilitySlot) and not world.lineTileCollision(mcontroller.position(), self:firePosition()) and not world.underground(mcontroller.position()) do
    
	--Set the laser colour to "targeting"
    activeItem.setScriptedAnimationParameter("laserColour", self.laserColourTargeting)
	
	--Set the laser colour to "ready" very briefly before firing
	if self.chargeTimer < self.laserReadyTime then
	  activeItem.setScriptedAnimationParameter("laserColour", self.laserColourReady)
	end
	
	self.chargeTimer = math.max(0, self.chargeTimer - self.dt)

	--Prevent energy regen while charging
	status.setResourcePercentage("energyRegenBlock", 0.6)
	
	--Enable walk while firing
	if self.walkWhileFiring == true then
      mcontroller.controlModifiers({runningSuppressed=true})
	end
	
	--Debug the targeted position
	world.debugPoint(self:targetPosition(), "red")

    coroutine.yield()
  end
  
  --If the charge is ready, we have line of sight and plenty of energy, go to firing state
  if self.chargeTimer == 0 and status.overConsumeResource("energy", self:energyPerShot()) and not world.lineTileCollision(mcontroller.position(), self:firePosition()) and not world.underground(self:targetPosition()) then
    self:setState(self.fire)
  --If not charging and charge isn't ready, go to cooldown
  else
    self.shouldDischarge = true
    self:setState(self.cooldown)
  end
end

function TheaAirstrikeMarker:fire()
  self.weapon:setStance(self.stances.fire)
  
  animator.stopAllSounds("chargeLoop")
  animator.setAnimationState("charge", "off")
  
  animator.playSound("fire")
  
  self.chargeHasStarted = false
  
  --Prepare the projectiles for firing
  self:prepareProjectiles()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.chargeTimer = self.chargeTime
  
  self.cooldownTimer = self.cooldownTime
  self:setState(self.cooldown)
end

function TheaAirstrikeMarker:prepareProjectiles()
  --Create a list of projectiles to send to the projectile spawner stagehand
  local projectileList = {}
  
  --For every entry in the list, determine parameters here
  for i = 1, #self.projectiles do
	--Copy data from our config file
	local projectileConfig = self.projectiles[i]
	
	--Determine projectile spawn position and direction
	projectileConfig.position = self:projectilePosition(projectileConfig.heightRange, projectileConfig.widthRange)
	projectileConfig.direction = self:projectileVector(projectileConfig.inaccuracy)
	
	--Generate projectile parameters like power
	projectileConfig.params = sb.jsonMerge(projectileConfig.projectileParameters, {})
	projectileConfig.params.power = self:damagePerShot()
	projectileConfig.params.powerMultiplier = activeItem.ownerPowerMultiplier()
	
	--Set the projectile's ownerEntityId
	projectileConfig.ownerEntityId = activeItem.ownerEntityId()
	
	--If the projectile's spawn position isn't blocked, insert our newly created projectile config into the list
	if projectileConfig.position then
	  table.insert(projectileList, projectileConfig)
	end
  end
  
  --Create the stagehand that handles projectile spawning
  --sb.logInfo("CREATED NEW PROJECTILE LIST FOR AIRSTRIKE WEAPON")
  --sb.logInfo(sb.printJson(projectileList, 1))
  world.spawnStagehand(self:targetPosition(), self.stagehandType, {projectileList = projectileList})
end

function TheaAirstrikeMarker:cooldown()
  --Use the inactive laser colour (usually invisible)
  activeItem.setScriptedAnimationParameter("laserColour", self.laserColourInactive)
  
  if self.shouldDischarge == true then
    self.weapon:updateAim()
	self.weapon:setStance(self.stances.discharge)
	self.shouldDischarge = false
	
	animator.playSound("discharge")
	self.cooldownTimer = self.cooldownTime / 2
	
	local progress = 0
    util.wait(self.stances.discharge.duration, function()
      local from = self.stances.discharge.weaponOffset or {0,0}
      local to = self.stances.idle.weaponOffset or {0,0}
      self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

      self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.discharge.weaponRotation, self.stances.idle.weaponRotation))
      self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.discharge.armRotation, self.stances.idle.armRotation))

      progress = math.min(1.0, progress + (self.dt / self.stances.discharge.duration))
    end)
  else
    self.weapon:updateAim()
	self.weapon:setStance(self.stances.cooldown)
	
    local progress = 0
    util.wait(self.stances.cooldown.duration, function()
      local from = self.stances.cooldown.weaponOffset or {0,0}
      local to = self.stances.idle.weaponOffset or {0,0}
      self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

      self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.weaponRotation, self.stances.idle.weaponRotation))
      self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.armRotation, self.stances.idle.armRotation))

      progress = math.min(1.0, progress + (self.dt / self.stances.cooldown.duration))
    end)
  end
end

function TheaAirstrikeMarker:projectilePosition(heightRange, widthRange)
  --Calculate the randomized spawn position
  local yOffset = math.random(heightRange[1], heightRange[2])
  local xOffset = math.random(widthRange[1], widthRange[2])
  local position = vec2.add(self:targetPosition(), {xOffset, yOffset})
  
  return position
end

function TheaAirstrikeMarker:projectileVector(inaccuracy)
  local vector = vec2.rotate({0, -1}, sb.nrand(inaccuracy, 0))
  return vector
end

function TheaAirstrikeMarker:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function TheaAirstrikeMarker:targetPosition()
  local lineStart = self:firePosition()
  local lineEnd = vec2.add(lineStart, vec2.mul(vec2.norm(self:aimVector(0)), self.maxLaserDistance))
  
  local collidePoint = world.lineCollision(lineStart, lineEnd)
  if collidePoint then
	lineEnd = collidePoint
  end

  return lineEnd
end

function TheaAirstrikeMarker:aimVector()
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle)
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaAirstrikeMarker:energyPerShot()
  return self.baseEnergyUsage * (self.energyUsageMultiplier or 1.0)
end

function TheaAirstrikeMarker:damagePerShot()
  return self.baseDamage * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / #self.projectiles
end

function TheaAirstrikeMarker:uninit()
  self:reset()
end

function TheaAirstrikeMarker:reset()
  animator.setAnimationState("charge", "off")
  animator.stopAllSounds("chargeLoop")
  self.chargeTimer = self.chargeTime
  self.shouldDischarge = false
  self.weapon:setStance(self.stances.idle)
end