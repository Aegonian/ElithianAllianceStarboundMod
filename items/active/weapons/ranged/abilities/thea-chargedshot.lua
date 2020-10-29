require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

-- Charged primary ability
TheaChargedShot = WeaponAbility:new()

function TheaChargedShot:init()

  self.chargeTimer = self.chargeTime
  self.cooldownTimer = 0
  
  self.chargeHasStarted = false
  self.shouldDischarge = false
  
  --Optional animation set-up
  if self.activeAnimation then
	animator.setAnimationState("gun", "idle")
  end

  self:reset()

  self.weapon.onLeaveAbility = function()
    self:reset()
  end
end

function TheaChargedShot:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  --world.debugText("Projectile Type Primary: " .. sb.print(self.projectileType), vec2.add(mcontroller.position(), {0,2}), "yellow")

  --If holding fire, and nothing is holding back the charging process
  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
	and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
	and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

    self:setState(self.charge)
  --If the charge was prematurely stopped or interrupted somehow
  elseif self.chargeHasStarted == true and (self.fireMode ~= (self.activatingFireMode or self.abilitySlot) or world.lineTileCollision(mcontroller.position(), self:firePosition())) then
    animator.stopAllSounds("chargeLoop")
	animator.setAnimationState("charge", "off")
	animator.setParticleEmitterActive("chargeparticles", false)
	self.chargeTimer = self.chargeTime
  end
  
  --Optional animation while firing
  if self.activeAnimation then
	if self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 and animator.animationState("gun") == "idle" then
	  animator.setAnimationState("gun", "activate")
	elseif (self.fireMode ~= (self.activatingFireMode or self.abilitySlot) or self.cooldownTimer > 0) and animator.animationState("gun") == "active" then
	  animator.setAnimationState("gun", "deactivate")
	end
  end
end

function TheaChargedShot:charge()
  self.weapon:setStance(self.stances.charge)
  
  self.chargeHasStarted = true

  animator.playSound("chargeLoop", -1)
  animator.setAnimationState("charge", "charging")
  animator.setParticleEmitterActive("chargeparticles", true)
  
  --While charging, but not yet ready, count down the charge timer
  while self.chargeTimer > 0 and self.fireMode == (self.activatingFireMode or self.abilitySlot) and not world.lineTileCollision(mcontroller.position(), self:firePosition()) do
    self.chargeTimer = math.max(0, self.chargeTimer - self.dt)

	--Prevent energy regen while charging
	status.setResourcePercentage("energyRegenBlock", 0.6)

	--Optionally update the charge intake particles
	if self.useChargeParticles then
	  self:updateChargeIntake(self.chargeTimer)
	end
	
	--Enable walk while firing
	if self.walkWhileFiring == true then
      mcontroller.controlModifiers({runningSuppressed=true})
	end

    coroutine.yield()
  end
  
  --Optionally reset the charge intake particles
  if self.useChargeParticles then
	activeItem.setScriptedAnimationParameter("particles", {})
  end
  
  --If the charge is ready, we have line of sight and plenty of energy, go to firing state
  if self.chargeTimer == 0 and status.overConsumeResource("energy", self:energyPerShot()) and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
	if self.fireType == "burst" then
	  self:setState(self.burst)
	else
	  self:setState(self.fire)
	end
  --If not charging and charge isn't ready, go to cooldown
  else
    self.shouldDischarge = true
	animator.playSound("discharge")
    self:setState(self.cooldown)
  end
end

function TheaChargedShot:fire()
  self.weapon:setStance(self.stances.fire)
  
  animator.stopAllSounds("chargeLoop")
  animator.setAnimationState("charge", "off")
  animator.setParticleEmitterActive("chargeparticles", false)
  
  self.chargeHasStarted = false
  
  --Fire a projectile and show a muzzleflash, then continue on with this state
  self:fireProjectile()
  self:muzzleFlash()
  
  --Optionally play a firing animation
  if self.singleFireAnimation then
	animator.setAnimationState("gun", "active")
  end
  
  --Optionally apply self-damage
  if self.selfDamage then
	status.applySelfDamageRequest({
	  damageType = "IgnoresDef",
	  damage = math.max(1, self.selfDamage * config.getParameter("damageLevelMultiplier") * activeItem.ownerPowerMultiplier()),
	  damageSourceKind = self.selfDamageSource,
	  sourceEntityId = activeItem.ownerEntityId()
	})
  end
  
  if self.recoilKnockbackVelocity then
	--If not crouching or if crouch does not impact recoil
	if not (self.crouchStopsRecoil and mcontroller.crouching()) then
	  local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(self:aimVector(0), -1)), self.recoilKnockbackVelocity)
	  --If aiming down and not in zero G, reset Y velocity first to allow for breaking of falls
	  if (self.weapon.aimAngle <= 0 and not mcontroller.zeroG()) then
		mcontroller.setYVelocity(0)
	  end
	  mcontroller.addMomentum(recoilVelocity)
	  mcontroller.controlJump()
	--If crouching
	elseif self.crouchRecoilKnockbackVelocity then
	  local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(self:aimVector(0), -1)), self.crouchRecoilKnockbackVelocity)
	  mcontroller.setYVelocity(0)
	  mcontroller.addMomentum(recoilVelocity)
	end
  end

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.chargeTimer = self.chargeTime
  
  self.cooldownTimer = self.cooldownTime
  self:setState(self.cooldown)
end

function TheaChargedShot:burst()
  self.weapon:setStance(self.stances.fire)
  
  animator.stopAllSounds("chargeLoop")
  animator.setAnimationState("charge", "off")
  animator.setParticleEmitterActive("chargeparticles", false)
  
  self.chargeHasStarted = false
  
  --Optionally apply self-damage
  if self.selfDamage then
	status.applySelfDamageRequest({
	  damageType = "IgnoresDef",
	  damage = math.max(0.33, (self.selfDamage / self.burstCount) * config.getParameter("damageLevelMultiplier") * activeItem.ownerPowerMultiplier()),
	  damageSourceKind = self.selfDamageSource,
	  sourceEntityId = activeItem.ownerEntityId()
	})
  end
  
  --Burst projectiles and muzzleflash
  local shots = self.burstCount
  local burstNumber = 0
  while shots > 0 and status.overConsumeResource("energy", self:energyPerShot()) do
	self:fireProjectile(burstNumber)
    self:muzzleFlash()
    shots = shots - 1
	burstNumber = burstNumber + 1
  
    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.armRotation))
	
	--Optionally apply knockback to the player
	if self.recoilKnockbackVelocity then
	  --If not crouching or if crouch does not impact recoil
	  if not (self.crouchStopsRecoil and mcontroller.crouching()) then
		local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(self:aimVector(0), -1)), self.recoilKnockbackVelocity)
		--If aiming down and not in zero G, reset Y velocity first to allow for breaking of falls
		if (self.weapon.aimAngle <= 0 and not mcontroller.zeroG()) then
		  mcontroller.setYVelocity(0)
		end
		mcontroller.addMomentum(recoilVelocity)
		mcontroller.controlJump()
	  --If crouching
	  elseif self.crouchRecoilKnockbackVelocity then
		local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(self:aimVector(0), -1)), self.crouchRecoilKnockbackVelocity)
		mcontroller.setYVelocity(0)
		mcontroller.addMomentum(recoilVelocity)
	  end
	end

    util.wait(self.burstTime)
  end

  self.chargeTimer = self.chargeTime
  
  self.cooldownTimer = self.cooldownTime
  self:setState(self.cooldown)
end

function TheaChargedShot:fireProjectile(burstNumber)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)

  local projectileType = self.projectileType
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end
  
  local shotNumber = 0

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end
	
	shotNumber = i

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(self.inaccuracy, shotNumber, burstNumber),
        false,
        params
      )
	
	--If the ability config has this set to true, then the projectile fired will align with the player's aimVector shortly after being fired (as in the Rocket Burst ability) 
	if self.alignProjectiles then
	  world.callScriptedEntity(projectileId, "setApproach", self:aimVector(0, 1))
	end
  end
  
  return projectileId
end

function TheaChargedShot:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  if self.casingEjectParticles then
	animator.burstParticleEmitter("casingEject")
  end
  animator.playSound("fire")

  animator.setLightActive("muzzleFlash", true)
end

function TheaChargedShot:cooldown()
  if self.shouldDischarge == true then
    self.weapon:updateAim()
	self.weapon:setStance(self.stances.discharge)
	self.shouldDischarge = false
	
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

function TheaChargedShot:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function TheaChargedShot:aimVector(inaccuracy, shotNumber, burstNumber)
  local angleAdjustmentList = self.angleAdjustmentsPerShot or {}
  local aimVector = {}
  
  if self.allowIndependantAim then
	local aimAngle, aimDirection = activeItem.aimAngleAndDirection(self.weapon.aimOffset, activeItem.ownerAimPosition())
	aimVector = vec2.rotate({1, 0}, aimAngle + sb.nrand(inaccuracy or 0, 0) + (angleAdjustmentList[shotNumber] or 0) + ((burstNumber or 0) * (self.burstRiseAngle or 0)))
  else
	aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy or 0, 0) + (angleAdjustmentList[shotNumber] or 0) + ((burstNumber or 0) * (self.burstRiseAngle or 0)))
  end
  
  aimVector[1] = aimVector[1] * self.weapon.aimDirection
  return aimVector
end

function TheaChargedShot:energyPerShot()
  if self.fireType == "burst" then
	return self.baseEnergyUsage * (self.energyUsageMultiplier or 1.0) / self.burstCount
  else
	return self.baseEnergyUsage * (self.energyUsageMultiplier or 1.0)
  end
end

function TheaChargedShot:damagePerShot()
  if self.fireType == "burst" then
	return self.baseDamage * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount / self.burstCount
  else
	return self.baseDamage * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
  end
end

function TheaChargedShot:updateChargeIntake(chargeTimeLeft)  
  --Update existing charge particles
  for i,particle in ipairs(self.chargeParticles) do
	particle.muzzlePosition = self:firePosition()
	particle.lifeTime = particle.lifeTime - self.dt
  end
  
  --If not yet at max particle count, add a new particle to the list
  self.particleCooldown = math.max(0, self.particleCooldown - self.dt)
  if self.particleCooldown == 0 and #self.chargeParticles < self.maxChargeParticles and chargeTimeLeft > self.particleLifetime then
	local particle = {
      muzzlePosition = self:firePosition(),
      vector = vec2.rotate({self.maxParticleDistance, 0}, math.random() * (2 * math.pi)),
	  lifeTime = self.particleLifetime,
	  maxLifeTime = self.particleLifetime
    }
    table.insert(self.chargeParticles, particle)
	
	self.particleCooldown = self.timeBewteenParticles
  end
  
  --Filter the existing particle list by particle lifetime to remove particles with negative lifetime
  local newChargeParticles = {}
  for i,particle in ipairs(self.chargeParticles) do	
	if particle.lifeTime > 0 then
	  newChargeParticles[#newChargeParticles+1] = particle
	end
  end
  self.chargeParticles = newChargeParticles
  
  activeItem.setScriptedAnimationParameter("particles", self.chargeParticles)
end

function TheaChargedShot:uninit()
  self:reset()
end

function TheaChargedShot:reset()
  animator.setAnimationState("charge", "off")
  animator.setParticleEmitterActive("chargeparticles", false)
  self.chargeHasStarted = false
  self.weapon:setStance(self.stances.idle)
  
  --Charge particle set-up
  if self.useChargeParticles then
	self.chargeParticles = {}
	self.particleCooldown = 0
	activeItem.setScriptedAnimationParameter("particles", {})
  end
end