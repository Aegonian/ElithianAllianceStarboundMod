require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

-- Bow primary ability
TheaChargedTentacleShot = WeaponAbility:new()

function TheaChargedTentacleShot:init()
  self.chains = {}
  
  self.chargeTimer = self.chargeTime
  self.cooldownTimer = 0
  
  self.chargeHasStarted = false
  self.shouldDischarge = false

  self:reset()

  self.weapon.onLeaveAbility = function()
    self:reset()
  end
end

function TheaChargedTentacleShot:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  --If holding fire, and nothing is holding back the charging process
  if self:shouldFire() and not self.weapon.currentAbility then
    self:setState(self.charge)
	
  --If the charge was prematurily stopped or interrupted somehow
  elseif self.chargeHasStarted == true and (self.fireMode ~= (self.activatingFireMode or self.abilitySlot) or world.lineTileCollision(mcontroller.position(), self:firePosition())) then
    animator.stopAllSounds("chargeLoop")
	animator.setAnimationState("charge", "off")
	animator.setParticleEmitterActive("chargeparticles", false)
	self.chargeTimer = self.chargeTime
  end
end

function TheaChargedTentacleShot:shouldFire()
  return self.fireMode == (self.activatingFireMode or self.abilitySlot)
      and self.cooldownTimer == 0
      and #self.chains < self.maxProjectiles
      and not status.resourceLocked("energy")
      and not world.lineTileCollision(mcontroller.position(), self:firePosition())
end

function TheaChargedTentacleShot:charge()
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
	
	--Enable walk while firing
	if self.walkWhileFiring == true then
      mcontroller.controlModifiers({runningSuppressed=true})
	end

    coroutine.yield()
  end
  
  --If the charge is ready but we need to wait for release
  if self.chargeTimer == 0 and not world.lineTileCollision(mcontroller.position(), self:firePosition()) and self.fireOnRelease then
    self:setState(self.charged)
	
  --If the charge is ready and we are able to fire immediately
  elseif self.chargeTimer == 0 and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
    self:setState(self.firing)
	
  --If not charging and charge isn't ready, go to cooldown
  else
    self.shouldDischarge = true
	animator.playSound("discharge")
    self:setState(self.cooldown)
  end
end

function TheaChargedTentacleShot:charged()
  self.weapon:setStance(self.stances.charged)

  animator.playSound("fullcharge")
  animator.playSound("chargedloop", -1)
  animator.setParticleEmitterActive("chargeready", true)
  
  --While waiting for release
  while self.fireMode == (self.activatingFireMode or self.abilitySlot) do

	--Prevent energy regen while charging
	status.setResourcePercentage("energyRegenBlock", 0.6)
	
	--Enable walk while firing
	if self.walkWhileFiring == true then
      mcontroller.controlModifiers({runningSuppressed=true})
	end

    coroutine.yield()
  end
  
  --If the button is released, and nothing is preventing us from firing
  if not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
    self:setState(self.firing)
  --If the firing sequence was interrupted
  else
    self.shouldDischarge = true
	animator.playSound("discharge")
    self:setState(self.cooldown)
  end
end

function TheaChargedTentacleShot:firing()
  self.weapon:setStance(self.stances.fire)

  self:fire()

  while #self.chains > 0 do
    if self:shouldFire() then
      self:fire()
    end

    self:updateTentacles()
    coroutine.yield()
  end

  self.chargeTimer = self.chargeTime
  
  self.cooldownTimer = self.cooldownTime
  self:setState(self.cooldown)
end

function TheaChargedTentacleShot:fire()
  status.overConsumeResource("energy", self:energyPerShot())
  
  self.weapon:setStance(self.stances.fire)
  
  animator.stopAllSounds("chargeLoop")
  animator.setAnimationState("charge", "off")
  animator.setParticleEmitterActive("chargeparticles", false)
  
  self.chargeHasStarted = false
  
  --Fire a projectile and show a muzzleflash, then continue on with this state
  self:fireProjectile()
  self:muzzleFlash()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end
end

function TheaChargedTentacleShot:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)

  if not projectileType then
    projectileType = self.projectileType
  end
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy),
        false,
        params
      )
	self:addProjectile(projectileId)
	
	--If the ability config has this set to true, then the projectile fired will align with the player's aimVector shortly after being fired (as in the Rocket Burst ability) 
	if self.alignProjectiles then
	  world.callScriptedEntity(projectileId, "setApproach", self:aimVector(0, 1))
	end
  end
  
  return projectileId
end

function TheaChargedTentacleShot:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire")

  animator.setLightActive("muzzleFlash", true)
end

function TheaChargedTentacleShot:cooldown()
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

function TheaChargedTentacleShot:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function TheaChargedTentacleShot:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaChargedTentacleShot:energyPerShot()
  return self.baseEnergyUsage * (self.energyUsageMultiplier or 1.0)
end

function TheaChargedTentacleShot:damagePerShot()
  return self.baseDamage * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

--Functions for controlling, updating and terminating tentacle projectiles

function TheaChargedTentacleShot:addProjectile(projectileId)
  local newChain = copy(self.chain)
  newChain.targetEntityId = projectileId

  newChain.startOffset = vec2.add(newChain.startOffset or {0,0}, self.weapon.muzzleOffset)

  local min = newChain.arcRadiusRatio[1]
  local max = newChain.arcRadiusRatio[2]
  newChain.arcRadiusRatio = (math.random() * (max - min) + min) * (math.random(2) * 2 - 3)

  table.insert(self.chains, newChain)
end

function TheaChargedTentacleShot:updateTentacles()
  self.chains = util.filter(self.chains, function (chain)
      return chain.targetEntityId and world.entityExists(chain.targetEntityId)
    end)

  for _,chain in pairs(self.chains) do
    local endPosition = world.entityPosition(chain.targetEntityId)
    local length = world.magnitude(endPosition, mcontroller.position())
    chain.arcRadius = chain.arcRadiusRatio * length

    if self.guideProjectiles then
      local target = activeItem.ownerAimPosition()
      local distance = world.distance(target, mcontroller.position())
      if self.maxLength and vec2.mag(distance) > self.maxLength then
        target = vec2.add(vec2.mul(vec2.norm(distance), self.maxLength), mcontroller.position())
      end
      world.callScriptedEntity(chain.targetEntityId, "setTargetPosition", target)
    end
  end

  activeItem.setScriptedAnimationParameter("chains", self.chains)
end

function TheaChargedTentacleShot:killProjectiles()
  for _,chain in pairs(self.chains) do
    if world.entityExists(chain.targetEntityId) then
      world.callScriptedEntity(chain.targetEntityId, "projectile.die")
    end
  end
end

--Resume regular functions

function TheaChargedTentacleShot:uninit()
  self:reset()
end

function TheaChargedTentacleShot:reset()
  animator.setAnimationState("charge", "off")
  animator.setParticleEmitterActive("chargeparticles", false)
  self.chargeHasStarted = false
  self.weapon:setStance(self.stances.idle)
  self:killProjectiles()
end