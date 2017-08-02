require "/scripts/vec2.lua"

TheaArrowBarrage = WeaponAbility:new()

function TheaArrowBarrage:init()
  self.energyPerShot = self.energyPerShot or 0

  self.drawTime = 0
  self.cooldownTimer = self.cooldownTime

  self.projectileParameters = self.projectileParameters or {}

  local projectileConfig = root.projectileConfig(self.projectileType)
  self.projectileParameters.speed = self.projectileParameters.speed or projectileConfig.speed
  self.projectileParameters.power = self.projectileParameters.power or projectileConfig.power
  self.projectileParameters.power = self.projectileParameters.power * self.weapon.damageLevelMultiplier

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

  -- self.weapon.onLeaveAbility = function()
  --   self:reset()
  -- end
end

function TheaArrowBarrage:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 and (self.energyPerShot == 0 or not status.resourceLocked("energy")) then
    self:setState(self.windup)
  end
end

function TheaArrowBarrage:uninit()
  self:reset()
end

function TheaArrowBarrage:reset()
  animator.setGlobalTag("drawFrame", "0")
  -- self.weapon:setStance(self.stances.idle)
end

function TheaArrowBarrage:windup()
  self.weapon:setStance(self.stances.windup)

  activeItem.emote("sleep")

  util.wait(self.stances.windup.duration, function()

    end)

  self:setState(self.draw)
end

function TheaArrowBarrage:draw()
  self.weapon:setStance(self.stances.draw)

  animator.playSound("draw")

  while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
    if self.walkWhileFiring then mcontroller.controlModifiers({runningSuppressed = true}) end

    self.drawTime = self.drawTime + self.dt

    local drawFrame = math.floor(root.evalFunction(self.drawFrameSelector, self.drawTime))
    animator.setGlobalTag("drawFrame", drawFrame)
    self.stances.draw.frontArmFrame = self.drawArmFrames[drawFrame + 1]

    local aimVec = self:idealAimVector()
    aimVec[1] = aimVec[1] * self.weapon.aimDirection

    -- I feel like there's a joke here about Zeno's paradoxes
    self.weapon.aimAngle = (4 * self.weapon.aimAngle + vec2.angle(aimVec)) / 5

    coroutine.yield()
  end

  self:setState(self.fire)
end

function TheaArrowBarrage:fire()
  self.weapon:setStance(self.stances.fire)

  animator.stopAllSounds("draw")
  animator.setGlobalTag("drawFrame", "0")

  if not world.pointTileCollision(self:firePosition()) and status.overConsumeResource("energy", self.energyPerShot) then
    local params = copy(self.projectileParameters)
    params.powerMultiplier = activeItem.ownerPowerMultiplier()
    params.speed = params.speed * root.evalFunction(self.drawSpeedMultiplier, self.drawTime)
	--Bonus damage calculation for quiver users
	local damageBonus = 1.0
	if self.useQuiverDamageBonus == true and status.statPositive("avikanQuiver") then
	  damageBonus = status.stat("avikanQuiver")
	end
    params.power = params.power * root.evalFunction(self.drawPowerMultiplier, self.drawTime) * damageBonus

    world.spawnProjectile(
        self.projectileType,
        self:firePosition(),
        activeItem.ownerEntityId(),
        self:idealAimVector(),
        false,
        params
      )

    animator.playSound("release")

    self.drawTime = 0

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
