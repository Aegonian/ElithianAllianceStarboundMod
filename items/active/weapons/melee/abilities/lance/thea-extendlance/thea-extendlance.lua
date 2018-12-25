require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

TheaExtendLance = WeaponAbility:new()

function TheaExtendLance:init()  
  self.active = config.getParameter("active") or false
  animator.setAnimationState("blade", "idle")
  
  self:reset()
  
  self.rechargeTimer = self.rechargeTime
end

function TheaExtendLance:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  self.rechargeTimer = math.max(0, self.rechargeTimer - self.dt)
  
  world.debugText(self.rechargeTimer, vec2.add(mcontroller.position(), {0,1}), "red")
  
  if self.rechargeTimer == 0 then
	--Activate the weapon
	animator.setAnimationState("light", "active")
  end

  if self.weapon.currentAbility == nil and self.fireMode == "alt" and not status.resourceLocked("energy") and self.rechargeTimer == 0 then
    self:setState(self.windup)
  end
end

-- Attack state: windup
function TheaExtendLance:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0

  animator.playSound("charge")
  animator.setAnimationState("blade", "charge")
  animator.setParticleEmitterActive("charge", true)

  local wasFull = false
  local chargeTimer = 0
  while self.fireMode == "alt" and (chargeTimer == self.chargeTime or status.overConsumeResource("energy", (self.energyUsage / self.chargeTime) * self.dt)) do
    chargeTimer = math.min(self.chargeTime, chargeTimer + self.dt)

    if chargeTimer == self.chargeTime and not wasFull then
      wasFull = true
      animator.stopAllSounds("charge")
	  if self.loopingReadySound then
		animator.playSound("chargefull", -1)
	  else
		animator.playSound("chargefull")
	  end
    end

    mcontroller.controlModifiers({
      runningSuppressed = true
    })
	
	--Disable energy regen while charging
	status.setResourcePercentage("energyRegenBlock", 0.6)
	
	world.debugText(chargeTimer .. " / " .. self.chargeTime, mcontroller.position(), "red")

    coroutine.yield()
  end

  animator.stopAllSounds("charge")
  animator.stopAllSounds("chargefull")
  animator.setParticleEmitterActive("charge", false)

  if chargeTimer >= self.chargeTime then
    self:setState(self.fire)
  else
	self:reset()
  end
end

-- Attack state: fire
function TheaExtendLance:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()
  
  self.rechargeTimer = self.rechargeTime
  
  animator.setAnimationState("light", "recharge")
  animator.setAnimationState("swoosh", "superThrust")
  animator.setAnimationState("blade", "extend")
  
  animator.playSound("superThrust")
  animator.burstParticleEmitter("extendBlade")

  util.wait(self.stances.fire.duration, function()
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
  end)
  
  animator.setAnimationState("blade", "retract")
end

function TheaExtendLance:reset()
  animator.stopAllSounds("charge")
  animator.stopAllSounds("chargefull")
  animator.setParticleEmitterActive("charge", false)
  
  animator.setAnimationState("light", "recharge")
end

function TheaExtendLance:uninit()
  self:reset()
  
  animator.stopAllSounds("charge")
  animator.stopAllSounds("chargefull")
end
