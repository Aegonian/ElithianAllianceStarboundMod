require("/scripts/vec2.lua")

function init()
  --Set up the healing animation
  animator.setParticleEmitterOffsetRegion("healing", mcontroller.boundBox())
  animator.setParticleEmitterEmissionRate("healing", config.getParameter("emissionRate", 3))
  
  --Load in config values
  self.cooldownTimer = config.getParameter("cooldownAfterHit", 10)
  self.healingRate = config.getParameter("healAmount", 30)
  
  --Set up initial stats
  self.currentHealth = status.resource("health", 1)
  self.lastHealth = self.currentHealth
end

function update(dt)
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  self.currentHealth = status.resource("health")
  
  --world.debugText(self.currentHealth, vec2.add(mcontroller.position(), {0,3}), "red")
  --world.debugText(self.lastHealth, vec2.add(mcontroller.position(), {0,2}), "red")
  --world.debugText(self.cooldownTimer, vec2.add(mcontroller.position(), {0,1}), "red")
  
  --Reset the cooldown timer if we lose health
  if self.currentHealth < self.lastHealth then
	self.cooldownTimer = config.getParameter("cooldownAfterHit")
  end
  
  if self.cooldownTimer == 0 then
	--If we aren't at full health already
	if status.resourcePercentage("health") < 1.0 then
	  --Do healing
	  status.modifyResource("health", self.healingRate * dt)
	  animator.setParticleEmitterActive("healing", true)
	else
	  animator.setParticleEmitterActive("healing", false)
	end
  else
	animator.setParticleEmitterActive("healing", false)
  end
  
  self.lastHealth = self.currentHealth
  
  sb.setLogMap("THEA - Active racial benefit", "GENETIC ENHANCEMENTS")
end

function uninit()
end