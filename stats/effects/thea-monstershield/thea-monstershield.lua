require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/vec2.lua"

function init()
  animator.setAnimationState("shield", "recharge")
  
  --Loading stats from monster stats config into self
  self.maxHealth = status.stat("maxShield") * root.evalFunction("monsterLevelHealthMultiplier", world.threatLevel())
  self.startHealthPercentage = status.stat("shieldStartPercentage")
  self.regenPercentage = status.stat("shieldRegenPercentage")
  self.rechargeTimeAfterHit = status.stat("shieldRechargeTimeAfterHit")
  self.cooldownTimeAfterBreak = status.stat("shieldCooldownTimeAfterBreak")
  
  --Static stats
  self.maxOverlayFactor = config.getParameter("maxOverlayFactor")
  
  --Initial stats
  self.rechargeTimer = 0
  self.cooldownTimer = 0
  self.active = false
  self.shieldHealth = status.resource("shieldHealth")
  self.lastShieldHealth = status.resource("shieldHealth")
  
  --Setting the initial render directive
  animator.setGlobalTag("shieldDirectives", "")
end

function update(dt)
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  
  --world.debugText("Cooldown ready in " .. self.cooldownTimer, mcontroller.position(), "red")
  --world.debugText("Recharge ready in " .. self.rechargeTimer, vec2.add(mcontroller.position(), {0,1}), "red")
  --world.debugText("Health is " .. self.shieldHealth .. " / " .. self.maxHealth, vec2.add(mcontroller.position(), {0,2}), "red")
  
  if not self.active then
	if self.cooldownTimer == 0 then
	  animator.setAnimationState("shield", "recharge")
	  self.rechargeTimer = math.max(0, self.rechargeTimer - dt)
	  if self.rechargeTimer == 0 then
		activateShield()
	  end
	end
  elseif self.active then
	self.shieldHealth = status.resource("shieldHealth")
	
	self.rechargeTimer = math.max(0, self.rechargeTimer - dt)
	
	--Check if we got hit recently by comparing current damage absorption to that of last frame
	if self.shieldHealth ~= self.lastShieldHealth then
	  self.rechargeTimer = self.rechargeTimeAfterHit
	elseif self.shieldHealth ~= self.maxHealth and self.rechargeTimer == 0 then
	  status.setResource("shieldHealth", math.min(self.maxHealth, self.shieldHealth + (self.maxHealth * self.regenPercentage * dt)))
	end
	
	local healthFactor =  1 - (self.shieldHealth / self.maxHealth)
	
	if status.resource("shieldHealth") <= 0 then
	  breakShield()
	end
  end
  
  local factor = (1 - (status.resource("shieldHealth") / self.maxHealth)) * self.maxOverlayFactor
  local directive = "fade=FF0000=" .. factor
  --world.debugText("Directive factor is " .. factor, vec2.add(mcontroller.position(), {0,3}), "red")
  
  animator.setGlobalTag("shieldDirectives", directive)
  self.lastShieldHealth = status.resource("shieldHealth")
end

function activateShield()
  animator.setAnimationState("shield", "activate")
  animator.setLightActive("glow", true)
  status.setResource("shieldHealth", self.maxHealth * self.startHealthPercentage)
  self.active = true
end

function breakShield()
  animator.setAnimationState("shield", "break")
  animator.setLightActive("glow", false)
  animator.playSound("break")
  animator.burstParticleEmitter("break")
  self.cooldownTimer = self.cooldownTimeAfterBreak
  self.rechargeTimer = self.rechargeTimeAfterHit
  self.active = false
end

function uninit()
  status.setResource("shieldHealth", 0)
end

function onExpire()
  status.setResource("shieldHealth", 0)
end