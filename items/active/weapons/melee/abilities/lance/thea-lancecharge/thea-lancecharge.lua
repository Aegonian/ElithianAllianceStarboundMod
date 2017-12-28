require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

TheaLanceCharge = WeaponAbility:new()

function TheaLanceCharge:init()
  self:reset()
end

function TheaLanceCharge:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  
  if mcontroller.onGround() then
	self.airTime = 0
  else
	self.airTime = math.min(self.airTime + self.dt, 5)
  end
  
  if self.weapon.currentAbility == nil
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
	and mcontroller.onGround()
    and self.fireMode == "alt" then
    
    self:setState(self.windup)
  end
end

function TheaLanceCharge:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  --Code for logging all current movement parameters
  --local params = mcontroller.baseParameters()
  --local info = sb.printJson(params, 1)
  --sb.logInfo(info)
  
  animator.playSound("windup")
  
  if self.stances.windup.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  else
    util.wait(self.stances.windup.duration, function()
	  mcontroller.controlModifiers({
		walkingSuppressed = true,
		runningSuppressed = true,
		movementSuppressed = true,
		jumpingSuppressed = true
	  })
	  if mcontroller.onGround() then
		mcontroller.setVelocity({0,0})
	  end
	end)
  end

  if mcontroller.onGround() then
	self:setState(self.charge)
  else
	--If the windup failed, add a short cooldown time
	self.cooldownTimer = self.cooldownTimeShort
  end
end

function TheaLanceCharge:charge()
  self.weapon:setStance(self.stances.charge)
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0

  animator.playSound("chargeStart")
  animator.playSound("chargeLoop", -1)
  animator.setParticleEmitterActive("chargeParticles", true)
  
  --Initial speed boost
  mcontroller.setXVelocity(self.initialDashSpeed * mcontroller.facingDirection())

  --Allow the player to start running just after activating the charge
  self.waitTimer = 0
  while self.fireMode == "alt" and self.airTime <= self.maxAirTime and mcontroller.velocity()[1] ~= 0 and status.overConsumeResource("energy", self.energyUsage * self.dt) do
    local damageArea = partDamageArea("blade")
	self.weapon:setDamage(self.damageConfig, damageArea)
	
	self.waitTimer = math.min(self.waitTimer + self.dt, 5)
	
	mcontroller.controlModifiers({speedModifier = self.chargeSpeedModifier})
	mcontroller.controlMove(mcontroller.facingDirection(), true)
	
	local movementParams = mcontroller.baseParameters()
	local currentVelocity = mcontroller.velocity()
    if math.abs(currentVelocity[1]) > self.maxChargeSpeed then
      mcontroller.setXVelocity(self.maxChargeSpeed * mcontroller.facingDirection())
    end
	
	coroutine.yield()
  end

  self:reset()
end

function TheaLanceCharge:reset()
  animator.setParticleEmitterActive("chargeParticles", false)
  animator.stopAllSounds("chargeLoop")
  self.cooldownTimer = self.cooldownTime
  self.airTime = 0
end

function TheaLanceCharge:uninit()
  self:reset()
end
