require "/scripts/util.lua"

function init()
  --animator.setParticleEmitterOffsetRegion("chargingCloakingField", mcontroller.boundBox())
  
  self.windUpTimer = config.getParameter("timeToCloak", 1.5)
  self.cooldownTimer = 0
  
  script.setUpdateDelta(1)
end

function update(dt)
  if mcontroller.crouching() and self.cooldownTimer == 0 then
	self.windUpTimer = math.max(0, self.windUpTimer - dt)
	animator.setParticleEmitterActive("chargingCloakingField", true)
	
	if self.windUpTimer == 0 then
	  status.addEphemeralEffect("thea-cloaking", config.getParameter("cloakingDuration", 5.0))
	  self.cooldownTimer = config.getParameter("cooldownTime", 1.0)
	end
  else
	self.windUpTimer = config.getParameter("timeToCloak", 1.5)
	animator.setParticleEmitterActive("chargingCloakingField", false)
  end
  
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
end

function uninit()
end
