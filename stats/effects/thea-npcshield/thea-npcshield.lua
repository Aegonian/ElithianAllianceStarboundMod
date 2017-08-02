require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/vec2.lua"

function init()
  animator.setAnimationState("shield", "recharge")
  
  --Loading stats from config file into self
  self.maxHealth = config.getParameter("shieldHealth")
  self.rechargeTimeAfterBreak = config.getParameter("rechargeTimeAfterBreak")
  self.cooldownTimeAfterBreak = config.getParameter("cooldownTimeAfterBreak")
  self.maxAnimationRate = config.getParameter("maxAnimationRate")
  self.forceWalking = config.getParameter("forceWalking")
  
  --Initial stats
  self.currentHealth = 0
  self.rechargeTimer = 0
  self.cooldownTimer = 0
  self.active = false
  self.shieldHealth = status.resource("damageAbsorption")
  self.lastShieldHealth = status.resource("damageAbsorption")
  animator.setAnimationRate(1)
end

function update(dt)
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  
  if self.forceWalking then
	mcontroller.controlModifiers({runningSuppressed=true})
  end
  
  --world.debugText("Cooldown ready in " .. self.cooldownTimer, mcontroller.position(), "red")
  --world.debugText("Recharge ready in " .. self.rechargeTimer, vec2.add(mcontroller.position(), {0,1}), "red")
  --world.debugText("Health is " .. self.shieldHealth, vec2.add(mcontroller.position(), {0,2}), "red")
  
  if not self.active then
	if self.cooldownTimer == 0 then
	  animator.setAnimationState("shield", "recharge")
	  self.rechargeTimer = math.max(0, self.rechargeTimer - dt)
	  if self.rechargeTimer == 0 then
		activateShield()
	  end
	end
  elseif self.active then
	self.shieldHealth = status.resource("damageAbsorption")
	
	local healthFactor =  1 - (self.shieldHealth / self.maxHealth)
	local animationRate =  1 + (healthFactor * (self.maxAnimationRate - 1))
	animator.setAnimationRate(animationRate)
	--world.debugText("Animation Rate is " .. animationRate, vec2.add(mcontroller.position(), {0,3}), "red")
	
	if status.resource("damageAbsorption") <= 0 then
	  breakShield()
	end
  end
  
  self.lastShieldHealth = status.resource("damageAbsorption")
end

function activateShield()
  animator.setAnimationState("shield", "activate")
  animator.setLightActive("glow", true)
  animator.setAnimationRate(1)
  status.setResource("damageAbsorption", self.maxHealth)
  self.active = true
end

function breakShield()
  animator.setAnimationState("shield", "break")
  animator.setLightActive("glow", false)
  animator.setAnimationRate(1)
  animator.playSound("break")
  animator.burstParticleEmitter("break")
  self.cooldownTimer = self.cooldownTimeAfterBreak
  self.rechargeTimer = self.rechargeTimeAfterBreak
  self.active = false
end

function uninit()
  status.setResource("damageAbsorption", 0)
end

function onExpire()
  status.setResource("damageAbsorption", 0)
end