require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/vec2.lua"

function init()
  animator.setAnimationState("shield", "recharge")
  
  --Loading stats from config file into self
  self.maxHealth = config.getParameter("shieldHealth")
  self.rechargeTime = config.getParameter("rechargeTime")
  self.cooldownTime = config.getParameter("cooldownTime")
  self.projectileParameters = config.getParameter("projectileParameters")
  
  --Initial stats
  self.currentHealth = 0
  self.rechargeTimer = self.rechargeTime
  self.cooldownTimer = 0
  self.active = false
  self.shieldHealth = status.resource("damageAbsorption")
  self.lastShieldHealth = status.resource("damageAbsorption")
end

function update(dt)
  if not self.active then
	self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
	if self.cooldownTimer == 0 then
	  animator.setAnimationState("shield", "recharge")
	end
	self.rechargeTimer = math.max(0, self.rechargeTimer - dt)
	if self.rechargeTimer == 0 then
	  activateShield()
	end
  elseif self.active then
	self.shieldHealth = status.resource("damageAbsorption")
	if self.shieldHealth ~= self.lastShieldHealth then
	  breakShield()
	end
  end
  
  self.lastShieldHealth = status.resource("damageAbsorption")
end

function activateShield()
  animator.setAnimationState("shield", "on")
  animator.setLightActive("glow", true)
  status.setResource("damageAbsorption", self.maxHealth)
  self.active = true
end

function breakShield()
  animator.setAnimationState("shield", "off")
  animator.setLightActive("glow", false)
  status.setResource("damageAbsorption", 0)
  self.active = false
  
  --Explosion projectile confg
  world.spawnProjectile("forceshieldexplosionspawner", mcontroller.position(), entity.id(), {0, 0}, false, self.projectileParameters)
  self.rechargeTimer = self.rechargeTime
  self.cooldownTimer = self.cooldownTime
  
  --Grant the player a very short-lived effect to repel even more projectiles
  status.addEphemeralEffect("thea-forceshieldrepel", config.getParameter("repelDuration", 1), effect.sourceEntity())
end

function uninit()
  status.setResource("damageAbsorption", 0)
end

function onExpire()
  status.setResource("damageAbsorption", 0)
end