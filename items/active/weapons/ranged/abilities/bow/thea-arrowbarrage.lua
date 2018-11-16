require "/scripts/vec2.lua"

TheaArrowBarrage = WeaponAbility:new()

function TheaArrowBarrage:init()
  self.energyPerShot = self.energyPerShot or 0

  self.drawTimer = 0
  animator.setAnimationState("bow", "idle")
  self.cooldownTimer = self.cooldownTime

  self.projectileParameters = self.projectileParameters or {}

  --local projectileConfig = root.projectileConfig(self.projectileType)
  --self.projectileParameters.speed = self.projectileParameters.speed or projectileConfig.speed
  --self.projectileParameters.power = self.projectileParameters.power or projectileConfig.power
  --self.projectileParameters.power = self.projectileParameters.power * self.weapon.damageLevelMultiplier

  self.projectileParameters.periodicActions = {
    {
      time = self.splitDelay,
      ["repeat"] = false,
      action = "projectile",
      type = self.projectileType,
      angleAdjust = -self.splitAngle * 0.5,
      inheritDamageFactor = 1.0,
      inheritSpeedFactor = 1.0
    },
    {
      time = self.splitDelay,
      ["repeat"] = false,
      action = "projectile",
      type = self.projectileType,
      angleAdjust = self.splitAngle * 0.5,
      inheritDamageFactor = 1.0,
      inheritSpeedFactor = 1.0
    },
    {
      time = self.splitDelay,
      ["repeat"] = false,
      action = "projectile",
      type = self.projectileType,
      angleAdjust = self.splitAngle,
      inheritDamageFactor = 1.0,
      inheritSpeedFactor = 1.0
    },
    {
      time = self.splitDelay,
      ["repeat"] = false,
      action = "projectile",
      type = self.projectileType,
      angleAdjust = -self.splitAngle,
      inheritDamageFactor = 1.0,
      inheritSpeedFactor = 1.0
    }
  }

  self.projectileGravityMultiplier = root.projectileGravityMultiplier(self.projectileType)
end

function TheaArrowBarrage:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  world.debugPoint(self:firePosition(), "orange")

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 and (self.drawTimer > 0 or not status.resourceLocked("energy")) then
    self:setState(self.windup)
  end
end

function TheaArrowBarrage:uninit()
  self:reset()
end

function TheaArrowBarrage:reset()
  animator.setGlobalTag("drawFrame", "0")
  animator.setAnimationState("bow", "idle")
  animator.stopAllSounds("drawBarrage")
  animator.stopAllSounds("ready")
end

function TheaArrowBarrage:windup()
  self.weapon:setStance(self.stances.windup)

  activeItem.emote("sleep")

  util.wait(self.stances.windup.duration)

  self:setState(self.draw)
end

function TheaArrowBarrage:draw()
  self.weapon:setStance(self.stances.draw)

  animator.playSound("drawBarrage", -1)
  local readySoundPlayed = false

  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and not status.resourceLocked("energy") do
    if self.walkWhileFiring then mcontroller.controlModifiers({runningSuppressed = true}) end

    self.drawTimer = self.drawTimer + self.dt

    local drawFrame = math.min(#self.drawArmFrames - 2, math.floor(self.drawTimer / self.drawTime * (#self.drawArmFrames - 1)))
    animator.setGlobalTag("drawFrame", drawFrame)
    self.stances.draw.frontArmFrame = self.drawArmFrames[drawFrame + 1]

	--Calculate the correct aiming angle to hit the target location
    local aimVec = self:idealAimVector()
    aimVec[1] = aimVec[1] * self.weapon.aimDirection
    self.weapon.aimAngle = (4 * self.weapon.aimAngle + vec2.angle(aimVec)) / 5
	world.debugLine(self:firePosition(), vec2.add(self:firePosition(), vec2.mul(vec2.norm(self:idealAimVector()), 3)), "red")

	--If not yet fully drawn, drain energy quickly
	if self.drawTimer < self.drawTime then
	  status.overConsumeResource("energy", self.energyPerShot / self.drawTime * self.dt)
	  
	--If fully drawn, drain energy slowly
	elseif self.drawTimer > self.drawTime then
	  status.overConsumeResource("energy", self.holdEnergyUsage * self.dt)
	end
	
	--Play the ready sound just before the bow is fully drawn
	if self.drawTimer >= (self.drawTime - 0.15) then
	  animator.stopAllSounds("drawBarrage")
	  if not readySoundPlayed then
		animator.playSound("ready")
		readySoundPlayed = true
	  end
	end
	
    coroutine.yield()
  end

  animator.stopAllSounds("drawBarrage")
  self:setState(self.fire)
end

function TheaArrowBarrage:fire()
  self.weapon:setStance(self.stances.fire)

  animator.stopAllSounds("drawBarrage")
  animator.setGlobalTag("drawFrame", "0")
  animator.stopAllSounds("ready")

  if not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
    local projectileParameters = copy(self.projectileParameters)
	
	--Calculate projectile speed based on draw time and projectile parameters
    projectileParameters.speed = projectileParameters.speed * math.min(1, (self.drawTimer / self.drawTime))
	
	--Bonus damage calculation for quiver users
	local damageBonus = 1.0
	if self.useQuiverDamageBonus == true and status.statPositive("avikanQuiver") then
	  damageBonus = status.stat("avikanQuiver")
	end
	
	--Calculate projectile power based on draw time and projectile parameters
	local drawTimeMultiplier = self.staticDamageMultiplier or math.min(1, (self.drawTimer / self.drawTime))
    projectileParameters.power = projectileParameters.power
      * self.weapon.damageLevelMultiplier
      * drawTimeMultiplier
	  * damageBonus
    projectileParameters.powerMultiplier = activeItem.ownerPowerMultiplier()

	--Spawn the projectile using the calculated parameters
    world.spawnProjectile(
        self.projectileType,
        self:firePosition(),
        activeItem.ownerEntityId(),
        self:idealAimVector(),
        false,
        projectileParameters
      )
	  
    self.drawTimer = 0

    animator.playSound("release")
	animator.setAnimationState("bow", "loosed")

    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.cooldownTime
end

function TheaArrowBarrage:idealAimVector()
  local targetOffset = world.distance(activeItem.ownerAimPosition(), self:firePosition())
  return util.aimVector(targetOffset, self.projectileParameters.speed, self.projectileGravityMultiplier, true)
end

function TheaArrowBarrage:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end
