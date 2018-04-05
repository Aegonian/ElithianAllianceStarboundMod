require "/scripts/vec2.lua"

-- Bow primary ability
TheaLongbowSpecialArrows = WeaponAbility:new()

function TheaLongbowSpecialArrows:init()
  self.energyPerShot = self.energyPerShot or 0

  self.drawTime = 0
  animator.setAnimationState("bow", "idle")
  self.cooldownTimer = self.cooldownTime

  self:reset()

  self.weapon.onLeaveAbility = function()
    self:reset()
  end
end

function TheaLongbowSpecialArrows:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  world.debugPoint(self:firePosition(), "red")

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 and (self.energyPerShot == 0 or not status.resourceLocked("energy")) then
    self:setState(self.draw)
  else
	animator.setAnimationState("arrows", "hidden")
  end
end

function TheaLongbowSpecialArrows:uninit()
  self:reset()
end

function TheaLongbowSpecialArrows:reset()
  animator.setGlobalTag("drawFrame", "0")
  animator.setAnimationState("bow", "idle")
  self.weapon:setStance(self.stances.idle)
end

function TheaLongbowSpecialArrows:draw()
  self.weapon:setStance(self.stances.draw)

  animator.playSound("draw")

  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and not status.resourceLocked("energy") do
    animator.setAnimationState("arrows", "visible")
	
	if self.walkWhileFiring then
	  mcontroller.controlModifiers({runningSuppressed = true})
	end

    self.drawTime = self.drawTime + self.dt

    local drawFrame = math.floor(root.evalFunction(self.drawFrameSelector, self.drawTime))
    animator.setGlobalTag("drawFrame", drawFrame)
    self.stances.draw.frontArmFrame = self.drawArmFrames[drawFrame + 1]
	
	--if self:perfectTiming() then
      --world.debugText("PERFECT", mcontroller.position(), "green")
	  --local canHoldBow = status.overConsumeResource("energy", self.holdEnergyUsage * self.dt)
    --else
      --world.debugText("NOPE", mcontroller.position(), "red")
    --end

    coroutine.yield()
  end

  self:setState(self.fire)
end

function TheaLongbowSpecialArrows:fire()
  self.weapon:setStance(self.stances.fire)

  animator.stopAllSounds("draw")
  animator.setGlobalTag("drawFrame", "0")

  if not world.lineTileCollision(mcontroller.position(), self:firePosition()) and status.overConsumeResource("energy", self.energyPerShot) then
    local projectileId = 0
	for i = 1, (self.projectileCount) do
	  world.spawnProjectile(
        self:perfectTiming() and self.powerProjectileType or self.projectileType,
        self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(),
        false,
        self:currentProjectileParameters()
      )

	  if self:perfectTiming() then
		animator.playSound("perfectRelease")
	  else
		animator.playSound("release")
	  end
	end
	
	animator.setAnimationState("bow", "loosed")

    self.drawTime = 0

    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.cooldownTime
end

function TheaLongbowSpecialArrows:perfectTiming()
  return self.drawTime > self.powerProjectileTime[1]
end

function TheaLongbowSpecialArrows:currentProjectileParameters()
  local projectileParameters = copy(self.projectileParameters or {})
  local projectileConfig = root.projectileConfig(self:perfectTiming() and self.powerProjectileType or self.projectileType)
  projectileParameters.speed = projectileParameters.speed or projectileConfig.speed
  projectileParameters.speed = projectileParameters.speed * root.evalFunction(self.drawSpeedMultiplier, self.drawTime)
  --Bonus damage calculation for quiver users
  local damageBonus = 1.0
  if self.useQuiverDamageBonus == true and status.statPositive("avikanQuiver") then
	damageBonus = status.stat("avikanQuiver")
  end
  projectileParameters.power = projectileParameters.power or projectileConfig.power
  projectileParameters.power = projectileParameters.power
      * self.weapon.damageLevelMultiplier
      * root.evalFunction(self.drawPowerMultiplier, self.drawTime)
	  * damageBonus
  projectileParameters.powerMultiplier = activeItem.ownerPowerMultiplier()

  return projectileParameters
end

function TheaLongbowSpecialArrows:aimVector()
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(self.inaccuracy or 0, 0))
  aimVector[1] = aimVector[1] * self.weapon.aimDirection
  return aimVector
end

function TheaLongbowSpecialArrows:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end
