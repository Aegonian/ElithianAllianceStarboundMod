require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/items/active/weapons/weapon.lua"

GroundConduct = WeaponAbility:new()

function GroundConduct:init()
  self.cooldownTimer = self.cooldownTime
  self.burstTimer = self.burstTime
end

function GroundConduct:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  if self.weapon.currentAbility == nil and self.fireMode == "alt" and mcontroller.onGround() and not status.resourceLocked("energy") and self.cooldownTimer <= 0 then
    self:setState(self.windup)
  end
end

function GroundConduct:windup()
  --Lock the player in place
  mcontroller.controlModifiers({ movementSuppressed = true })
  
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  util.wait(self.stances.windup.duration)
  
  self:setState(self.fire)
end

function GroundConduct:fire()
  --Lock the player in place
  mcontroller.controlModifiers({ movementSuppressed = true })
  
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  animator.playSound("fire")
  animator.setAnimationState("swoosh", "fire")
  
  util.wait(self.stances.fire.duration)
  
  local impact, impactHeight = self:impactPosition()
  if impact then
	self.weapon.weaponOffset = {0, impactHeight + self.impactWeaponOffset}
  end
  if impact then
	--Fire the initial shockwave
	if status.overConsumeResource("energy", self.energyPerWave) then
	  self:fireShockwave()
	end
	
	--If we hold the attack button, go to hold state
	if self.fireMode == "alt" then
	  self:setState(self.hold)
	end
  end
  
  --If there was no impact, go to cooldown
  self.weapon:setStance(self.stances.cooldown)
  util.wait(self.stances.cooldown.duration)
  
  self.cooldownTimer = self.cooldownTime
end

function GroundConduct:hold()
  self.weapon:setStance(self.stances.hold)
  self.weapon:updateAim()
  
  local impact, impactHeight = self:impactPosition()
  if impact then
	self.weapon.weaponOffset = {0, impactHeight + self.impactWeaponOffset}
  end
  
  animator.playSound("holdLoop", -1)
  
  while self.fireMode == "alt" and impact do
	--Lock the player in place
	mcontroller.controlModifiers({ movementSuppressed = true })
	
	status.overConsumeResource("energy", self.energyUsage * self.dt)
	
	self.burstTimer = math.max(0, self.burstTimer - self.dt)
	
	local impact, impactHeight = self:impactPosition()
	if impact then
	  self.weapon.weaponOffset = {0, impactHeight + self.impactWeaponOffset}
	--If the ground gets removed from underneath us, stop the attack
	else
	  break
	end
	
	--If we runout of energy, stop the attack
	if status.resourceLocked("energy") then
	  break
	end
	
	if self.burstTimer <= 0 and status.overConsumeResource("energy", self.energyPerWave) then
	  self:fireShockwave()
	  self.burstTimer = self.burstTime
	end
	coroutine.yield()
  end

  --If the player stops holding out the weapon, stop the attack and activate cooldown
  animator.setAnimationState("swoosh", "idle")
  
  self.cooldownTimer = self.cooldownTime
end

function GroundConduct:reset()  
  self.cooldownTimer = self.cooldownTime
  self.burstTimer = self.burstTime
end

function GroundConduct:uninit()
  self:reset()
end

function GroundConduct:fireShockwave()
  local impact, impactHeight = self:impactPosition()
  
  animator.setAnimationState("swoosh", "conduct")

  if impact then
    self.weapon.weaponOffset = {0, impactHeight + self.impactWeaponOffset}

    local directions = {1}
    if self.bothDirections then directions[2] = -1 end
    local positions = self:shockwaveProjectilePositions(impact, directions)
    if #positions > 0 then
      animator.playSound("shockwave")
      local params = copy(self.projectileParameters)
      params.powerMultiplier = activeItem.ownerPowerMultiplier()
      params.power = params.power * config.getParameter("damageLevelMultiplier")
      params.actionOnReap = {
        {
          action = "projectile",
          inheritDamageFactor = 1,
          type = self.projectileType
        }
      }
      for i,position in pairs(positions) do
        local xDistance = world.distance(position, impact)[1]
        local dir = util.toDirection(xDistance)
        params.timeToLive = (math.floor(math.abs(xDistance))) * 0.025
        world.spawnProjectile("trinkelectricwavespawner", position, activeItem.ownerEntityId(), {dir,0}, false, params)
      end
    end
  end
end

function GroundConduct:impactPosition()
  local dir = mcontroller.facingDirection()
  local startLine = vec2.add(mcontroller.position(), vec2.mul(self.impactLine[1], {dir, 1}))
  local endLine = vec2.add(mcontroller.position(), vec2.mul(self.impactLine[2], {dir, 1}))
  
  local blocks = world.collisionBlocksAlongLine(startLine, endLine, {"Null", "Block"})
  if #blocks > 0 then
    return vec2.add(blocks[1], {0.5, 0.5}), endLine[2] - blocks[1][2] + 1
  end
end

function GroundConduct:shockwaveProjectilePositions(impactPosition, directions)
  local positions = {}

  for _,direction in pairs(directions) do
    direction = direction * mcontroller.facingDirection()
    local position = copy(impactPosition)
    for i = 0, self.maxDistance do
      local continue = false
      for _,yDir in ipairs({0, -1, 1}) do
        local wavePosition = {position[1] + direction * i, position[2] + 0.5 + yDir + self.shockwaveHeight}
        local groundPosition = {position[1] + direction * i, position[2] + yDir}
        local bounds = rect.translate(self.shockWaveBounds, wavePosition)

        if world.pointTileCollision(groundPosition, {"Null", "Block", "Dynamic"}) and not world.rectTileCollision(bounds, {"Null", "Block", "Dynamic"}) then
          table.insert(positions, wavePosition)
          position[2] = position[2] + yDir
          continue = true
          break
        end
      end
      if not continue then break end
    end
  end

  return positions
end
