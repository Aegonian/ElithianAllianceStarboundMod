function init()
  animator.setParticleEmitterOffsetRegion("healing", mcontroller.boundBox())
  animator.setParticleEmitterEmissionRate("healing", config.getParameter("emissionRate", 3))
  animator.setParticleEmitterActive("healing", true)

  script.setUpdateDelta(5)
  
  self.healingApplied = false
end

function update(dt)
  if not self.healingApplied then
	status.modifyResource("health", config.getParameter("healAmount", 1))
	if animator.hasSound("heal") then
	  animator.playSound("heal")
	end
	self.healingApplied = true
  elseif config.getParameter("completeDuration", false) then
	--Allows the configured effect to play out its full duration, making the duration act as an immunity time until the next heal can be applied
	animator.setParticleEmitterActive("healing", false)
  else
	effect.expire()
  end
end

function uninit()
  
end
