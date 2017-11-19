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
	self.healingApplied = true
  else
	effect.expire()
  end
end

function uninit()
  
end
