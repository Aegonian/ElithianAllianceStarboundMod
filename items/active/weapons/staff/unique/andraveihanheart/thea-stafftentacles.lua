require "/scripts/vec2.lua"
require "/scripts/util.lua"

TheaStaffTentacles = WeaponAbility:new()

function TheaStaffTentacles:init()
  self.chains = {}

  self.baseDamageFactor = config.getParameter("baseDamageFactor", 1.0)
  self.stances = config.getParameter("stances")

  self.targetOffset = self.targetOffset or {0, 0}
  self.targetOffsetRotationRate = self.targetOffsetRotationRate or 0
  
  activeItem.setCursor("/cursors/reticle0.cursor")
  self.weapon:setStance(self.stances.idle)

  self.weapon.onLeaveAbility = function()
    self:reset()
  end
end

function TheaStaffTentacles:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  world.debugPoint(self:focusPosition(), "blue")

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and not status.resourceLocked("energy") then

    self:setState(self.charge)
  end
end

function TheaStaffTentacles:charge()
  self.weapon:setStance(self.stances.charge)

  animator.playSound("charge")
  animator.setAnimationState("charge", "charge")
  animator.setParticleEmitterActive("charge", true)
  activeItem.setCursor("/cursors/charge2.cursor")

  local chargeTimer = self.stances.charge.duration
  while chargeTimer > 0 and self.fireMode == (self.activatingFireMode or self.abilitySlot) do
    chargeTimer = chargeTimer - self.dt

    mcontroller.controlModifiers({runningSuppressed=true})

    coroutine.yield()
  end

  animator.stopAllSounds("charge")

  if chargeTimer <= 0 then
    self:setState(self.charged)
  else
    animator.playSound("discharge")
    self:setState(self.cooldown)
  end
end

function TheaStaffTentacles:charged()
  self.weapon:setStance(self.stances.charged)

  animator.playSound("fullcharge")
  animator.playSound("chargedloop", -1)
  animator.setParticleEmitterActive("charge", true)

  local targetValid
  while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
    targetValid = self:targetValid()
    activeItem.setCursor(targetValid and "/cursors/chargeready.cursor" or "/cursors/chargeinvalid.cursor")

    mcontroller.controlModifiers({runningSuppressed=true})

    coroutine.yield()
  end

  self:setState(self.discharge)
end

function TheaStaffTentacles:discharge()
  self.weapon:setStance(self.stances.discharge)

  activeItem.setCursor("/cursors/reticle0.cursor")

  if self:targetValid() and status.overConsumeResource("energy", self.energyCost * self.baseDamageFactor) then
    animator.playSound("activate")
    self:createProjectiles()
  else
    animator.playSound("discharge")
    self:setState(self.cooldown)
    return
  end

  while #self.chains > 0 do
    if self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.lastFireMode ~= self.fireMode then
      self:killProjectiles()
    end
    self.lastFireMode = self.fireMode
	
	self:updateTentacles()

    status.setResourcePercentage("energyRegenBlock", 1.0)
	
	if self.walkWhileFiring then
	  mcontroller.controlModifiers({runningSuppressed=true})
	end
    coroutine.yield()
  end

  animator.playSound("discharge")
  animator.stopAllSounds("chargedloop")

  self:setState(self.cooldown)
end

function TheaStaffTentacles:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon.aimAngle = 0

  animator.setAnimationState("charge", "discharge")
  animator.setParticleEmitterActive("charge", false)
  activeItem.setCursor("/cursors/reticle0.cursor")

  util.wait(self.stances.cooldown.duration, function()

  end)
end

function TheaStaffTentacles:createProjectiles()

  local projectileCount = self.projectileCount or 1

  local projectileParameters = copy(self.projectileParameters)
  projectileParameters.power = self.baseDamageFactor * projectileParameters.baseDamage * config.getParameter("damageLevelMultiplier") / projectileCount
  projectileParameters.powerMultiplier = activeItem.ownerPowerMultiplier()

  for i = 1, projectileCount do
    local projectileId = world.spawnProjectile(
        self.projectileType,
        self:focusPosition(),
        activeItem.ownerEntityId(),
        self:aimVector(),
        self.projectileTracksUser or false,
        projectileParameters
      )

    if projectileId then
      self:addProjectile(projectileId)
    end
  end
end

-- =================================================================================
-- Functions for determining firing positions and aim vectors
-- =================================================================================

function TheaStaffTentacles:targetValid()
  local focusPos = self:focusPosition()
  return not world.lineTileCollision(focusPos, mcontroller.position())
end

function TheaStaffTentacles:focusPosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("stone", "focalPoint")))
end

function TheaStaffTentacles:aimVector()
  local aimVector = {}
  
  if self.allowIndependantAim then
	local aimAngle, aimDirection = activeItem.aimAngleAndDirection(self.weapon.aimOffset, activeItem.ownerAimPosition())
	aimVector = vec2.rotate({1, 0}, aimAngle + sb.nrand(self.inaccuracy or 0, 0))
  else
	aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(self.inaccuracy or 0, 0))
  end
  
  aimVector[1] = aimVector[1] * self.weapon.aimDirection
  return aimVector
end

-- =================================================================================
-- Functions for updating, controlling and terminating projectiles and chains
-- =================================================================================

function TheaStaffTentacles:addProjectile(projectileId)
  local newChain = copy(self.chain)
  newChain.targetEntityId = projectileId

  newChain.startOffset = vec2.add(newChain.startOffset or {0,0}, self.weapon.muzzleOffset)

  --Optional randomimzed arcRadius
  if newChain.arcRadiusRatio then
	local min = newChain.arcRadiusRatio[1]
	local max = newChain.arcRadiusRatio[2]
	newChain.arcRadiusRatio = (math.random() * (max - min) + min) * (math.random(2) * 2 - 3)
  end
  
  --Optional randomized waveforms
  if newChain.waveformRanges then
	newChain.waveform = {}
	
	--Multiplying values for increased variance
	local movementMin = newChain.waveformRanges.movement[1] * 100
	local movementMax = newChain.waveformRanges.movement[2] * 100
	local frequencyMin = newChain.waveformRanges.frequency[1] * 100
	local frequencyMax = newChain.waveformRanges.frequency[2] * 100
	local amplitudeMin = newChain.waveformRanges.amplitude[1] * 100
	local amplitudeMax = newChain.waveformRanges.amplitude[2] * 100
	
	--Setting the values
	newChain.waveform.movement = math.random(movementMin, movementMax) / 100
	newChain.waveform.frequency = math.random(frequencyMin, frequencyMax) / 100
	newChain.waveform.amplitude = math.random(amplitudeMin, amplitudeMax) / 100
  end
  
  table.insert(self.chains, newChain)
end

function TheaStaffTentacles:updateTentacles()
  self.chains = util.filter(self.chains, function (chain)
      return chain.targetEntityId and world.entityExists(chain.targetEntityId)
    end)

  local chainIndex = 0
  
  self.targetOffset = vec2.rotate(self.targetOffset, self.targetOffsetRotationRate * self.dt)
  
  for _,chain in pairs(self.chains) do
    local endPosition = world.entityPosition(chain.targetEntityId)
    local length = world.magnitude(endPosition, mcontroller.position())
	
	--Setting optionally randomized values
	if chain.arcRadiusRatio then
	  chain.arcRadius = chain.arcRadiusRatio * length
	end

    if self.guideProjectiles then
      local target = activeItem.ownerAimPosition()
      local distance = world.distance(target, mcontroller.position())
      if self.maxLength and vec2.mag(distance) > self.maxLength then
        target = vec2.add(vec2.mul(vec2.norm(distance), self.maxLength), mcontroller.position())
      end
	  
	  chainIndex = chainIndex + 1
	  
	  --Rotate the target offset
	  local rotationalOffset = 360 / (#self.chains + 1) * chainIndex
	  local localOffset = self.targetOffset
	  localOffset = vec2.rotate(localOffset, rotationalOffset)
	  
	  --world.debugText(rotationalOffset, vec2.add(mcontroller.position(), {0, chainIndex*3}), "yellow")
	  --world.debugText(localOffset[1], vec2.add(mcontroller.position(), {3, chainIndex*3}), "blue")
	  --world.debugText(localOffset[2], vec2.add(mcontroller.position(), {3, chainIndex*3+1}), "green")
	  
	  target = vec2.add(target, localOffset)
	  world.debugPoint(target, "red")
	  
      world.callScriptedEntity(chain.targetEntityId, "setTargetPosition", target)
    end
  end

  activeItem.setScriptedAnimationParameter("chains", self.chains)
end

function TheaStaffTentacles:killProjectiles()
  for _,chain in pairs(self.chains) do
    if world.entityExists(chain.targetEntityId) then
      world.callScriptedEntity(chain.targetEntityId, "projectile.die")
    end
  end
end

-- =================================================================================
-- Functions for resetting the weapon
-- =================================================================================

function TheaStaffTentacles:reset()
  self.weapon:setStance(self.stances.idle)
  animator.stopAllSounds("chargedloop")
  animator.stopAllSounds("fullcharge")
  animator.setAnimationState("charge", "idle")
  animator.setParticleEmitterActive("charge", false)
  activeItem.setCursor("/cursors/reticle0.cursor")
end

function TheaStaffTentacles:uninit(weaponUninit)
  self:reset()
  if weaponUninit then
    self:killProjectiles()
  end
end
