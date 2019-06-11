--Modified bow shot ability that drains energy while drawing and holding, with configurable drain rates. Has an animation state for when arrows have been loosed

require "/scripts/vec2.lua"

-- Bow primary ability
TheaQuickDraw = WeaponAbility:new()

function TheaQuickDraw:init()
  self.energyPerShot = self.energyPerShot or 0

  self.drawTimer = 0
  animator.setAnimationState("bow", "idle")
  self.cooldownTimer = 0

  self:reset()

  self.weapon.onLeaveAbility = function()
    self:reset()
  end
end

function TheaQuickDraw:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  world.debugPoint(self:firePosition(), "red")
  
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 and (self.drawTimer > 0 or not status.resourceLocked("energy")) then
    self:setState(self.draw)
  end
end

function TheaQuickDraw:uninit()
  self:reset()
end

function TheaQuickDraw:reset()
  animator.setGlobalTag("drawFrame", "0")
  animator.setAnimationState("bow", "idle")
  animator.stopAllSounds("draw")
  animator.stopAllSounds("ready")
  self.weapon:setStance(self.stances.idle)
end

function TheaQuickDraw:draw()
  self.weapon:setStance(self.stances.draw)

  animator.playSound("draw", -1)
  local readySoundPlayed = false

  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and not status.resourceLocked("energy") and self.drawTimer < self.drawTime do
    if self.walkWhileFiring then
	  mcontroller.controlModifiers({runningSuppressed = true})
	end

    self.drawTimer = math.min(self.drawTime, self.drawTimer + self.dt)

    local drawFrame = math.min(#self.drawArmFrames - 2, math.floor(self.drawTimer / self.drawTime * (#self.drawArmFrames - 1)))
	
	--If not yet fully drawn, drain energy quickly
	if self.drawTimer < self.drawTime then
	  status.overConsumeResource("energy", self.energyPerShot / self.drawTime * self.dt)
	end
	
	--If the bow is almost fully drawn, stop the draw sound and play the ready sound
	--Do this slightly before the draw is ready so the player can release when they hear the sound
	--This way, the sound plays at the same moment in the draw phase for every bow regardless of draw time
	if self.drawTimer >= (self.drawTime - 0.15) then
	  animator.stopAllSounds("draw")
	  if not readySoundPlayed then
		animator.playSound("ready")
		readySoundPlayed = true
	  end
	end
	
    animator.setGlobalTag("drawFrame", drawFrame)
    self.stances.draw.frontArmFrame = self.drawArmFrames[drawFrame + 1]
	
	world.debugText(sb.printJson(self:currentProjectileParameters(), 1), mcontroller.position(), "yellow")
	
    coroutine.yield()
  end

  animator.stopAllSounds("draw")
  self:setState(self.fire)
end

function TheaQuickDraw:fire()
  self.weapon:setStance(self.stances.fire)

  animator.setGlobalTag("drawFrame", "0")
  animator.stopAllSounds("ready")

  if not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
    for i = 1, (self.projectileCount or 1) do
	  world.spawnProjectile(
        self.projectileType,
        self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(),
        false,
        self:currentProjectileParameters()
      )

	  animator.playSound("release")
	end
	
	animator.setAnimationState("bow", "loosed")

    self.drawTimer = 0

    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.cooldownTime
end

function TheaQuickDraw:currentProjectileParameters()
  --Set projectile parameters based on draw power level
  local projectileParameters = copy(self.projectileParameters or {})
  --Load the root projectile config based on draw power level
  local projectileConfig = root.projectileConfig(self.projectileType)
  
  --Calculate projectile speed based on draw time and projectile parameters
  projectileParameters.speed = projectileParameters.speed or projectileConfig.speed
  projectileParameters.speed = projectileParameters.speed * math.min(1, (self.drawTimer / self.drawTime))
  
  --Bonus damage calculation for quiver users
  local damageBonus = 1.0
  if self.useQuiverDamageBonus == true and status.statPositive("avikanQuiver") then
	damageBonus = status.stat("avikanQuiver")
  end
  
  --Calculate projectile power based on draw time and projectile parameters
  local drawTimeMultiplier = self.staticDamageMultiplier or math.min(1, (self.drawTimer / self.drawTime))
  projectileParameters.power = projectileParameters.power or projectileConfig.power
  projectileParameters.power = projectileParameters.power
	* self.weapon.damageLevelMultiplier
	* drawTimeMultiplier
	* (self.dynamicDamageMultiplier or 1)
	* damageBonus
	/ (self.projectileCount or 1)
  projectileParameters.powerMultiplier = activeItem.ownerPowerMultiplier()

  return projectileParameters
end

function TheaQuickDraw:aimVector()
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(self.inaccuracy or 0, 0))
  aimVector[1] = aimVector[1] * self.weapon.aimDirection
  return aimVector
end

function TheaQuickDraw:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end
